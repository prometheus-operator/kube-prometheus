local defaults = {
  namespace: error 'must provide namespace',
};

function(params) {
  local m = self,
  config:: defaults + params,
  base+:
    (import '../alerts/general.libsonnet') +
    (import '../alerts/node.libsonnet') +
    (import '../rules/node-rules.libsonnet') +
    (import '../rules/general.libsonnet') {
      _config+:: {
        nodeExporterSelector: 'job="node-exporter"',
        hostNetworkInterfaceSelector: 'device!~"veth.+"',
      },
    },

  kubernetes:
    (import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet') {
      _config+:: {
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
}
