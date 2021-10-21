# CNI monitoring special configuration updates for EKS

AWS EKS uses [CNI](https://github.com/aws/amazon-vpc-cni-k8s) networking plugin for pod networking in Kubernetes using Elastic Network Interfaces on AWS

One fatal issue that can occur is that you run out of IP addresses in your eks cluster. (Generally happens due to error configs where pods keep scheduling).

You can monitor the `awscni` using kube-promethus with :

```jsonnet mdox-exec="cat examples/eks-cni-example.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
    kubePrometheus+: {
      platform: 'eks',
    },
  },
  kubernetesControlPlane+: {
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
```

After you have the required yaml file please run

```
kubectl apply -f manifests/prometheus-serviceMonitorAwsEksCNI.yaml
```
