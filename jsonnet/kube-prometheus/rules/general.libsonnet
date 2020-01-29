{
  prometheusRules+:: {
    groups+: [
      {
        name: 'kube-prometheus-general.rules',
        rules: [
          {
            expr: 'count without(instance, pod, node) (up == 1)',
            record: 'count:up1',
          },
          {
            expr: 'count without(instance, pod, node) (up == 0)',
            record: 'count:up0',
          },
        ],
      },
    ],
  },
}
