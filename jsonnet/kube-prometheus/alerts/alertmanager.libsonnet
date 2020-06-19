{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'alertmanager.rules',
        rules: [
          {
            alert: 'AlertmanagerConfigInconsistent',
            annotations: {
              message: |||
                The configuration of the instances of the Alertmanager cluster `{{ $labels.namespace }}/{{ $labels.service }}` are out of sync.
                {{ range printf "alertmanager_config_hash{namespace=\"%s\",service=\"%s\"}" $labels.namespace $labels.service | query }}
                Configuration hash for pod {{ .Labels.pod }} is "{{ printf "%.f" .Value }}"
                {{ end }}
              |||,
            },
            expr: |||
              count by(namespace,service) (count_values by(namespace,service) ("config_hash", alertmanager_config_hash{%(alertmanagerSelector)s})) != 1
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'AlertmanagerFailedReload',
            annotations: {
              message: "Reloading Alertmanager's configuration has failed for {{ $labels.namespace }}/{{ $labels.pod}}.",
            },
            expr: |||
              alertmanager_config_last_reload_successful{%(alertmanagerSelector)s} == 0
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'AlertmanagerMembersInconsistent',
            annotations: {
              message: 'Alertmanager has not found all other members of the cluster.',
            },
            expr: |||
              alertmanager_cluster_members{%(alertmanagerSelector)s}
                != on (service) GROUP_LEFT()
              count by (service) (alertmanager_cluster_members{%(alertmanagerSelector)s})
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
          },
        ],
      },
    ],
  },
}
