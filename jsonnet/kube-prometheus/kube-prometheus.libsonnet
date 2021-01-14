local alertmanager = import './alertmanager/alertmanager.libsonnet';
local blackboxExporter = import './blackbox-exporter/blackbox-exporter.libsonnet';
local kubeStateMetrics = import './kube-state-metrics/kube-state-metrics.libsonnet';
local nodeExporter = import './node-exporter/node-exporter.libsonnet';
local prometheusAdapter = import './prometheus-adapter/prometheus-adapter.libsonnet';
local prometheusOperator = import './prometheus-operator/prometheus-operator.libsonnet';
local prometheus = import './prometheus/prometheus.libsonnet';
local prometheusOperator = import './prometheus-operator/prometheus-operator.libsonnet';

local monitoringMixins = import './mixins/monitoring-mixins.libsonnet';

(import 'github.com/brancz/kubernetes-grafana/grafana/grafana.libsonnet') +
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
    prometheusURL: 'http://prometheus-' + $._config.prometheus.name + '.' + $._config.namespace + '.svc.cluster.local:9090/',
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
  mixins+:: monitoringMixins({
    namespace: $._config.namespace,
  }),

  // FIXME(paulfantom) Remove this variable by moving each mixin to its own component
  // Example: node_exporter mixin could be added in ./node-exporter/node-exporter.libsonnet
  allRules::
    //$.mixins.nodeExporter.prometheusRules +
    $.mixins.kubernetes.prometheusRules +
    $.mixins.base.prometheusRules +
    //$.mixins.kubeStateMetrics.prometheusAlerts +
    //$.mixins.nodeExporter.prometheusAlerts +
    //$.mixins.alertmanager.prometheusAlerts +
    //$.mixins.prometheusOperator.prometheusAlerts +
    $.mixins.kubernetes.prometheusAlerts +
    //$.mixins.prometheus.prometheusAlerts +
    $.mixins.base.prometheusAlerts,

  kubePrometheus+:: {
    namespace: {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: $._config.namespace,
      },
    },
  },

  grafana+:: {
    local dashboardDefinitions = super.dashboardDefinitions,

    dashboardDefinitions: {
      apiVersion: 'v1',
      kind: 'ConfigMapList',
      items: dashboardDefinitions,
    },
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'grafana',
        namespace: $._config.namespace,
        labels: $._config.grafana.labels,
      },
      spec: {
        selector: {
          matchLabels: {
            app: 'grafana',
          },
        },
        endpoints: [{
          port: 'http',
          interval: '15s',
        }],
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

    versions+:: { grafana: '7.3.5' },

    grafana+:: {
      labels: {
        'app.kubernetes.io/name': 'grafana',
        'app.kubernetes.io/version': $._config.versions.grafana,
        'app.kubernetes.io/component': 'grafana',
        'app.kubernetes.io/part-of': 'kube-prometheus',
      },
      // FIXME(paulfantom): Same as with rules and alerts.
      // This should be gathering all dashboards from components without having to enumerate all dashboards.
      dashboards:
        //$.mixins.nodeExporter.grafanaDashboards +
        $.mixins.kubernetes.grafanaDashboards,
      //$.mixins.prometheus.grafanaDashboards,
    },
  },
}
