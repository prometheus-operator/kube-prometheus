{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'node-network',
        rules: [
          {
            alert: 'NodeNetworkInterfaceFlapping',
            annotations: {
              summary: "Network interface is often changin it's status",
              description: 'Network interface "{{ $labels.device }}" changing it\'s up status often on node-exporter {{ $labels.namespace }}/{{ $labels.pod }}',
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
