local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/platforms/eks.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
  prometheus+: {
    prometheusRuleEksCNI+: {
      spec+: {
        groups+: [
          {
            name: 'example-group',
            rules: [
              {
                record: 'aws_eks_available_ip',
                expr: 'sum by(instance) (awscni_total_ip_addresses) - sum by(instance) (awscni_assigned_ip_addresses) < 10',
              },
            ],
          },
        ],
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
