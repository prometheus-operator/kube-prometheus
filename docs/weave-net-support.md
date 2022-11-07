# Setup Weave Net monitoring using kube-prometheus

[Weave Net](https://kubernetes.io/docs/concepts/cluster-administration/networking/#weave-net-from-weaveworks) is a resilient and simple to use CNI provider for Kubernetes. A well monitored and observed CNI provider helps in troubleshooting Kubernetes networking problems. [Weave Net](https://www.weave.works/docs/net/latest/concepts/how-it-works/) emits [prometheus metrics](https://www.weave.works/docs/net/latest/tasks/manage/metrics/) for monitoring Weave Net. There are many ways to install Weave Net in your cluster. One of them is using [kops](https://github.com/kubernetes/kops/blob/master/docs/networking.md).

Following this document, you can setup Weave Net monitoring for your cluster using kube-prometheus.

## Contents

Using kube-prometheus and kubectl you will be able install the following for monitoring Weave Net in your cluster:

1. [Service for Weave Net](https://gist.github.com/alok87/379c6234b582f555c141f6fddea9fbce) The service which the ServiceMonitor scrapes.
2. [ServiceMonitor for Weave Net](https://gist.github.com/alok87/e46a7f9a79ef6d1da6964a035be2cfb9) Service monitor to scrape the Weave Net metrics and bring it to Prometheus.
3. [Prometheus Alerts for Weave Net](https://stackoverflow.com/a/60447864) This will setup all the important Weave Net metrics you should be alerted on.
4. [Grafana Dashboard for Weave Net](https://grafana.com/grafana/dashboards/11789) This will setup the per Weave Net pod level monitoring for Weave Net.
5. [Grafana Dashboard for Weave Net(Cluster)](https://grafana.com/grafana/dashboards/11804) This will setup the cluster level monitoring for Weave Net.

## Instructions
- You can monitor Weave Net using an example like below. **Please note that some alert configurations are environment specific and may require modifications of alert thresholds**. For example: The FastDP flows have never gone below 15000 for us. But if this value is say 20000 for you then you can use an example like below to update the alert. The alerts which may require threshold modifications are `WeaveNetFastDPFlowsLow` and `WeaveNetIPAMUnreachable`.

```jsonnet mdox-exec="cat examples/weave-net-example.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/addons/weave-net/weave-net.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
  kubernetesControlPlane+: {
    prometheusRuleWeaveNet+: {
      spec+: {
        groups: std.map(
          function(group)
            if group.name == 'weave-net' then
              group {
                rules: std.map(
                  function(rule)
                    if rule.alert == 'WeaveNetFastDPFlowsLow' then
                      rule {
                        expr: 'sum(weave_flows) < 20000',
                      }
                    else if rule.alert == 'WeaveNetIPAMUnreachable' then
                      rule {
                        expr: 'weave_ipam_unreachable_percentage > 25',
                      }
                    else
                      rule
                  ,
                  group.rules
                ),
              }
            else
              group,
          super.groups
        ),
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

- After you have the required yamls file please run

```
kubectl create -f prometheus-serviceWeaveNet.yaml
kubectl create -f prometheus-serviceMonitorWeaveNet.yaml
kubectl apply -f  prometheus-rules.yaml
kubectl apply -f grafana-dashboardDefinitions.yaml
kubectl apply -f grafana-deployment.yaml
```
