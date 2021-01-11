{
  // Add you mixins here.
  mixins+:: {
    _config:: {  // TODO(paulfantom): figure out how to pass this from higher up
      prometheusName: 'k8s',
      alertmanagerName: 'main',
      namespace: 'default',
    },
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

    kubeStateMetrics:
      (import 'github.com/kubernetes/kube-state-metrics/jsonnet/kube-state-metrics-mixin/mixin.libsonnet') {
        _config+:: {
          kubeStateMetricsSelector: 'job="kube-state-metrics"',
        },
      },

    prometheusOperator:
      (import 'github.com/prometheus-operator/prometheus-operator/jsonnet/mixin/mixin.libsonnet') {
        _config+:: {
          //prometheusOperatorSelector: 'job="prometheus-operator",namespace="' + $._config.namespace + '"',
          prometheusOperatorSelector: 'job="prometheus-operator",namespace="monitoring"',
        },
      },

    prometheus:
      (import 'github.com/prometheus/prometheus/documentation/prometheus-mixin/mixin.libsonnet') {
        _config+:: {
          //prometheusSelector: 'job="prometheus-' + $._config.prometheusName + '",namespace="' + $._config.namespace + '"',
          prometheusSelector: 'job="prometheus-k8s",namespace="monitoring"',
          prometheusName: '{{$labels.namespace}}/{{$labels.pod}}',
        },
      },

    alertmanager:
      (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/mixin.libsonnet') {
        _config+:: {
          alertmanagerName: '{{ $labels.namespace }}/{{ $labels.pod}}',
          alertmanagerClusterLabels: 'namespace,service',
          //alertmanagerSelector: 'job="alertmanager-' + $._config.alertmanagerName + '",namespace="' + $._config.namespace + '"',
          alertmanagerSelector: 'job="alertmanager-main",namespace="monitoring"',
        },
      },

    nodeExporter:
      (import 'github.com/prometheus/node_exporter/docs/node-mixin/mixin.libsonnet') {
        _config+:: {
          nodeExporterSelector: 'job="node-exporter"',
          fsSpaceFillingUpCriticalThreshold: 15,
          diskDeviceSelector: 'device=~"mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|dasd.+"',
        },
      },

  },
}
