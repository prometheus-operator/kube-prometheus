# Adding Prometheus Pushgateway
This guide will help you add on prometheus push gateway along side all oher kube-prometheus components

# Setup

```bash
jb install github.com/latchmihay/kube-prometheus-pushgateway/prometheus-pushgateway
cat > withPromGateway.jsonnet <<EOF
local kp =
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
  (import "prometheus-pushgateway/pushgateway.libsonnet") +
  {
    _config+:: {
      namespace: 'monitoring',
    },
  };

{ ['prometheus-pushgateway-' + name]: kp.pushgateway[name], for name in std.objectFields(kp.pushgateway) } +
{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
EOF
./build.sh withPromGateway.jsonnet

# everything is at manifests folder
```

# Note
Prometheus Push Gateway is managed outside of the kube-prometheus project.

For more information please go to https://github.com/latchmihay/kube-prometheus-pushgateway