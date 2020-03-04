# Setup WeaveNet CNI monitoring using kube-prometheus
[WeaveNet](https://kubernetes.io/docs/concepts/cluster-administration/networking/#weave-net-from-weaveworks) is a resilient and simple to use CNI for Kubernetes. A well monitored and observed CNI helps in troubleshooting Kubernetes networking problems. [WeaveNet](https://www.weave.works/docs/net/latest/concepts/how-it-works/) emits [prometheus metrics](https://www.weave.works/docs/net/latest/tasks/manage/metrics/) for monitoring WeaveNet. There are many ways to install WeaveNet in your cluster. One of them is using [kops](https://github.com/kubernetes/kops/blob/master/docs/networking.md).

Following this document, you can setup weave net CNI monitoring for your cluster using kube-prometheus.

## Contents
Using kube-prometheus and kubectl you will be able install the following for monitoring weave-net in your cluster:

1. [Service for WeaveNet](https://gist.github.com/alok87/379c6234b582f555c141f6fddea9fbce) The service which the [service monitor](https://coreos.com/operators/prometheus/docs/latest/user-guides/cluster-monitoring.html) scraps.
2. [ServiceMonitor for WeaveNet](https://gist.github.com/alok87/e46a7f9a79ef6d1da6964a035be2cfb9) Service monitor to scraps the weavenet metrics and bring it to Prometheus.
3. [Prometheus Alerts for WeaveNet](https://stackoverflow.com/a/60447864) This will setup all the important weave net metrics you should be alerted on.
4. [Grafana Dashboard for WeaveNet](https://grafana.com/grafana/dashboards/11789) This will setup the per CNI pod level monitoring for weave net.
5. [Grafana Dashboard for WeaveNet(Cluster)](https://grafana.com/grafana/dashboards/11789) This will setup the cluster level monitoring for weave net.

## Instructions
- You can monitor weave-net CNI using an example like below. **Please note that some alert configurations are environment specific and may require modifications of alert thresholds**. For example: The FastDP flows have never gone below 1500 for us. But if this value is say 2000 for you then you can use an example like below to update the alert. The alerts which may require threshold modifications are `WeaveNetFastDPFlowsLow` and `WeaveNetIPAMUnreachable`.

[embedmd]:# (../examples/weavenet-example.jsonnet)
```jsonnet
local kp =  (import 'kube-prometheus/kube-prometheus.libsonnet') +
            (import 'kube-prometheus/kube-prometheus-weavenet.libsonnet') + {
  _config+:: {
    namespace: 'monitoring',
  },
  prometheusAlerts+:: {
    groups: std.map(
      function(group)
        if group.name == 'weave-net' then
          group {
            rules: std.map(function(rule)
              if rule.alert == "WeaveNetFastDPFlowsLow" then
                rule {
                  expr: "sum(weave_flows) < 2000"
                }
              else if rule.alert == "WeaveNetIPAMUnreachable" then
                rule {
                  expr: "weave_ipam_unreachable_percentage > 25"
                }
              else
                rule
              ,
              group.rules
            )
          }
        else
          group,
        super.groups
      ),
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
```
