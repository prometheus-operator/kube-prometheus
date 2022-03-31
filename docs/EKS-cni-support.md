# CNI monitoring special configuration updates for EKS

AWS EKS uses [CNI](https://github.com/aws/amazon-vpc-cni-k8s) networking plugin for pod networking in Kubernetes using Elastic Network Interfaces on AWS

One fatal issue that can occur is that you run out of IP addresses in your eks cluster. (Generally happens due to error configs where pods keep scheduling).

You can monitor the `awscni` using kube-promethus with :

```jsonnet mdox-exec="cat examples/eks-cni-example.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
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

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
```

After you have the required yaml file please run

```
kubectl apply -f manifests/prometheus-serviceMonitorAwsEksCNI.yaml
```
