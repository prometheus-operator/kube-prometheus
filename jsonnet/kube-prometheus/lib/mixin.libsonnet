local defaults = {
  name: error 'provide name',
  namespace: 'monitoring',
  labels: {
    prometheus: 'k8s',
  },
  mixin: error 'provide a mixin',
};

function(params) {
  config:: defaults + params,

  local m = self,

  local prometheusRules = if std.objectHasAll(m.config.mixin, 'prometheusRules') || std.objectHasAll(m.config.mixin, 'prometheusAlerts') then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: m.config.labels,
      name: m.config.name,
      namespace: m.config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(m.config.mixin, 'prometheusRules') then m.config.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(m.config.mixin, 'prometheusAlerts') then m.config.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  local grafanaDashboards = if std.objectHasAll(m.config.mixin, 'grafanaDashboards') then (
    if std.objectHas(m.config, 'dashboardFolder') then {
      [m.config.dashboardFolder]+: m.config.mixin.grafanaDashboards,
    } else (m.config.mixin.grafanaDashboards)
  ),

  prometheusRules: prometheusRules,
  grafanaDashboards: grafanaDashboards,
}
