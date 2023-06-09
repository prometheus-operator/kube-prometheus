local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  name:: 'cadvisor',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide version',
  resources:: {
    requests: { cpu: '400m', memory: '400Mi' },
    limits: { cpu: '800m', memory: '2000Mi' },
  },
  listenAddress:: '127.0.0.1',
  port:: 8080,
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
  mixin:: {
    ruleLabels: {},
    _config: {
      cadvisorSelector: 'job="cadvisor"',
    },
  },
};

function(params) {
  local ne = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(ne._config.resources),
  assert std.isObject(ne._config.mixin._config),
  _metadata:: {
    name: ne._config.name,
    namespace: ne._config.namespace,
    labels: ne._config.commonLabels,
  },

  clusterRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: ne._metadata,
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: ne._config.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: ne._config.name,
      namespace: ne._config.namespace,
    }],
  },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: ne._metadata,
    rules: [
      {
        apiGroups: ['policy'],
        resourceNames: ['cadvisor'],
        resources: ['podsecuritypolicies'],
        verbs: ['use'],
      },
    ],
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: ne._metadata,
    automountServiceAccountToken: false,
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: ne._metadata,
    spec: {
      ports: [
        { name: 'http', targetPort: ne._config.port, port: ne._config.port },
      ],
      selector: ne._config.selectorLabels,
      clusterIP: 'None',
    },
  },

  daemonset:
    local cAdvisor = {
      name: ne._config.name,
      image: ne._config.image,
      args: [
        '--housekeeping_interval=10s',
        '--max_housekeeping_interval=15s',
        '--event_storage_event_limit=default=0',
        '--event_storage_age_limit=default=0',
        '--enable_metrics=app,cpu,disk,diskIO,memory,network,process',
        '--docker_only',
        '--store_container_labels=false',
        '--whitelisted_container_labels=io.kubernetes.container.name,io.kubernetes.pod.name,io.kubernetes.pod.namespace',
      ],
      ports: [{ name: 'http', containerPort: ne._config.port }],
      volumeMounts: [{
        mountPath: '/rootfs',
        name: 'rootfs',
        readOnly: true,
      },{
        mountPath: '/var/run',
        name: 'var-run',
        readOnly: true,
      },{
        mountPath: '/sys',
          name: 'sys',
          readOnly: true,
      },{
        mountPath: '/var/lib/docker',
        name: 'docker',
        readOnly: true,
      },{
        mountPath: '/dev/disk',
        name: 'disk',
        readOnly: true,
      }],
      resources: ne._config.resources,
    };

    {
      apiVersion: 'apps/v1',
      kind: 'DaemonSet',
      metadata: ne._metadata,
      spec: {
        selector: {
          matchLabels: ne._config.selectorLabels,
        },
        updateStrategy: {
          type: 'RollingUpdate',
          rollingUpdate: { maxUnavailable: '10%' },
        },
        template: {
          metadata: {
            annotations: {
              'kubectl.kubernetes.io/default-container': cAdvisor.name,
            },
            labels: ne._config.commonLabels,
          },
          spec: {
            nodeSelector: { 'kubernetes.io/os': 'linux' },
            tolerations: [{
              operator: 'Exists',
            }],
            containers: [cAdvisor],
            volumes: [
              { name: 'rootfs', hostPath: { path: '/' } },
              { name: 'var-run', hostPath: { path: '/var/run' } },
              { name: 'sys', hostPath: { path: '/sys' } },
              { name: 'docker', hostPath: { path: '/var/lib/docker' } },
              { name: 'disk', hostPath: { path: '/dev/disk' } },
            ],
            automountServiceAccountToken: false,
            serviceAccountName: ne._config.name,
            priorityClassName: 'system-cluster-critical',
          },
        },
      },
    },
}