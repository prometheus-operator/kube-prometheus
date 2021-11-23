{
  values+:: {
    alertmanager+: {
      podAntiAffinity: 'soft',
      podAntiAffinityTopologyKey: 'kubernetes.io/hostname',
    },
    prometheus+: {
      podAntiAffinity: 'soft',
      podAntiAffinityTopologyKey: 'kubernetes.io/hostname',
    },
    blackboxExporter+: {
      podAntiAffinity: 'soft',
      podAntiAffinityTopologyKey: 'kubernetes.io/hostname',
    },
    prometheusAdapter+: {
      podAntiAffinity: 'soft',
      podAntiAffinityTopologyKey: 'kubernetes.io/hostname',
    },
  },

  antiaffinity(labelSelector, namespace, type, topologyKey):: {
    local podAffinityTerm = {
      namespaces: [namespace],
      topologyKey: topologyKey,
      labelSelector: {
        matchLabels: labelSelector,
      },
    },

    affinity: {
      podAntiAffinity: if type == 'soft' then {
        preferredDuringSchedulingIgnoredDuringExecution: [{
          weight: 100,
          podAffinityTerm: podAffinityTerm,
        }],
      } else if type == 'hard' then {
        requiredDuringSchedulingIgnoredDuringExecution: [
          podAffinityTerm,
        ],
      } else error 'podAntiAffinity must be either "soft" or "hard"',
    },
  },

  alertmanager+: {
    alertmanager+: {
      spec+:
        $.antiaffinity(
          $.alertmanager._config.selectorLabels,
          $.values.alertmanager.namespace,
          $.values.alertmanager.podAntiAffinity,
          $.values.alertmanager.podAntiAffinityTopologyKey,
        ),
    },
  },

  prometheus+: {
    prometheus+: {
      spec+:
        $.antiaffinity(
          $.prometheus._config.selectorLabels,
          $.values.prometheus.namespace,
          $.values.prometheus.podAntiAffinity,
          $.values.prometheus.podAntiAffinityTopologyKey,
        ),
    },
  },

  blackboxExporter+: {
    deployment+: {
      spec+: {
        template+: {
          spec+:
            $.antiaffinity(
              $.blackboxExporter._config.selectorLabels,
              $.values.blackboxExporter.namespace,
              $.values.blackboxExporter.podAntiAffinity,
              $.values.blackboxExporter.podAntiAffinityTopologyKey,
            ),
        },
      },
    },
  },

  prometheusAdapter+: {
    deployment+: {
      spec+: {
        template+: {
          spec+:
            $.antiaffinity(
              $.prometheusAdapter._config.selectorLabels,
              $.values.prometheusAdapter.namespace,
              $.values.prometheusAdapter.podAntiAffinity,
              $.values.prometheusAdapter.podAntiAffinityTopologyKey,
            ),
        },
      },
    },
  },
}
