local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  namespace:: error 'must provide namespace',
  image: error 'must provide image',
  version: error 'must provide version',
  resources: {
    limits: { cpu: '100m', memory: '100Mi' },
    requests: { cpu: '4m', memory: '100Mi' },
  },
  commonLabels:: {
    'app.kubernetes.io/name': 'alertmanager',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'alert-router',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  name:: error 'must provide name',
  reloaderPort:: 8080,
  config:: {
    global: {
      resolve_timeout: '5m',
    },
    inhibit_rules: [{
      source_matchers: ['severity = critical'],
      target_matchers: ['severity =~ warning|info'],
      equal: ['namespace', 'alertname'],
    }, {
      source_matchers: ['severity = warning'],
      target_matchers: ['severity = info'],
      equal: ['namespace', 'alertname'],
    }, {
      source_matchers: ['alertname = InfoInhibitor'],
      target_matchers: ['severity = info'],
      equal: ['namespace'],
    }],
    route: {
      group_by: ['namespace'],
      group_wait: '30s',
      group_interval: '5m',
      repeat_interval: '12h',
      receiver: 'Default',
      routes: [
        { receiver: 'Watchdog', matchers: ['alertname = Watchdog'] },
        { receiver: 'null', matchers: ['alertname = InfoInhibitor'] },
        { receiver: 'Critical', matchers: ['severity = critical'] },
      ],
    },
    receivers: [
      { name: 'Default' },
      { name: 'Watchdog' },
      { name: 'Critical' },
      { name: 'null' },
    ],
  },
  replicas: 3,
  secrets: [],
  mixin:: {
    ruleLabels: {},
    _config: {
      alertmanagerName: '{{ $labels.namespace }}/{{ $labels.pod}}',
      alertmanagerClusterLabels: 'namespace,service',
      alertmanagerSelector: 'job="alertmanager-' + defaults.name + '",namespace="' + defaults.namespace + '"',
      runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/alertmanager/%s',
    },
  },
};


function(params) {
  local am = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(am._config.resources),
  assert std.isObject(am._config.mixin._config),
  _metadata:: {
    name: 'alertmanager-' + am._config.name,
    namespace: am._config.namespace,
    labels: am._config.commonLabels,
  },

  mixin:: (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/mixin.libsonnet') +
          (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') {
            _config+:: am._config.mixin._config,
          },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: am._metadata {
      labels+: am._config.mixin.ruleLabels,
      name: am._metadata.name + '-rules',
    },
    spec: {
      local r = if std.objectHasAll(am.mixin, 'prometheusRules') then am.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(am.mixin, 'prometheusAlerts') then am.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  networkPolicy: {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'NetworkPolicy',
    metadata: am.service.metadata,
    spec: {
      podSelector: {
        matchLabels: am._config.selectorLabels,
      },
      policyTypes: ['Egress', 'Ingress'],
      egress: [{}],
      ingress: [
        {
          from: [{
            podSelector: {
              matchLabels: {
                'app.kubernetes.io/name': 'prometheus',
              },
            },
          }],
          ports: std.map(function(o) {
            port: o.port,
            protocol: 'TCP',
          }, am.service.spec.ports),
        },
        // Alertmanager cluster peer-to-peer communication
        {
          from: [{
            podSelector: {
              matchLabels: {
                'app.kubernetes.io/name': 'alertmanager',
              },
            },
          }],
          ports: [{
            port: 9094,
            protocol: 'TCP',
          }, {
            port: 9094,
            protocol: 'UDP',
          }],
        },
      ],
    },
  },

  secret: {
    apiVersion: 'v1',
    kind: 'Secret',
    type: 'Opaque',
    metadata: am._metadata,
    stringData: {
      'alertmanager.yaml': if std.type(am._config.config) == 'object'
      then
        std.manifestYamlDoc(am._config.config)
      else
        am._config.config,
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: am._metadata,
    automountServiceAccountToken: false,
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: am._metadata,
    spec: {
      ports: [
        { name: 'web', targetPort: 'web', port: 9093 },
        { name: 'reloader-web', port: am._config.reloaderPort, targetPort: 'reloader-web' },
      ],
      selector: am._config.selectorLabels,
      sessionAffinity: 'ClientIP',
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: am._metadata,
    spec: {
      selector: {
        matchLabels: am._config.selectorLabels,
      },
      endpoints: [
        { port: 'web', interval: '30s' },
        { port: 'reloader-web', interval: '30s' },
      ],
    },
  },

  [if (defaults + params).replicas > 1 then 'podDisruptionBudget']: {
    apiVersion: 'policy/v1',
    kind: 'PodDisruptionBudget',
    metadata: am._metadata,
    spec: {
      maxUnavailable: 1,
      selector: {
        matchLabels: am._config.selectorLabels,
      },
    },
  },

  alertmanager: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'Alertmanager',
    metadata: am._metadata {
      name: am._config.name,
    },
    spec: {
      replicas: am._config.replicas,
      version: am._config.version,
      image: am._config.image,
      podMetadata: {
        labels: am.alertmanager.metadata.labels,
      },
      resources: am._config.resources,
      nodeSelector: { 'kubernetes.io/os': 'linux' },
      secrets: am._config.secrets,
      serviceAccountName: am.serviceAccount.metadata.name,
      securityContext: {
        runAsUser: 1000,
        runAsNonRoot: true,
        fsGroup: 2000,
      },
    },
  },
}
