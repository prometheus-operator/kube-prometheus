### Monitoring all namespaces

In case you want to monitor all namespaces in a cluster, you can add the following mixin. Also, make sure to empty the namespaces defined in prometheus so that roleBindings are not created against them.

```jsonnet mdox-exec="cat examples/all-namespaces.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/addons/all-namespaces.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
    prometheus+: {
      namespaces: [],
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

> NOTE: This configuration can potentially make your cluster insecure especially in a multi-tenant cluster. This is because this gives Prometheus visibility over the whole cluster which might not be expected in a scenario when certain namespaces are locked down for security reasons.

Proceed with [creating ServiceMonitors for the services in the namespaces](monitoring-additional-namespaces.md#defining-the-servicemonitor-for-each-additional-namespace) you actually want to monitor
