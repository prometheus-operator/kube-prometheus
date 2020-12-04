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
        antiaffinity('alertmanager', [$._config.alertmanager.name], $._config.namespace),
    },
  },

  prometheus+:: {
    local p = self,

    prometheus+: {
      spec+:
        antiaffinity('prometheus', [$._config.prometheus.name], $._config.namespace),
    },
  },
}
