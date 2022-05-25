local defaults = {
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  namespace:: error 'must provide namespace',
  commonLabels:: {
    'app.kubernetes.io/name': 'kube-prometheus',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  mixin:: {
    ruleLabels: {},
    _config: {},
  },
};

function(params) {
  local etcd = self,
  _config:: defaults + params,
  _metadata:: {
    labels: etcd._config.commonLabels,
    namespace: etcd._config.namespace,
  },

  mixin:: (import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet') {
    _config+:: etcd._config.mixin._config,
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: etcd._metadata {
      name: 'etcd-monitoring-rules',
      labels+: etcd._config.mixin.ruleLabels,
    },
    spec: {
      local r = if std.objectHasAll(etcd.mixin, 'prometheusRules') then etcd.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(etcd.mixin, 'prometheusAlerts') then etcd.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },
}
