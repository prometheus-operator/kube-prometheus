(import 'kube-prometheus/main.libsonnet') +
{
  values+:: {
    common+: {
      resourceMetricsAPI:: 'metrics-server',
    },
    metricsServer+: {
      kubeletInsecureTLS:: true,
    },
  },
}
