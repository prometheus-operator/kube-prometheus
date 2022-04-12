// Disables creation of NetworkPolicies

{
  blackboxExporter+: {
    networkPolicy:: {},
  },

  kubeStateMetrics+: {
    networkPolicy:: {},
  },

  nodeExporter+: {
    networkPolicy:: {},
  },

  prometheusAdapter+: {
    networkPolicy:: {},
  },

  alertmanager+: {
    networkPolicy:: {},
  },

  grafana+: {
    networkPolicy:: {},
  },

  prometheus+: {
    networkPolicy:: {},
  },

  prometheusOperator+: {
    networkPolicy:: {},
  },
}
