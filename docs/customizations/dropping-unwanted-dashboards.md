### Dropping unwanted dashboards

When deploying kube-prometheus, your Grafana instance is deployed with a lot of dashboards by default. All those dashboards are comming from upstream projects like [kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin), [prometheus-mixin](https://github.com/prometheus/prometheus/tree/main/documentation/prometheus-mixin) and [node-exporter-mixin](https://github.com/prometheus/node_exporter/tree/master/docs/node-mixin), among others.

In case you find out that you don't need some of them, you can choose to remove those dashboards like in the example below, which removes the [`alertmanager-overview.json`](https://github.com/prometheus/alertmanager/blob/main/doc/alertmanager-mixin/dashboards/overview.libsonnet) dashboard.

```jsonnet mdox-exec="cat examples/drop-dashboards.jsonnet"
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
      grafana+: {
        dashboards: std.mergePatch(super.dashboards, {
          // Add more unwanted dashboards here
          'alertmanager-overview.json': null,
        }),
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
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
```
