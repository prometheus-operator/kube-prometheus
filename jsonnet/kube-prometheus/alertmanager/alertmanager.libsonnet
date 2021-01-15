local defaults = {
  local defaults = self,
  namespace: error 'must provide namespace',
  image: error 'must provide image',
  version: error 'must provide version',
  resources: {},
  commonLabels:: {
    'app.kubernetes.io/name': 'alertmanager',
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'alert-router',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  name: error 'must provide name',
  config: {
    global: {
      resolve_timeout: '5m',
    },
    inhibit_rules: [{
      source_match: {
        severity: 'critical',
      },
      target_match_re: {
        severity: 'warning|info',
      },
      equal: ['namespace', 'alertname'],
    }, {
      source_match: {
        severity: 'warning',
      },
      target_match_re: {
        severity: 'info',
      },
      equal: ['namespace', 'alertname'],
    }],
    route: {
      group_by: ['namespace'],
      group_wait: '30s',
      group_interval: '5m',
      repeat_interval: '12h',
      receiver: 'Default',
      routes: [
        { receiver: 'Watchdog', match: { alertname: 'Watchdog' } },
        { receiver: 'Critical', match: { severity: 'critical' } },
      ],
    },
    receivers: [
      { name: 'Default' },
      { name: 'Watchdog' },
      { name: 'Critical' },
    ],
  },
  replicas: 3,
  mixin: {
    ruleLabels: {},
    _config: {
      alertmanagerName: '{{ $labels.namespace }}/{{ $labels.pod}}',
      alertmanagerClusterLabels: 'namespace,service',
      alertmanagerSelector: 'job="alertmanager-' + defaults.name + '",namespace="' + defaults.namespace + '"',
    },
  },
};


function(params) {
  local am = self,
  config:: defaults + params,
  // Safety check
  assert std.isObject(am.config.resources),
  assert std.isObject(am.config.mixin._config),

  mixin:: (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/mixin.libsonnet') {
    _config+:: am.config.mixin._config,
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: am.config.commonLabels + am.config.mixin.ruleLabels,
      name: am.config.name + '-rules',
      namespace: am.config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(am.mixin, 'prometheusRules') then am.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(am.mixin, 'prometheusAlerts') then am.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  secret: {
    apiVersion: 'v1',
    kind: 'Secret',
    type: 'Opaque',
    metadata: {
      name: 'alertmanager-' + am.config.name,
      namespace: am.config.namespace,
      labels: { alertmanager: am.config.name } + am.config.commonLabels,
    },
    stringData: {
      'alertmanager.yaml': if std.type(am.config.config) == 'object'
      then
        std.manifestYamlDoc(am.config.config)
      else
        am.config.config,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: 'alertmanager-' + am.config.name,
      namespace: am.config.namespace,
      labels: { alertmanager: am.config.name } + am.config.commonLabels,
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'alertmanager-' + am.config.name,
      namespace: am.config.namespace,
      labels: { alertmanager: am.config.name } + am.config.commonLabels,
    },
    spec: {
      ports: [
        { name: 'web', targetPort: 'web', port: 9093 },
      ],
      selector: {
        app: 'alertmanager',
        alertmanager: am.config.name,
      } + am.config.selectorLabels,
      sessionAffinity: 'ClientIP',
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'alertmanager',
      namespace: am.config.namespace,
      labels: am.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: {
          alertmanager: am.config.name,
        } + am.config.selectorLabels,
      },
      endpoints: [
        { port: 'web', interval: '30s' },
      ],
    },
  },

  alertmanager: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'Alertmanager',
    metadata: {
      name: am.config.name,
      namespace: am.config.namespace,
      labels: {
        alertmanager: am.config.name,
      } + am.config.commonLabels,
    },
    spec: {
      replicas: am.config.replicas,
      version: am.config.version,
      image: am.config.image,
      podMetadata: {
        labels: am.config.commonLabels,
      },
      resources: am.config.resources,
      nodeSelector: { 'kubernetes.io/os': 'linux' },
      serviceAccountName: 'alertmanager-' + am.config.name,
      securityContext: {
        runAsUser: 1000,
        runAsNonRoot: true,
        fsGroup: 2000,
      },
    },
  },
}
