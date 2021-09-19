local defaults = {
  local defaults = self,
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  resources: {
    requests: { memory: '400Mi' },
  },

  name: error 'must provide name',
  alertmanagerName: error 'must provide alertmanagerName',
  namespaces: ['default', 'kube-system', defaults.namespace],
  replicas: 2,
  externalLabels: {},
  enableFeatures: [],
  commonLabels:: {
    'app.kubernetes.io/name': 'prometheus',
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'prometheus',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  } + { prometheus: defaults.name },
  ruleSelector: {},
  mixin: {
    ruleLabels: {},
    _config: {
      prometheusSelector: 'job="prometheus-' + defaults.name + '",namespace="' + defaults.namespace + '"',
      prometheusName: '{{$labels.namespace}}/{{$labels.pod}}',
      thanosSelector: 'job="thanos-sidecar"',
      runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/prometheus/%s',
    },
  },
  thanos: null,
};


function(params) {
  local p = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(p._config.resources),
  assert std.isObject(p._config.mixin._config),

  mixin::
    (import 'github.com/prometheus/prometheus/documentation/prometheus-mixin/mixin.libsonnet') +
    (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') + {
      _config+:: p._config.mixin._config,
    },

  mixinThanos::
    (import 'github.com/thanos-io/thanos/mixin/alerts/sidecar.libsonnet') +
    (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') + {
      _config+:: p._config.mixin._config,
      targetGroups: {},
      sidecar: {
        selector: p._config.mixin._config.thanosSelector,
        dimensions: std.join(', ', ['job', 'instance']),
      },
    },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: p._config.commonLabels + p._config.mixin.ruleLabels,
      name: 'prometheus-' + p._config.name + '-prometheus-rules',
      namespace: p._config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(p.mixin, 'prometheusRules') then p.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(p.mixin, 'prometheusAlerts') then p.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: 'prometheus-' + p._config.name,
      namespace: p._config.namespace,
      labels: p._config.commonLabels,
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'prometheus-' + p._config.name,
      namespace: p._config.namespace,
      labels: { prometheus: p._config.name } + p._config.commonLabels,
    },
    spec: {
      ports: [
               { name: 'web', targetPort: 'web', port: 9090 },
             ] +
             (
               if p._config.thanos != null then
                 [{ name: 'grpc', port: 10901, targetPort: 10901 }]
               else []
             ),
      selector: { app: 'prometheus' } + p._config.selectorLabels,
      sessionAffinity: 'ClientIP',
    },
  },

  roleBindingSpecificNamespaces:
    local newSpecificRoleBinding(namespace) = {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBinding',
      metadata: {
        name: 'prometheus-' + p._config.name,
        namespace: namespace,
        labels: p._config.commonLabels,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'prometheus-' + p._config.name,
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: 'prometheus-' + p._config.name,
        namespace: p._config.namespace,
      }],
    };
    {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBindingList',
      items: [newSpecificRoleBinding(x) for x in p._config.namespaces],
    },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'prometheus-' + p._config.name,
      labels: p._config.commonLabels,
    },
    rules: [
      {
        apiGroups: [''],
        resources: ['nodes/metrics'],
        verbs: ['get'],
      },
      {
        nonResourceURLs: ['/metrics'],
        verbs: ['get'],
      },
    ],
  },

  roleConfig: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'Role',
    metadata: {
      name: 'prometheus-' + p._config.name + '-config',
      namespace: p._config.namespace,
      labels: p._config.commonLabels,
    },
    rules: [{
      apiGroups: [''],
      resources: ['configmaps'],
      verbs: ['get'],
    }],
  },

  roleBindingConfig: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'RoleBinding',
    metadata: {
      name: 'prometheus-' + p._config.name + '-config',
      namespace: p._config.namespace,
      labels: p._config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'prometheus-' + p._config.name + '-config',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: 'prometheus-' + p._config.name,
      namespace: p._config.namespace,
    }],
  },

  clusterRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      name: 'prometheus-' + p._config.name,
      labels: p._config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'prometheus-' + p._config.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: 'prometheus-' + p._config.name,
      namespace: p._config.namespace,
    }],
  },

  roleSpecificNamespaces:
    local newSpecificRole(namespace) = {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'Role',
      metadata: {
        name: 'prometheus-' + p._config.name,
        namespace: namespace,
        labels: p._config.commonLabels,
      },
      rules: [
        {
          apiGroups: [''],
          resources: ['services', 'endpoints', 'pods'],
          verbs: ['get', 'list', 'watch'],
        },
        {
          apiGroups: ['extensions'],
          resources: ['ingresses'],
          verbs: ['get', 'list', 'watch'],
        },
        {
          apiGroups: ['networking.k8s.io'],
          resources: ['ingresses'],
          verbs: ['get', 'list', 'watch'],
        },
      ],
    };
    {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleList',
      items: [newSpecificRole(x) for x in p._config.namespaces],
    },

  [if (defaults + params).replicas > 1 then 'podDisruptionBudget']: {
    apiVersion: 'policy/v1beta1',
    kind: 'PodDisruptionBudget',
    metadata: {
      name: 'prometheus-' + p._config.name,
      namespace: p._config.namespace,
      labels: p._config.commonLabels,
    },
    spec: {
      minAvailable: 1,
      selector: {
        matchLabels: {
          prometheus: p._config.name,
        } + p._config.selectorLabels,
      },
    },
  },

  prometheus: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'Prometheus',
    metadata: {
      name: p._config.name,
      namespace: p._config.namespace,
      labels: { prometheus: p._config.name } + p._config.commonLabels,
    },
    spec: {
      replicas: p._config.replicas,
      version: p._config.version,
      image: p._config.image,
      podMetadata: {
        labels: p._config.commonLabels,
      },
      externalLabels: p._config.externalLabels,
      enableFeatures: p._config.enableFeatures,
      serviceAccountName: 'prometheus-' + p._config.name,
      podMonitorSelector: {},
      podMonitorNamespaceSelector: {},
      probeSelector: {},
      probeNamespaceSelector: {},
      ruleNamespaceSelector: {},
      ruleSelector: p._config.ruleSelector,
      serviceMonitorSelector: {},
      serviceMonitorNamespaceSelector: {},
      nodeSelector: { 'kubernetes.io/os': 'linux' },
      resources: p._config.resources,
      alerting: {
        alertmanagers: [{
          namespace: p._config.namespace,
          name: 'alertmanager-' + p._config.alertmanagerName,
          port: 'web',
          apiVersion: 'v2',
        }],
      },
      securityContext: {
        runAsUser: 1000,
        runAsNonRoot: true,
        fsGroup: 2000,
      },
      [if std.objectHas(params, 'thanos') then 'thanos']: p._config.thanos,
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'prometheus-' + p._config.name,
      namespace: p._config.namespace,
      labels: p._config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: p._config.selectorLabels,
      },
      endpoints: [{
        port: 'web',
        interval: '30s',
      }],
    },
  },

  // Include thanos sidecar PrometheusRule only if thanos config was passed by user
  [if std.objectHas(params, 'thanos') && params.thanos != null then 'prometheusRuleThanosSidecar']: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: p._config.commonLabels + p._config.mixin.ruleLabels,
      name: 'prometheus-' + p._config.name + '-thanos-sidecar-rules',
      namespace: p._config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(p.mixinThanos, 'prometheusRules') then p.mixinThanos.prometheusRules.groups else [],
      local a = if std.objectHasAll(p.mixinThanos, 'prometheusAlerts') then p.mixinThanos.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  // Include thanos sidecar Service only if thanos config was passed by user
  [if std.objectHas(params, 'thanos') && params.thanos != null then 'serviceThanosSidecar']: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata+: {
      name: 'prometheus-' + p._config.name + '-thanos-sidecar',
      namespace: p._config.namespace,
      labels+: p._config.commonLabels {
        prometheus: p._config.name,
        'app.kubernetes.io/component': 'thanos-sidecar',
      },
    },
    spec+: {
      ports: [
        { name: 'grpc', port: 10901, targetPort: 10901 },
        { name: 'http', port: 10902, targetPort: 10902 },
      ],
      selector: p._config.selectorLabels {
        prometheus: p._config.name,
        'app.kubernetes.io/component': 'prometheus',
      },
      clusterIP: 'None',
    },
  },

  // Include thanos sidecar ServiceMonitor only if thanos config was passed by user
  [if std.objectHas(params, 'thanos') && params.thanos != null then 'serviceMonitorThanosSidecar']: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: 'thanos-sidecar',
      namespace: p._config.namespace,
      labels: p._config.commonLabels {
        prometheus: p._config.name,
        'app.kubernetes.io/component': 'thanos-sidecar',
      },
    },
    spec+: {
      jobLabel: 'app.kubernetes.io/component',
      selector: {
        matchLabels: {
          prometheus: p._config.name,
          'app.kubernetes.io/component': 'thanos-sidecar',
        },
      },
      endpoints: [{
        port: 'http',
        interval: '30s',
      }],
    },
  },
}
