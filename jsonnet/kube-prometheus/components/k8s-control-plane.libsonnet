local relabelings = import '../addons/dropping-deprecated-metrics-relabelings.libsonnet';

local defaults = {
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  namespace:: error 'must provide namespace',
  commonLabels:: {
    'app.kubernetes.io/name': 'kube-prometheus',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  mixin:: {
    ruleLabels: {},
    _config: {
      showMultiCluster: true,
      cadvisorSelector: 'job="kubelet", metrics_path="/metrics/cadvisor"',
      kubeletSelector: 'job="kubelet", metrics_path="/metrics"',
      kubeStateMetricsSelector: 'job="kube-state-metrics"',
      nodeExporterSelector: 'job="node-exporter"',
      kubeSchedulerSelector: 'job="kube-scheduler"',
      kubeControllerManagerSelector: 'job="kube-controller-manager"',
      kubeApiserverSelector: 'job="apiserver"',
      kubeProxySelector: 'job="kube-proxy"',
      coreDNSSelector: 'job="coredns"',
      podLabel: 'pod',
      runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/kubernetes/%s',
      diskDeviceSelector: 'device=~"(/dev/)?(mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|md.+|dasd.+)"',
      hostNetworkInterfaceSelector: 'device!~"veth.+"',
    },
  },
  kubelet: {
    slos: {
      requestErrors: {
        target: '99',
        window: '2w',
      },
      runtimeErrors: {
        target: '99.5',
        window: '2w',
      },
    },
  },
  kubeControllerManager: {
    slos: {
      requestErrors: {
        target: '99',
        window: '2w',
      },
    },
  },
  kubeProxy: false,
  kubeProxyConfig: {  // different name for backwards compatability
    slos: {
      syncRulesLatency: {
        target: '90',
        latency: '0.512',  // must exist as le label
        window: '2w',
      },
      requestErrors: {
        target: '90',  // kube-proxy makes very few requests
        window: '2w',
      },
    },
  },
  coredns: {
    name: 'coredns',
    slos: {
      responseErrors: {
        target: '99.99',
        window: '2w',
      },
      responseLatency: {
        target: '99',
        latency: '0.032',  // must exist as le label
        window: '2w',
      },
    },
  },
};

function(params) {
  local k8s = self,
  _config:: defaults + params,
  _metadata:: {
    labels: k8s._config.commonLabels,
    namespace: k8s._config.namespace,
  },

  mixin:: (import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet') {
    _config+:: k8s._config.mixin._config,
  } + {
    // Filter-out alerts related to kube-proxy when `kubeProxy: false`
    [if !(defaults + params).kubeProxy then 'prometheusAlerts']+:: {
      groups: std.filter(
        function(g) !std.member(['kubernetes-system-kube-proxy'], g.name),
        super.groups
      ),
    },
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: k8s._metadata {
      name: 'kubernetes-monitoring-rules',
      labels+: k8s._config.mixin.ruleLabels,
    },
    spec: {
      local r = if std.objectHasAll(k8s.mixin, 'prometheusRules') then k8s.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(k8s.mixin, 'prometheusAlerts') then k8s.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  serviceMonitorKubeScheduler: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: k8s._metadata {
      name: 'kube-scheduler',
      labels+: { 'app.kubernetes.io/name': 'kube-scheduler' },
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      endpoints: [
        {
          port: 'https-metrics',
          interval: '30s',
          scheme: 'https',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          tlsConfig: { insecureSkipVerify: true },
        },
        {
          port: 'https-metrics',
          interval: '5s',
          scheme: 'https',
          path: '/metrics/slis',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          tlsConfig: { insecureSkipVerify: true },
          metricRelabelings: [
            {
              sourceLabels: ['__name__'],
              regex: 'process_start_time_seconds',
              action: 'drop',
            },
          ],
        },
      ],
      selector: {
        matchLabels: { 'app.kubernetes.io/name': 'kube-scheduler' },
      },
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
    },
  },

  kubeletServiceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: k8s._metadata {
      name: 'kubelet',
      labels+: { 'app.kubernetes.io/name': 'kubelet' },
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      endpoints: [
        {
          port: 'https-metrics',
          scheme: 'https',
          interval: '30s',
          honorLabels: true,
          tlsConfig: { insecureSkipVerify: true },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          metricRelabelings: relabelings,
          relabelings: [{
            action: 'replace',
            sourceLabels: ['__metrics_path__'],
            targetLabel: 'metrics_path',
          }],
        },
        {
          port: 'https-metrics',
          scheme: 'https',
          path: '/metrics/cadvisor',
          interval: '30s',
          honorLabels: true,
          honorTimestamps: false,
          tlsConfig: {
            insecureSkipVerify: true,
          },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          relabelings: [{
            action: 'replace',
            sourceLabels: ['__metrics_path__'],
            targetLabel: 'metrics_path',
          }],
          metricRelabelings: [
            // Drop a bunch of metrics which are disabled but still sent, see
            // https://github.com/google/cadvisor/issues/1925.
            {
              sourceLabels: ['__name__'],
              regex: 'container_(network_tcp_usage_total|network_udp_usage_total|tasks_state|cpu_load_average_10s)',
              action: 'drop',
            },
            // Drop cAdvisor metrics with no (pod, namespace) labels while preserving ability to monitor system services resource usage (cardinality estimation)
            {
              sourceLabels: ['__name__', 'pod', 'namespace'],
              action: 'drop',
              regex: '(' + std.join('|',
                                    [
                                      'container_spec_.*',  // everything related to cgroup specification and thus static data (nodes*services*5)
                                      'container_file_descriptors',  // file descriptors limits and global numbers are exposed via (nodes*services)
                                      'container_sockets',  // used sockets in cgroup. Usually not important for system services (nodes*services)
                                      'container_threads_max',  // max number of threads in cgroup. Usually for system services it is not limited (nodes*services)
                                      'container_threads',  // used threads in cgroup. Usually not important for system services (nodes*services)
                                      'container_start_time_seconds',  // container start. Possibly not needed for system services (nodes*services)
                                      'container_last_seen',  // not needed as system services are always running (nodes*services)
                                    ]) + ');;',
            },
            {
              sourceLabels: ['__name__', 'container'],
              action: 'drop',
              regex: '(' + std.join('|',
                                    [
                                      'container_blkio_device_usage_total',
                                    ]) + ');.+',
            },
          ],
        },
        {
          port: 'https-metrics',
          scheme: 'https',
          path: '/metrics/probes',
          interval: '30s',
          honorLabels: true,
          tlsConfig: { insecureSkipVerify: true },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          relabelings: [{
            action: 'replace',
            sourceLabels: ['__metrics_path__'],
            targetLabel: 'metrics_path',
          }],
        },
        {
          port: 'https-metrics',
          scheme: 'https',
          path: '/metrics/slis',
          interval: '5s',
          honorLabels: true,
          tlsConfig: { insecureSkipVerify: true },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          relabelings: [
            {
              action: 'replace',
              sourceLabels: ['__metrics_path__'],
              targetLabel: 'metrics_path',
            },
          ],
          metricRelabelings: [
            {
              sourceLabels: ['__name__'],
              regex: 'process_start_time_seconds',
              action: 'drop',
            },
          ],
        },
      ],
      selector: {
        matchLabels: { 'app.kubernetes.io/name': 'kubelet' },
      },
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
    },
  },

  'kubelet-slo-request-errors': {
    apiVersion: 'pyrra.dev/v1alpha1',
    kind: 'ServiceLevelObjective',
    metadata: k8s._metadata {
      name: 'kubelet-request-errors',
      labels+: {
        'app.kubernetes.io/name': 'kubelet',
        prometheus: 'k8s',  //TODO
        role: 'alert-rules',
        'pyrra.dev/component': 'kubelet',
      },
    },
    spec: {
      target: k8s._config.kubelet.slos.requestErrors.target,
      window: k8s._config.kubelet.slos.requestErrors.window,
      description: |||
        The kubelet is the primary “node agent” that runs on each node.
        The kubelet ensures that the containers are running and healthy.
        If these requests are failing the Kubelet might not know what to run exactly.
      |||,
      indicator: {
        ratio: {
          errors: {
            metric: 'rest_client_requests_total{%s,code=~"5..|<error>"}' % [
              k8s._config.mixin._config.kubeletSelector,
            ],
          },
          total: {
            metric: 'rest_client_requests_total{%s}' % [
              k8s._config.mixin._config.kubeletSelector,
            ],
          },
        },
      },
    },
  },

  'kubelet-slo-runtime-errors': {
    apiVersion: 'pyrra.dev/v1alpha1',
    kind: 'ServiceLevelObjective',
    metadata: k8s._metadata {
      name: 'kubelet-runtime-errors',
      labels+: {
        'app.kubernetes.io/name': 'kubelet',
        prometheus: 'k8s',  //TODO
        role: 'alert-rules',
        'pyrra.dev/component': 'kubelet',
      },
    },
    spec: {
      target: k8s._config.kubelet.slos.runtimeErrors.target,
      window: k8s._config.kubelet.slos.runtimeErrors.window,
      description: |||
        The kubelet is the primary “node agent” that runs on each node.
        If there are runtime errors the kubelet might be unable to check the containers are running and healthy.
      |||,
      indicator: {
        ratio: {
          errors: {
            metric: 'kubelet_runtime_operations_errors_total{%s}' % [
              k8s._config.mixin._config.kubeletSelector,
            ],
          },
          total: {
            metric: 'kubelet_runtime_operations_total{%s}' % [
              k8s._config.mixin._config.kubeletSelector,
            ],
          },
        },
      },
    },
  },

  kubeControllerManagerServiceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: k8s._metadata {
      name: 'kube-controller-manager',
      labels+: { 'app.kubernetes.io/name': 'kube-controller-manager' },
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      endpoints: [
        {
          port: 'https-metrics',
          interval: '30s',
          scheme: 'https',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          tlsConfig: {
            insecureSkipVerify: true,
          },
          metricRelabelings: relabelings + [
            {
              sourceLabels: ['__name__'],
              regex: 'etcd_(debugging|disk|request|server).*',
              action: 'drop',
            },
          ],
        },
        {
          port: 'https-metrics',
          interval: '5s',
          scheme: 'https',
          path: '/metrics/slis',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          tlsConfig: {
            insecureSkipVerify: true,
          },
          metricRelabelings: [
            {
              sourceLabels: ['__name__'],
              regex: 'process_start_time_seconds',
              action: 'drop',
            },
          ],
        },
      ],
      selector: {
        matchLabels: { 'app.kubernetes.io/name': 'kube-controller-manager' },
      },
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
    },
  },

  kubeControllerManagerSLORequestErrors: {
    apiVersion: 'pyrra.dev/v1alpha1',
    kind: 'ServiceLevelObjective',
    metadata: k8s._metadata {
      name: 'kube-controller-manager-request-errors',
      labels+: {
        'app.kubernetes.io/name': 'kube-controller-manager',
        prometheus: 'k8s',  //TODO
        role: 'alert-rules',
        'pyrra.dev/component': 'kube-controller-manager',
      },
    },
    spec: {
      target: k8s._config.kubeControllerManager.slos.requestErrors.target,
      window: k8s._config.kubeControllerManager.slos.requestErrors.window,
      description: |||
        The Kubernetes controller manager is a daemon that embeds the core control loops shipped with Kubernetes. 
        In applications of robotics and automation, a control loop is a non-terminating loop that regulates the state of the system. 
        In Kubernetes, a controller is a control loop that watches the shared state of the cluster through the apiserver and makes changes attempting to move the current state towards the desired state. Examples of controllers that ship with Kubernetes today are the replication controller, endpoints controller, namespace controller, and serviceaccounts controller.
      |||,
      indicator: {
        ratio: {
          errors: {
            metric: 'rest_client_requests_total{%s,code=~"5..|<error>"}' % [
              k8s._config.mixin._config.kubeControllerManagerSelector,
            ],
          },
          total: {
            metric: 'rest_client_requests_total{%s}' % [
              k8s._config.mixin._config.kubeControllerManagerSelector,
            ],
          },
        },
      },
    },
  },

  serviceMonitorApiserver: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: k8s._metadata {
      name: 'kube-apiserver',
      labels+: { 'app.kubernetes.io/name': 'apiserver' },
    },
    spec: {
      jobLabel: 'component',
      selector: {
        matchLabels: {
          component: 'apiserver',
          provider: 'kubernetes',
        },
      },
      namespaceSelector: {
        matchNames: ['default'],
      },
      endpoints: [
        {
          port: 'https',
          interval: '30s',
          scheme: 'https',
          tlsConfig: {
            caFile: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
            serverName: 'kubernetes',
          },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          metricRelabelings: relabelings + [
            {
              sourceLabels: ['__name__'],
              regex: 'etcd_(debugging|disk|server).*',
              action: 'drop',
            },
            {
              sourceLabels: ['__name__'],
              regex: 'apiserver_admission_controller_admission_latencies_seconds_.*',
              action: 'drop',
            },
            {
              sourceLabels: ['__name__'],
              regex: 'apiserver_admission_step_admission_latencies_seconds_.*',
              action: 'drop',
            },
            {
              sourceLabels: ['__name__', 'le'],
              regex: '(apiserver_request|apiserver_request_sli|etcd_request)_duration_seconds_bucket;(0.15|0.25|0.3|0.35|0.4|0.45|0.6|0.7|0.8|0.9|1.25|1.5|1.75|2.5|3|3.5|4.5|6|7|8|9|15|25|30|50)',
              action: 'drop',
            },
            {
              sourceLabels: ['__name__', 'le'],
              regex: 'apiserver_request_body_size_bytes_bucket;(150000|350000|550000|650000|850000|950000|(1\\.15|1\\.35|1\\.55|1\\.65|1\\.85|1\\.95|2\\.15|2\\.35|2\\.55|2\\.65|2\\.85|2\\.95)e\\+06)',
              action: 'drop',
            },
          ],
        },
        {
          port: 'https',
          interval: '5s',
          scheme: 'https',
          path: '/metrics/slis',
          tlsConfig: {
            caFile: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
            serverName: 'kubernetes',
          },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          metricRelabelings: [
            {
              sourceLabels: ['__name__'],
              regex: 'process_start_time_seconds',
              action: 'drop',
            },
          ],
        },
      ],
    },
  },

  [if (defaults + params).kubeProxy then 'podMonitorKubeProxy']: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PodMonitor',
    metadata: k8s._metadata {
      labels+: { 'k8s-app': 'kube-proxy' },
      name: 'kube-proxy',
    },
    spec: {
      jobLabel: 'k8s-app',
      namespaceSelector: {
        matchNames: [
          'kube-system',
        ],
      },
      selector: {
        matchLabels: {
          'k8s-app': 'kube-proxy',
        },
      },
      podMetricsEndpoints: [{
        honorLabels: true,
        relabelings: [
          {
            action: 'replace',
            regex: '(.*)',
            replacement: '$1',
            sourceLabels: ['__meta_kubernetes_pod_node_name'],
            targetLabel: 'instance',
          },
          {
            action: 'replace',
            regex: '(.*)',
            replacement: '$1:10249',
            targetLabel: '__address__',
            sourceLabels: ['__meta_kubernetes_pod_ip'],
          },
        ],
      }],
    },
  },

  [if (defaults + params).kubeProxy then 'kubeProxySLOSyncRulesLatency']: {
    apiVersion: 'pyrra.dev/v1alpha1',
    kind: 'ServiceLevelObjective',
    metadata: k8s._metadata {
      name: 'kube-proxy-sync-rules-latency',
      labels+: {
        'app.kubernetes.io/name': 'kube-proxy',
        'app.kubernetes.io/component': 'controller',  //TODO
        prometheus: 'k8s',  // TODO
        'pyrra.dev/component': 'kube-proxy',
        role: 'alert-rules',
      },
    },
    spec: {
      target: k8s._config.kubeProxyConfig.slos.syncRulesLatency.target,
      window: k8s._config.kubeProxyConfig.slos.syncRulesLatency.window,
      description: |||
        The Kubernetes network proxy runs on each node. 
        This reflects services as defined in the Kubernetes API on each node and can do simple TCP, UDP
        stream forwarding or round robin TCP,UDP forwarding across a set of backends. 

        If this is firing the networks might not be synchronized fast enough and services might be unable to reach the containers they want to reach.
      |||,
      indicator: {
        latency: {
          success: {
            metric: 'kubeproxy_sync_proxy_rules_duration_seconds_bucket{%s,le="%s"}' % [
              k8s._config.mixin._config.kubeProxySelector,
              k8s._config.kubeProxyConfig.slos.syncRulesLatency.latency,
            ],
          },
          total: {
            metric: 'kubeproxy_sync_proxy_rules_duration_seconds_count{%s}' % [
              k8s._config.mixin._config.kubeProxySelector,
            ],
          },
        },
      },
    },
  },

  kubeProxySLORequestErrors: {
    apiVersion: 'pyrra.dev/v1alpha1',
    kind: 'ServiceLevelObjective',
    metadata: k8s._metadata {
      name: 'kube-proxy-request-errors',
      labels+: {
        'app.kubernetes.io/name': 'kube-proxy',
        'app.kubernetes.io/component': 'controller',  //TODO
        prometheus: 'k8s',  // TODO
        'pyrra.dev/component': 'kube-proxy',
        role: 'alert-rules',
      },
    },
    spec: {
      target: k8s._config.kubeProxyConfig.slos.requestErrors.target,
      window: k8s._config.kubeProxyConfig.slos.requestErrors.window,
      description: '',
      indicator: {
        ratio: {
          errors: {
            metric: 'rest_client_requests_total{%s,code=~"5..|<error>"}' % [
              k8s._config.mixin._config.kubeProxySelector,
            ],
          },
          total: {
            metric: 'rest_client_requests_total{%s}' % [
              k8s._config.mixin._config.kubeProxySelector,
            ],
          },
        },
      },
    },
  },

  'coredns-ServiceMonitor': {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: k8s._metadata {
      name: k8s._config.coredns.name,
      labels+: { 'app.kubernetes.io/name': k8s._config.coredns.name },
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      selector: {
        matchLabels: { 'k8s-app': k8s._config.coredns.name },
      },
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
      endpoints: [
        {
          port: 'metrics',
          interval: '15s',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          metricRelabelings: [
            // Drop deprecated metrics
            // TODO (pgough) - consolidate how we drop metrics across the project
            {
              sourceLabels: ['__name__'],
              regex: 'coredns_cache_misses_total',
              action: 'drop',
            },
          ],
        },
      ],
    },
  },

  'coredns-slo-response-errors': {
    apiVersion: 'pyrra.dev/v1alpha1',
    kind: 'ServiceLevelObjective',
    metadata: k8s._metadata {
      name: k8s._config.coredns.name + '-response-errors',
      labels+: {
        'app.kubernetes.io/name': k8s._config.coredns.name,
        'app.kubernetes.io/component': 'controller',
        prometheus: 'k8s',  // TODO
        'pyrra.dev/component': k8s._config.coredns.name,
        role: 'alert-rules',
      },
    },
    spec: {
      target: k8s._config.coredns.slos.responseErrors.target,
      window: k8s._config.coredns.slos.responseErrors.window,
      description: |||
        CoreDNS runs within a Kubernetes cluster and resolves internal requests and forward external requests.
        If CoreDNS fails to answer requests applications might be unable to make requests.
      |||,
      indicator: {
        ratio: {
          errors: {
            metric: 'coredns_dns_responses_total{%s,rcode="SERVFAIL"}' % [
              k8s._config.mixin._config.coreDNSSelector,
            ],
          },
          total: {
            metric: 'coredns_dns_responses_total{%s}' % [
              k8s._config.mixin._config.coreDNSSelector,
            ],
          },
        },
      },
    },
  },

  'coredns-slo-response-latency': {
    apiVersion: 'pyrra.dev/v1alpha1',
    kind: 'ServiceLevelObjective',
    metadata: k8s._metadata {
      name: k8s._config.coredns.name + '-response-latency',
      labels+: {
        'app.kubernetes.io/name': 'coredns',
        'app.kubernetes.io/component': 'controller',
        prometheus: 'k8s',  // TODO
        'pyrra.dev/component': 'coredns',
        role: 'alert-rules',
      },
    },
    spec: {
      target: k8s._config.coredns.slos.responseLatency.target,
      window: k8s._config.coredns.slos.responseLatency.window,
      description: |||
        CoreDNS runs within a Kubernetes cluster and resolves internal requests and forward external requests.
        If CoreDNS gets too slow it might have an impact on the latency of other applications in this cluster.
      |||,
      indicator: {
        latency: {
          success: {
            metric: 'coredns_dns_request_duration_seconds_bucket{%s,le="%s"}' % [
              k8s._config.mixin._config.coreDNSSelector,
              k8s._config.coredns.slos.responseLatency.latency,
            ],
          },
          total: {
            metric: 'coredns_dns_request_duration_seconds_count{%s}' % [
              k8s._config.mixin._config.coreDNSSelector,
            ],
          },
        },
      },
    },
  },
}
