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

}
