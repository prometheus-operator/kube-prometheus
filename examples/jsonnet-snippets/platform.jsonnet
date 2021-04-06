(import 'kube-prometheus/main.libsonnet') +
{
  values+:: {
    kubePrometheus+: {
      platform: 'example-platform',
    },
  },
}
