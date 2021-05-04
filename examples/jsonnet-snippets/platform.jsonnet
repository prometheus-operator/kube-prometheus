(import 'kube-prometheus/main.libsonnet') +
{
  values+:: {
    common+: {
      platform: 'example-platform',
    },
  },
}
