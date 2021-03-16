local relabelings = import '../addons/dropping-deprecated-metrics-relabelings.libsonnet';

local defaults = {
  namespace: error 'must provide namespace',
  commonLabels:: {
    'app.kubernetes.io/name': 'kube-prometheus',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  mixin: {
    ruleLabels: {},
    _config: {
      cadvisorSelector: 'job="kubelet", metrics_path="/metrics/cadvisor"',
      kubeletSelector: 'job="kubelet", metrics_path="/metrics"',
      kubeStateMetricsSelector: 'job="kube-state-metrics"',
      nodeExporterSelector: 'job="node-exporter"',
      kubeSchedulerSelector: 'job="kube-scheduler"',
      kubeControllerManagerSelector: 'job="kube-controller-manager"',
      kubeApiserverSelector: 'job="apiserver"',
      podLabel: 'pod',
      runbookURLPattern: 'https://github.com/prometheus-operator/kube-prometheus/wiki/%s',
      diskDeviceSelector: 'device=~"mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|dasd.+"',
      hostNetworkInterfaceSelector: 'device!~"veth.+"',
    },
  },
};

function(params) {
  local k8s = self,
  _config:: defaults + params,

  mixin:: (import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet') {
    _config+:: k8s._config.mixin._config,
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: k8s._config.commonLabels + k8s._config.mixin.ruleLabels,
      name: 'kubernetes-monitoring-rules',
      namespace: k8s._config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(k8s.mixin, 'prometheusRules') then k8s.mixin.prometheusRules.groups else {},
      local a = if std.objectHasAll(k8s.mixin, 'prometheusAlerts') then k8s.mixin.prometheusAlerts.groups else {},
      groups: a + r,
    },
  },

  serviceMonitorKubeScheduler: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'kube-scheduler',
      namespace: k8s._config.namespace,
      labels: { 'app.kubernetes.io/name': 'kube-scheduler' },
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      endpoints: [{
        port: 'https-metrics',
        interval: '30s',
        scheme: 'https',
        bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
        tlsConfig: { insecureSkipVerify: true },
      }],
      selector: {
        matchLabels: { 'app.kubernetes.io/name': 'kube-scheduler' },
      },
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
    },
  },

  serviceMonitorKubelet: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'kubelet',
      namespace: k8s._config.namespace,
      labels: { 'app.kubernetes.io/name': 'kubelet' },
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
            sourceLabels: ['__metrics_path__'],
            targetLabel: 'metrics_path',
          }],
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

  serviceMonitorKubeControllerManager: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'kube-controller-manager',
      namespace: k8s._config.namespace,
      labels: { 'app.kubernetes.io/name': 'kube-controller-manager' },
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      endpoints: [{
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
      }],
      selector: {
        matchLabels: { 'app.kubernetes.io/name': 'kube-controller-manager' },
      },
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
    },
  },

  serviceMonitorApiserver: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'kube-apiserver',
      namespace: k8s._config.namespace,
      labels: { 'app.kubernetes.io/name': 'apiserver' },
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
      endpoints: [{
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
            regex: 'apiserver_request_duration_seconds_bucket;(0.15|0.25|0.3|0.35|0.4|0.45|0.6|0.7|0.8|0.9|1.25|1.5|1.75|2.5|3|3.5|4.5|6|7|8|9|15|25|30|50)',
            action: 'drop',
          },
        ],
      }],
    },
  },

  serviceMonitorCoreDNS: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'coredns',
      namespace: k8s._config.namespace,
      labels: { 'app.kubernetes.io/name': 'coredns' },
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      selector: {
        matchLabels: { 'app.kubernetes.io/name': 'kube-dns' },
      },
      namespaceSelector: {
        matchNames: ['kube-system'],
      },
      endpoints: [{
        port: 'metrics',
        interval: '15s',
        bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
      }],
    },
  },


}
