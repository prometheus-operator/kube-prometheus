(import '../addons/managed-cluster.libsonnet') + {
  values+:: {
    prometheusAdapter+: {
      config+: {
        resourceRules:: null,
      },
    },
  },

  prometheusAdapter+:: {
    apiService:: null,
  },

  metricsServer+:: {
    apiService:: null,
  },
}
