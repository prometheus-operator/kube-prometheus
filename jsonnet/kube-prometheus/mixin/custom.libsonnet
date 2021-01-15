local defaults = {
  name: 'kube-prometheus',
  namespace: error 'must provide namespace',
  commonLabels:: {
    'app.kubernetes.io/name': 'kube-prometheus',
    'app.kubernetes.io/component': 'exporter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  mixin: {
    ruleLabels: {},
    _config: {
      nodeExporterSelector: 'job="node-exporter"',
      hostNetworkInterfaceSelector: 'device!~"veth.+"',
    },
  },
};

function(params) {
  local m = self,
  config:: defaults + params,

  local alertsandrules = (import './alerts/alerts.libsonnet') + (import './rules/rules.libsonnet'),

  mixin:: alertsandrules {
    _config+:: m.config.mixin._config,
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: m.config.commonLabels + m.config.mixin.ruleLabels,
      name: m.config.name + '-rules',
      namespace: m.config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(m.mixin, 'prometheusRules') then m.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(m.mixin, 'prometheusAlerts') then m.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },
}
