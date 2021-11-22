### Stripping container resource limits

Sometimes in small clusters, the CPU/memory limits can get high enough for alerts to be fired continuously. To prevent this, one can strip off the predefined limits.
To do that, one can import the following mixin

```jsonnet mdox-exec="cat examples/strip-limits.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/addons/strip-limits.libsonnet') + {
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
