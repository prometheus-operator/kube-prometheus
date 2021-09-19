local addMixin = (import 'kube-prometheus/lib/mixin.libsonnet');
local etcdMixin = addMixin({
  name: 'etcd',
  mixin: (import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet') + {
    _config+: {},  // mixin configuration object
  },
});

local kp = (import 'kube-prometheus/main.libsonnet') +
           {
             values+:: {
               common+: {
                 namespace: 'monitoring',
               },
               grafana+: {
                 // Adding new dashboard to grafana. This will modify grafana configMap with dashboards
                 dashboards+: etcdMixin.grafanaDashboards,
               },
             },
           };

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
// Rendering prometheusRules object. This is an object compatible with prometheus-operator CRD definition for prometheusRule
{ 'external-mixins/etcd-mixin-prometheus-rules': etcdMixin.prometheusRules }
