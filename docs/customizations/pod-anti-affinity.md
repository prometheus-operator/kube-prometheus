### Pod Anti-Affinity

To prevent `Prometheus` and `Alertmanager` instances from being deployed onto the same node when
possible, one can include the [kube-prometheus-anti-affinity.libsonnet](https://github.com/prometheus-operator/kube-prometheus/tree/main/jsonnet/kube-prometheus/addons/anti-affinity.libsonnet) mixin:

```jsonnet mdox-exec="cat examples/anti-affinity.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/addons/anti-affinity.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```
