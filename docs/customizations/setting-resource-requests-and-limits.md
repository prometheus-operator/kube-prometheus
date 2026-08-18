### Setting resource requests and limits

Resource requests and limits for kube-prometheus components are first-class
settings under `values`. Prefer configuring them directly instead of stripping
limits with an addon.

For example, to customize Prometheus resource requests and limits:

```jsonnet mdox-exec="cat examples/setting-resource-requests-and-limits.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
    prometheus+: {
      resources: {
        requests: { cpu: '200m', memory: '800Mi' },
        limits: { cpu: '1', memory: '2Gi' },
      },
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

The same `resources` shape applies to other components that expose it under
`values` (for example `alertmanager`, `grafana`, `nodeExporter`,
`kubeStateMetrics`, `prometheusOperator`).

If CPU throttling alerts fire on small clusters, tune or silence
`CPUThrottlingHigh` rather than clearing all container limits globally.
