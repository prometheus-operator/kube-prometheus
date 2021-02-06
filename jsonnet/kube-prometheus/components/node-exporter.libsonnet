local krp = import './kube-rbac-proxy.libsonnet';

local defaults = {
  local defaults = self,
  name: 'node-exporter',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide version',
  resources: {
    requests: { cpu: '102m', memory: '180Mi' },
    limits: { cpu: '250m', memory: '180Mi' },
  },
  listenAddress: '127.0.0.1',
  port: 9100,
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'exporter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  mixin: {
    ruleLabels: {},
    _config: {
      nodeExporterSelector: 'job="' + defaults.name + '"',
      fsSpaceFillingUpCriticalThreshold: 15,
      diskDeviceSelector: 'device=~"mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|dasd.+"',
    },
  },
};


function(params) {
  local ne = self,
  config:: defaults + params,
  // Safety check
  assert std.isObject(ne.config.resources),
  assert std.isObject(ne.config.mixin._config),

  mixin:: (import 'github.com/prometheus/node_exporter/docs/node-mixin/mixin.libsonnet') {
    _config+:: ne.config.mixin._config,
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: ne.config.commonLabels + ne.config.mixin.ruleLabels,
      name: ne.config.name + '-rules',
      namespace: ne.config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(ne.mixin, 'prometheusRules') then ne.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(ne.mixin, 'prometheusAlerts') then ne.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  clusterRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      name: ne.config.name,
      labels: ne.config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: ne.config.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: ne.config.name,
      namespace: ne.config.namespace,
    }],
  },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: ne.config.name,
      labels: ne.config.commonLabels,
    },
    rules: [
      {
        apiGroups: ['authentication.k8s.io'],
        resources: ['tokenreviews'],
        verbs: ['create'],
      },
      {
        apiGroups: ['authorization.k8s.io'],
        resources: ['subjectaccessreviews'],
        verbs: ['create'],
      },
    ],
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: ne.config.name,
      namespace: ne.config.namespace,
      labels: ne.config.commonLabels,
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: ne.config.name,
      namespace: ne.config.namespace,
      labels: ne.config.commonLabels,
    },
    spec: {
      ports: [
        { name: 'https', targetPort: 'https', port: ne.config.port },
      ],
      selector: ne.config.selectorLabels,
      clusterIP: 'None',
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: ne.config.name,
      namespace: ne.config.namespace,
      labels: ne.config.commonLabels,
    },
    spec: {
      jobLabel: 'app.kubernetes.io/name',
      selector: {
        matchLabels: ne.config.selectorLabels,
      },
      endpoints: [{
        port: 'https',
        scheme: 'https',
        interval: '15s',
        bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
        relabelings: [
          {
            action: 'replace',
            regex: '(.*)',
            replacement: '$1',
            sourceLabels: ['__meta_kubernetes_pod_node_name'],
            targetLabel: 'instance',
          },
        ],
        tlsConfig: {
          insecureSkipVerify: true,
        },
      }],
    },
  },

  daemonset:
    local nodeExporter = {
      name: ne.config.name,
      image: ne.config.image,
      args: [
        '--web.listen-address=' + std.join(':', [ne.config.listenAddress, std.toString(ne.config.port)]),
        '--path.sysfs=/host/sys',
        '--path.rootfs=/host/root',
        '--no-collector.wifi',
        '--no-collector.hwmon',
        '--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)',
        '--collector.netclass.ignored-devices=^(veth.*)$',
        '--collector.netdev.device-exclude=^(veth.*)$',
      ],
      volumeMounts: [
        { name: 'sys', mountPath: '/host/sys', mountPropagation: 'HostToContainer', readOnly: true },
        { name: 'root', mountPath: '/host/root', mountPropagation: 'HostToContainer', readOnly: true },
      ],
      resources: ne.config.resources,
    };

    local kubeRbacProxy = krp({
      name: 'kube-rbac-proxy',
      //image: krpImage,
      upstream: 'http://127.0.0.1:' + ne.config.port + '/',
      secureListenAddress: '[$(IP)]:' + ne.config.port,
      // Keep `hostPort` here, rather than in the node-exporter container
      // because Kubernetes mandates that if you define a `hostPort` then
      // `containerPort` must match. In our case, we are splitting the
      // host port and container port between the two containers.
      // We'll keep the port specification here so that the named port
      // used by the service is tied to the proxy container. We *could*
      // forgo declaring the host port, however it is important to declare
      // it so that the scheduler can decide if the pod is schedulable.
      ports: [
        { name: 'https', containerPort: ne.config.port, hostPort: ne.config.port },
      ],
    }) + {
      env: [
        { name: 'IP', valueFrom: { fieldRef: { fieldPath: 'status.podIP' } } },
      ],
    };

    {
      apiVersion: 'apps/v1',
      kind: 'DaemonSet',
      metadata: {
        name: ne.config.name,
        namespace: ne.config.namespace,
        labels: ne.config.commonLabels,
      },
      spec: {
        selector: { matchLabels: ne.config.selectorLabels },
        updateStrategy: {
          type: 'RollingUpdate',
          rollingUpdate: { maxUnavailable: '10%' },
        },
        template: {
          metadata: { labels: ne.config.commonLabels },
          spec: {
            nodeSelector: { 'kubernetes.io/os': 'linux' },
            tolerations: [{
              operator: 'Exists',
            }],
            containers: [nodeExporter, kubeRbacProxy],
            volumes: [
              { name: 'sys', hostPath: { path: '/sys' } },
              { name: 'root', hostPath: { path: '/' } },
            ],
            serviceAccountName: ne.config.name,
            securityContext: {
              runAsUser: 65534,
              runAsNonRoot: true,
            },
            hostPID: true,
            hostNetwork: true,
          },
        },
      },
    },


}
