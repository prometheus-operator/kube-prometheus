local defaults = {
  name: error 'provide name',
  namespace: 'monitoring',
  labels: {
    prometheus: 'k8s',
  },
  mixin: error 'provide a mixin',
};

function(params) {
  _config:: defaults + params,

  local m = self,

  local prometheusRules = if std.objectHasAll(m._config.mixin, 'prometheusRules') || std.objectHasAll(m._config.mixin, 'prometheusAlerts') then {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: m._config.labels,
      name: m._config.name,
      namespace: m._config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(m._config.mixin, 'prometheusRules') then m._config.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(m._config.mixin, 'prometheusAlerts') then m._config.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  local grafanaDashboards = if std.objectHasAll(m._config.mixin, 'grafanaDashboards') then (
    if std.objectHas(m._config, 'dashboardFolder') then {
      [m._config.dashboardFolder]+: m._config.mixin.grafanaDashboards,
    } else (m._config.mixin.grafanaDashboards)
  ),

  prometheusRules: prometheusRules,
  grafanaDashboards: grafanaDashboards,
}
