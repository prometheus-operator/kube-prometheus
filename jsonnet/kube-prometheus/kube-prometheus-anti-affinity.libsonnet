{
  local antiaffinity(key, values, namespace) = {
    affinity: {
      podAntiAffinity: {
        preferredDuringSchedulingIgnoredDuringExecution: [
          {
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
              weight: 100,
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

  prometheus+: {
    local p = self,

    prometheus+: {
      spec+:
        antiaffinity('prometheus', [p.name], p.namespace),
    },
  },
}
