local alertmanager = import './alertmanager/alertmanager.libsonnet';
local blackboxExporter = import './blackbox-exporter/blackbox-exporter.libsonnet';
local customMixin = import './mixin/custom.libsonnet';
local grafana = import './grafana/grafana.libsonnet';
local kubeStateMetrics = import './kube-state-metrics/kube-state-metrics.libsonnet';
local kubernetesMixin = import './mixin/kubernetes.libsonnet';
local nodeExporter = import './node-exporter/node-exporter.libsonnet';
local prometheusAdapter = import './prometheus-adapter/prometheus-adapter.libsonnet';
local prometheusOperator = import './prometheus-operator/prometheus-operator.libsonnet';
local prometheus = import './prometheus/prometheus.libsonnet';
local prometheusOperator = import './prometheus-operator/prometheus-operator.libsonnet';

{
  alertmanager: alertmanager({
    name: $._config.alertmanagerName,
    namespace: $._config.namespace,
    version: '0.21.0',
    image: 'quay.io/prometheus/alertmanager:v0.21.0',
    mixin+: {
      ruleLabels: $._config.ruleLabels,
    },
  }),
  blackboxExporter: blackboxExporter({
    namespace: $._config.namespace,
    version: '0.18.0',
    image: 'quay.io/prometheus/blackbox-exporter:v0.18.0',
  }),
  grafana: grafana({
    namespace: $._config.namespace,
    version: '7.3.5',
    image: 'grafana/grafana:v7.3.7',
    dashboards: {},
    prometheusName: $._config.prometheusName,
  }),
  kubeStateMetrics: kubeStateMetrics({
    namespace: $._config.namespace,
    version: '1.9.7',
    image: 'quay.io/coreos/kube-state-metrics:v1.9.7',
    mixin+: {
      ruleLabels: $._config.ruleLabels,
    },
  }),
  nodeExporter: nodeExporter({
    namespace: $._config.namespace,
    version: '1.0.1',
    image: 'quay.io/prometheus/node-exporter:v1.0.1',
    mixin+: {
      ruleLabels: $._config.ruleLabels,
    },
  }),
  prometheus: prometheus({
    namespace: $._config.namespace,
    version: '2.24.0',
    image: 'quay.io/prometheus/prometheus:v2.24.0',
    name: $._config.prometheusName,
    alertmanagerName: $._config.alertmanagerName,
    mixin+: {
      ruleLabels: $._config.ruleLabels,
    },
  }),
  prometheusAdapter: prometheusAdapter({
    namespace: $._config.namespace,
    version: '0.8.2',
    image: 'directxman12/k8s-prometheus-adapter:v0.8.2',
    prometheusURL: 'http://prometheus-' + $._config.prometheusName + '.' + $._config.namespace + '.svc.cluster.local:9090/',
  }),
  prometheusOperator: prometheusOperator({
    namespace: $._config.namespace,
    version: '0.45.0',
    image: 'quay.io/prometheus-operator/prometheus-operator:v0.45.0',
    configReloaderImage: 'quay.io/prometheus-operator/prometheus-config-reloader:v0.45.0',
    commonLabels+: {
      'app.kubernetes.io/part-of': 'kube-prometheus',
    },
    mixin+: {
      ruleLabels: $._config.ruleLabels,
    },
  }),
  kubernetesMixin: kubernetesMixin({
    namespace: $._config.namespace,
    mixin+: {
      ruleLabels: $._config.ruleLabels,
    },
  }),
  kubePrometheus: customMixin({
    namespace: $._config.namespace,
    mixin+: {
      ruleLabels: $._config.ruleLabels,
    },
  }) + {
    namespace: {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: $._config.namespace,
      },
    },
  },
} + {
  _config+:: {
    namespace: 'default',
    prometheusName: 'k8s',
    alertmanagerName: 'main',
    ruleLabels: {
      role: 'alert-rules',
      prometheus: $._config.prometheusName,
    },
  },
}
