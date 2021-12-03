// Disables creation of NetworkPolicies

{
  blackboxExporter+: {
    networkPolicies:: {},
  },

  kubeStateMetrics+: {
    networkPolicies:: {},
  },

  nodeExporter+: {
    networkPolicies:: {},
  },

  prometheusAdapter+: {
    networkPolicies:: {},
  },

  alertmanager+: {
    networkPolicies:: {},
  },

  grafana+: {
    networkPolicies:: {},
  },

  prometheus+: {
    networkPolicies:: {},
  },

  prometheusOperator+: {
    networkPolicies:: {},
  },
}
