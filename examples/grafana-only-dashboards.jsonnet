local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },

    // Disable all grafana-related objects apart from dashboards and datasource
    grafana: {
      dashboardSources:: {},
      deployment:: {},
      serviceAccount:: {},
      serviceMonitor:: {},
      service:: {},
    },
  };

// Manifestation
{
  [component + '-' + resource + '.json']: kp[component][resource]
  for component in std.objectFields(kp)
  for resource in std.objectFields(kp[component])
}
