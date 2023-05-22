{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'general.rules',
        rules: [
          {
            alert: 'TargetDown',
            annotations: {
              summary: 'One or more targets are unreachable.',
              description: '{{ printf "%.4g" $value }}% of the {{ $labels.job }}/{{ $labels.service }} targets in {{ $labels.namespace }} namespace are down.',
            },
            expr: '100 * (count(up == 0) BY (cluster, job, namespace, service) / count(up) BY (cluster, job, namespace, service)) > 10',
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'Watchdog',
            annotations: {
              summary: 'An alert that should always be firing to certify that Alertmanager is working properly.',
              description: |||
                This is an alert meant to ensure that the entire alerting pipeline is functional.
                This alert is always firing, therefore it should always be firing in Alertmanager
                and always fire against a receiver. There are integrations with various notification
                mechanisms that send a notification when this alert is not firing. For example the
                "DeadMansSnitch" integration in PagerDuty.
              |||,
            },
            expr: 'vector(1)',
            labels: {
              severity: 'none',
            },
          },
          {
            alert: 'InfoInhibitor',
            annotations: {
              summary: 'Info-level alert inhibition.',
              description: |||
                This is an alert that is used to inhibit info alerts.
                By themselves, the info-level alerts are sometimes very noisy, but they are relevant when combined with
                other alerts.
                This alert fires whenever there's a severity="info" alert, and stops firing when another alert with a
                severity of 'warning' or 'critical' starts firing on the same namespace.
                This alert should be routed to a null receiver and configured to inhibit alerts with severity="info".
              |||,
            },
            expr: 'ALERTS{severity = "info"} == 1 unless on(namespace) ALERTS{alertname != "InfoInhibitor", severity =~ "warning|critical", alertstate="firing"} == 1',
            labels: {
              severity: 'none',
            },
          },
        ],
      },
    ],
  },
}
