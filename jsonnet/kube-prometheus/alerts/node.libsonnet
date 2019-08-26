{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'node-time',
        rules: [
          {
            alert: 'ClockSkewDetected',
            annotations: {
              message: 'Clock skew detected on node-exporter {{ $labels.namespace }}/{{ $labels.pod }}. Ensure NTP is configured correctly on this host.',
            },
            expr: |||
              abs(node_timex_offset_seconds{%(nodeExporterSelector)s}) > 0.05
            ||| % $._config,
            'for': '2m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
      {
        name: 'node-network',
        rules: [
          {
            alert: 'NodeNetworkInterfaceFlapping',
            annotations: {
              message: 'Network interface "{{ $labels.device }}" changing it\'s up status often on node-exporter {{ $labels.namespace }}/{{ $labels.pod }}"',
            },
            expr: |||
              changes(node_network_up{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[2m]) > 2
            ||| % $._config,
            'for': '2m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}
