local defaults = {
  name: 'kubernetes',
  namespace: error 'must provide namespace',
  commonLabels:: {
    'app.kubernetes.io/name': 'kube-prometheus',
    'app.kubernetes.io/component': 'exporter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  mixin: {
    ruleLabels: {},
    _config: {
      cadvisorSelector: 'job="kubelet", metrics_path="/metrics/cadvisor"',
      kubeletSelector: 'job="kubelet", metrics_path="/metrics"',
      kubeStateMetricsSelector: 'job="kube-state-metrics"',
      nodeExporterSelector: 'job="node-exporter"',
      kubeSchedulerSelector: 'job="kube-scheduler"',
      kubeControllerManagerSelector: 'job="kube-controller-manager"',
      kubeApiserverSelector: 'job="apiserver"',
      podLabel: 'pod',
      runbookURLPattern: 'https://github.com/prometheus-operator/kube-prometheus/wiki/%s',
      diskDeviceSelector: 'device=~"mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|dasd.+"',
      hostNetworkInterfaceSelector: 'device!~"veth.+"',
    },
  },
};

function(params) {
  local m = self,
  config:: defaults + params,

  mixin:: (import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet') {
    _config+:: m.config.mixin._config,
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: m.config.commonLabels + m.config.mixin.ruleLabels,
      name: m.config.name + '-rules',
      namespace: m.config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(m.mixin, 'prometheusRules') then m.mixin.prometheusRules.groups else {},
      local a = if std.objectHasAll(m.mixin, 'prometheusAlerts') then m.mixin.prometheusAlerts.groups else {},
      groups: a + r,
    },
  },
}
