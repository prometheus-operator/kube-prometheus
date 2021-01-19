{
  local antiaffinity(key, values, namespace) = {
    affinity: {
      podAntiAffinity: {
        preferredDuringSchedulingIgnoredDuringExecution: [
          {
            weight: 100,
            podAffinityTerm: {
              namespaces: [namespace],
              topologyKey: 'kubernetes.io/hostname',
              labelSelector: {
                matchExpressions: [{
                  key: key,
                  operator: 'In',
                  values: values,
                }],
              },
            },
          },
        ],
      },
    },
  },

  alertmanager+:: {
    alertmanager+: {
      spec+:
        antiaffinity('alertmanager', [$.values.alertmanager.name], $.values.common.namespace),
    },
  },

  prometheus+:: {
    prometheus+: {
      spec+:
        antiaffinity('prometheus', [$.values.prometheus.name], $.values.common.namespace),
    },
  },
}
