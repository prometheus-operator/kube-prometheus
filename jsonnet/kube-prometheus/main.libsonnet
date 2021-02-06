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
      versions: {
        alertmanager: '0.21.0',
        blackboxExporter: '0.18.0',
        grafana: '7.3.7',
        kubeStateMetrics: '1.9.7',
        nodeExporter: '1.1.0',
        prometheus: '2.24.0',
        prometheusAdapter: '0.8.3',
        prometheusOperator: '0.45.0',
      },
      images: {
        alertmanager: 'quay.io/prometheus/alertmanager:v' + $.values.common.versions.alertmanager,
        blackboxExporter: 'quay.io/prometheus/blackbox-exporter:v' + $.values.common.versions.blackboxExporter,
        grafana: 'grafana/grafana:v' + $.values.common.versions.grafana,
        kubeStateMetrics: 'quay.io/coreos/kube-state-metrics:v' + $.values.common.versions.kubeStateMetrics,
        nodeExporter: 'quay.io/prometheus/node-exporter:v' + $.values.common.versions.nodeExporter,
        prometheus: 'quay.io/prometheus/prometheus:v' + $.values.common.versions.prometheus,
        prometheusAdapter: 'directxman12/k8s-prometheus-adapter:v' + $.values.common.versions.prometheusAdapter,
        prometheusOperator: 'quay.io/prometheus-operator/prometheus-operator:v' + $.values.common.versions.prometheusOperator,
        prometheusOperatorReloader: 'quay.io/prometheus-operator/prometheus-config-reloader:v' + $.values.common.versions.prometheusOperator,
      },
    },
    alertmanager: {
      name: 'main',
      namespace: $.values.common.namespace,
      version: $.values.common.versions.alertmanager,
      image: $.values.common.images.alertmanager,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    blackboxExporter: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.blackboxExporter,
      image: $.values.common.images.blackboxExporter,
    },
    grafana: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.grafana,
      image: $.values.common.images.grafana,
      prometheusName: $.values.prometheus.name,
      // TODO(paulfantom) This should be done by iterating over all objects and looking for object.mixin.grafanaDashboards
      dashboards: $.nodeExporter.mixin.grafanaDashboards + $.prometheus.mixin.grafanaDashboards + $.kubernetesMixin.mixin.grafanaDashboards,
    },
    kubeStateMetrics: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.kubeStateMetrics,
      image: $.values.common.images.kubeStateMetrics,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    nodeExporter: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.nodeExporter,
      image: $.values.common.images.nodeExporter,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    prometheus: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.prometheus,
      image: $.values.common.images.prometheus,
      name: 'k8s',
      alertmanagerName: $.values.alertmanager.name,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
    prometheusAdapter: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.prometheusAdapter,
      image: $.values.common.images.prometheusAdapter,
      prometheusURL: 'http://prometheus-' + $.values.prometheus.name + '.' + $.values.common.namespace + '.svc.cluster.local:9090/',
    },
    prometheusOperator: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.prometheusOperator,
      image: $.values.common.images.prometheusOperator,
      configReloaderImage: $.values.common.images.prometheusOperatorReloader,
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
