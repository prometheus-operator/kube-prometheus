{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'general.rules',
        rules: [
          {
            alert: 'TargetDown',
            annotations: {
              message: '{{ printf "%.4g" $value }}% of the {{ $labels.job }} targets in {{ $labels.namespace }} namespace are down.',
            },
            expr: '100 * (count(up == 0) BY (job, namespace, service) / count(up) BY (job, namespace, service)) > 10',
            'for': '10m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}
