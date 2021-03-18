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
  ruleSelector: {
    matchLabels: defaults.mixin.ruleLabels,
  },
  mixin: {
    ruleLabels: {
      role: 'alert-rules',
      prometheus: defaults.name,
    },
    _config: {
      prometheusSelector: 'job="prometheus-' + defaults.name + '",namespace="' + defaults.namespace + '"',
      prometheusName: '{{$labels.namespace}}/{{$labels.pod}}',
      thanosSelector: 'job="thanos-sidecar"',
      runbookURLPattern: 'https://github.com/prometheus-operator/kube-prometheus/wiki/%s',
    },
  },
  thanos: {},
};


function(params) {
  local p = self,
  config:: defaults + params,
  // Safety check
  assert std.isObject(p.config.resources),
  assert std.isObject(p.config.mixin._config),

  mixin:: (import 'github.com/prometheus/prometheus/documentation/prometheus-mixin/mixin.libsonnet') +
          (import 'github.com/kubernetes-monitoring/kubernetes-mixin/alerts/add-runbook-links.libsonnet') + (
    if p.config.thanos != {} then
      (import 'github.com/thanos-io/thanos/mixin/alerts/sidecar.libsonnet') + {
        sidecar: {
          selector: p.config.mixin._config.thanosSelector,
        },
      }
    else {}
  ) {
    _config+:: p.config.mixin._config,
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: p.config.commonLabels + p.config.mixin.ruleLabels,
      name: 'prometheus-' + p.config.name + '-prometheus-rules',
      namespace: p.config.namespace,
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
      name: 'prometheus-' + p.config.name,
      namespace: p.config.namespace,
      labels: p.config.commonLabels,
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'prometheus-' + p.config.name,
      namespace: p.config.namespace,
      labels: { prometheus: p.config.name } + p.config.commonLabels,
    },
    spec: {
      ports: [
               { name: 'web', targetPort: 'web', port: 9090 },
             ] +
             (
               if p.config.thanos != {} then
                 [{ name: 'grpc', port: 10901, targetPort: 10901 }]
               else []
             ),
      selector: { app: 'prometheus' } + p.config.selectorLabels,
      sessionAffinity: 'ClientIP',
    },
  },

  roleBindingSpecificNamespaces:
    local newSpecificRoleBinding(namespace) = {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBinding',
      metadata: {
        name: 'prometheus-' + p.config.name,
        namespace: namespace,
        labels: p.config.commonLabels,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'prometheus-' + p.config.name,
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: 'prometheus-' + p.config.name,
        namespace: p.config.namespace,
      }],
    };
    {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBindingList',
      items: [newSpecificRoleBinding(x) for x in p.config.namespaces],
    },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'prometheus-' + p.config.name,
      labels: p.config.commonLabels,
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
      name: 'prometheus-' + p.config.name + '-config',
      namespace: p.config.namespace,
      labels: p.config.commonLabels,
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
      name: 'prometheus-' + p.config.name + '-config',
      namespace: p.config.namespace,
      labels: p.config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'prometheus-' + p.config.name + '-config',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: 'prometheus-' + p.config.name,
      namespace: p.config.namespace,
    }],
  },

  clusterRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      name: 'prometheus-' + p.config.name,
      labels: p.config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'prometheus-' + p.config.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: 'prometheus-' + p.config.name,
      namespace: p.config.namespace,
    }],
  },

  roleSpecificNamespaces:
    local newSpecificRole(namespace) = {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'Role',
      metadata: {
        name: 'prometheus-' + p.config.name,
        namespace: namespace,
        labels: p.config.commonLabels,
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
      ],
    };
    {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleList',
      items: [newSpecificRole(x) for x in p.config.namespaces],
    },

  [if (defaults + params).replicas > 1 then 'podDisruptionBudget']: {
    apiVersion: 'policy/v1beta1',
    kind: 'PodDisruptionBudget',
    metadata: {
      name: 'prometheus-' + p.config.name,
      namespace: p.config.namespace,
      labels: p.config.commonLabels,
    },
    spec: {
      minAvailable: 1,
      selector: {
        matchLabels: {
          prometheus: p.config.name,
        } + p.config.selectorLabels,
      },
    },
  },

  prometheus: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'Prometheus',
    metadata: {
      name: p.config.name,
      namespace: p.config.namespace,
      labels: { prometheus: p.config.name } + p.config.commonLabels,
    },
    spec: {
      replicas: p.config.replicas,
      version: p.config.version,
      image: p.config.image,
      podMetadata: {
        labels: p.config.commonLabels,
      },
      externalLabels: p.config.externalLabels,
      serviceAccountName: 'prometheus-' + p.config.name,
      serviceMonitorSelector: {},
      podMonitorSelector: {},
      probeSelector: {},
      serviceMonitorNamespaceSelector: {},
      podMonitorNamespaceSelector: {},
      probeNamespaceSelector: {},
      nodeSelector: { 'kubernetes.io/os': 'linux' },
      ruleSelector: p.config.ruleSelector,
      resources: p.config.resources,
      alerting: {
        alertmanagers: [{
          namespace: p.config.namespace,
          name: 'alertmanager-' + p.config.alertmanagerName,
          port: 'web',
          apiVersion: 'v2',
        }],
      },
      securityContext: {
        runAsUser: 1000,
        runAsNonRoot: true,
        fsGroup: 2000,
      },
      [if std.objectHas(params, 'thanos') then 'thanos']: p.config.thanos,
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'prometheus-' + p.config.name,
      namespace: p.config.namespace,
      labels: p.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: p.config.selectorLabels,
      },
      endpoints: [{
        port: 'web',
        interval: '30s',
      }],
    },
  },

  // Include thanos sidecar Service only if thanos config was passed by user
  [if std.objectHas(params, 'thanos') && std.length(params.thanos) > 0 then 'serviceThanosSidecar']: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata+: {
      name: 'prometheus-' + p.config.name + '-thanos-sidecar',
      namespace: p.config.namespace,
      labels+: p.config.commonLabels {
        prometheus: p.config.name,
        'app.kubernetes.io/component': 'thanos-sidecar',
      },
    },
    spec+: {
      ports: [
        { name: 'grpc', port: 10901, targetPort: 10901 },
        { name: 'http', port: 10902, targetPort: 10902 },
      ],
      selector: p.config.selectorLabels {
        prometheus: p.config.name,
        'app.kubernetes.io/component': 'prometheus',
      },
      clusterIP: 'None',
    },
  },

  // Include thanos sidecar ServiceMonitor only if thanos config was passed by user
  [if std.objectHas(params, 'thanos') && std.length(params.thanos) > 0 then 'serviceMonitorThanosSidecar']: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: 'thanos-sidecar',
      namespace: p.config.namespace,
      labels: p.config.commonLabels {
        prometheus: p.config.name,
        'app.kubernetes.io/component': 'thanos-sidecar',
      },
    },
    spec+: {
      jobLabel: 'app.kubernetes.io/component',
      selector: {
        matchLabels: {
          prometheus: p.config.name,
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
