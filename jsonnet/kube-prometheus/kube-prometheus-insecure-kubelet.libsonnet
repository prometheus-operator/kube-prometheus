{
  prometheus+:: {
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
                // Drop cAdvisor metrics with no (pod, namespace) labels while preserving ability to monitor system services resource usage (cardinality estimation)
                {
                  sourceLabels: ['__name__', 'pod', 'namespace'],
                  action: 'drop',
                  regex: '(' + std.join('|',
                                        [
                                          'container_fs_.*',  // add filesystem read/write data (nodes*disks*services*4)
                                          'container_spec_.*',  // everything related to cgroup specification and thus static data (nodes*services*5)
                                          'container_blkio_device_usage_total',  // useful for containers, but not for system services (nodes*disks*services*operations*2)
                                          'container_file_descriptors',  // file descriptors limits and global numbers are exposed via (nodes*services)
                                          'container_sockets',  // used sockets in cgroup. Usually not important for system services (nodes*services)
                                          'container_threads_max',  // max number of threads in cgroup. Usually for system services it is not limited (nodes*services)
                                          'container_threads',  // used threads in cgroup. Usually not important for system services (nodes*services)
                                          'container_start_time_seconds',  // container start. Possibly not needed for system services (nodes*services)
                                          'container_last_seen',  // not needed as system services are always running (nodes*services)
                                        ]) + ');;',
                },
              ],
            },
          ],
        },
      },
  },
}
