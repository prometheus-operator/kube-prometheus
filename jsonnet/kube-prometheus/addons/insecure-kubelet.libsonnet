{
  prometheus+: {
    serviceMonitorKubelet+:
      {
        spec+: {
          endpoints: [
            {
              port: 'http-metrics',
              scheme: 'http',
              interval: '30s',
              bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
              relabelings: [
                { sourceLabels: ['__metrics_path__'], targetLabel: 'metrics_path' },
              ],
            },
            {
              port: 'http-metrics',
              scheme: 'http',
              path: '/metrics/cadvisor',
              interval: '30s',
              honorLabels: true,
              bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
              relabelings: [
                { sourceLabels: ['__metrics_path__'], targetLabel: 'metrics_path' },
              ],
              metricRelabelings: [
                // Drop a bunch of metrics which are disabled but still sent, see
                // https://github.com/google/cadvisor/issues/1925.
                {
                  sourceLabels: ['__name__'],
                  regex: 'container_(network_tcp_usage_total|network_udp_usage_total|tasks_state|cpu_load_average_10s)',
                  action: 'drop',
                },
              ],
            },
          ],
        },
      },
  },
}
