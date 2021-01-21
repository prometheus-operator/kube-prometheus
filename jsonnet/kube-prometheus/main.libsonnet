local alertmanager = import './components/alertmanager.libsonnet';
local blackboxExporter = import './components/blackbox-exporter.libsonnet';
local grafana = import './components/grafana.libsonnet';
local kubeStateMetrics = import './components/kube-state-metrics.libsonnet';
local customMixin = import './components/mixin/custom.libsonnet';
local kubernetesMixin = import './components/mixin/kubernetes.libsonnet';
local nodeExporter = import './components/node-exporter.libsonnet';
local prometheusAdapter = import './components/prometheus-adapter.libsonnet';
local prometheusOperator = import './components/prometheus-operator.libsonnet';
local prometheus = import './components/prometheus.libsonnet';

{
  // using `values` as this is similar to helm
  values:: {
    common: {
      namespace: 'default',
      ruleLabels: {
        role: 'alert-rules',
        prometheus: $.values.prometheus.name,
      },
    },
    alertmanager: {
      name: 'main',
      namespace: $.values.common.namespace,
      version: '0.21.0',
      image: 'quay.io/prometheus/alertmanager:v0.21.0',
      mixin+: {
        ruleLabels: $.values.common.ruleLabels,
      },
    },
    blackboxExporter: {
      namespace: $.values.common.namespace,
      version: '0.18.0',
      image: 'quay.io/prometheus/blackbox-exporter:v0.18.0',
    },
    grafana: {
      namespace: $.values.common.namespace,
      version: '7.3.5',
      image: 'grafana/grafana:v7.3.7',
      prometheusName: $.values.prometheus.name,
      // TODO(paulfantom) This should be done by iterating over all objects and looking for object.mixin.grafanaDashboards
      dashboards: $.nodeExporter.mixin.grafanaDashboards + $.prometheus.mixin.grafanaDashboards + $.kubernetesMixin.mixin.grafanaDashboards,
    },
    kubeStateMetrics: {
      namespace: $.values.common.namespace,
      version: '1.9.7',
      image: 'quay.io/coreos/kube-state-metrics:v1.9.7',
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    nodeExporter: {
      namespace: $.values.common.namespace,
      version: '1.0.1',
      image: 'quay.io/prometheus/node-exporter:v1.0.1',
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    prometheus: {
      namespace: $.values.common.namespace,
      version: '2.24.0',
      image: 'quay.io/prometheus/prometheus:v2.24.0',
      name: 'k8s',
      alertmanagerName: $.values.alertmanager.name,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    prometheusAdapter: {
      namespace: $.values.common.namespace,
      version: '0.8.2',
      image: 'directxman12/k8s-prometheus-adapter:v0.8.2',
      prometheusURL: 'http://prometheus-' + $.values.prometheus.name + '.' + $.values.common.namespace + '.svc.cluster.local:9090/',
    },
    prometheusOperator: {
      namespace: $.values.common.namespace,
      version: '0.45.0',
      image: 'quay.io/prometheus-operator/prometheus-operator:v0.45.0',
      configReloaderImage: 'quay.io/prometheus-operator/prometheus-config-reloader:v0.45.0',
      commonLabels+: {
        'app.kubernetes.io/part-of': 'kube-prometheus',
      },
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    kubernetesMixin: {
      namespace: $.values.common.namespace,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    kubePrometheus: {
      namespace: $.values.common.namespace,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
  },

  alertmanager: alertmanager($.values.alertmanager),
  blackboxExporter: blackboxExporter($.values.blackboxExporter),
  grafana: grafana($.values.grafana),
  kubeStateMetrics: kubeStateMetrics($.values.kubeStateMetrics),
  nodeExporter: nodeExporter($.values.nodeExporter),
  prometheus: prometheus($.values.prometheus),
  prometheusAdapter: prometheusAdapter($.values.prometheusAdapter),
  prometheusOperator: prometheusOperator($.values.prometheusOperator),
  kubernetesMixin: kubernetesMixin($.values.kubernetesMixin),
  kubePrometheus: customMixin($.values.kubePrometheus) + {
    namespace: {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: $.values.kubePrometheus.namespace,
      },
    },
  },
}
