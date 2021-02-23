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
  },

  local antiaffinity(key, values, namespace, type, topologyKey) = {
    local podAffinityTerm = {
      namespaces: [namespace],
      topologyKey: topologyKey,
      labelSelector: {
        matchExpressions: [{
          key: key,
          operator: 'In',
          values: values,
        }],
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
        antiaffinity(
          'alertmanager',
          [$.values.alertmanager.name],
          $.values.common.namespace,
          $.values.alertmanager.podAntiAffinity,
          $.values.alertmanager.podAntiAffinityTopologyKey,
        ),
    },
  },

  prometheus+: {
    prometheus+: {
      spec+:
        antiaffinity(
          'prometheus',
          [$.values.prometheus.name],
          $.values.common.namespace,
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
            antiaffinity(
              'app.kubernetes.io/name',
              ['blackbox-exporter'],
              $.values.common.namespace,
              $.values.blackboxExporter.podAntiAffinity,
              $.values.blackboxExporter.podAntiAffinityTopologyKey,
            ),
        },
      },
    },
  },

}
