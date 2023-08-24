local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // Uncomment the following imports to enable its patches
  // (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/managed-cluster.libsonnet') +
  // (import 'kube-prometheus/addons/node-ports.libsonnet') +
  // (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  // (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
  // (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  // (import 'kube-prometheus/addons/pyrra.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },
  };

// Unlike in kube-prometheus/example.jsonnet where a map of file-names to manifests is returned,
// for ArgoCD we need to return just a regular list with all the manifests.
local manifests =
  [ kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) ] +
  [ kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) ] +
  [ kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) ] +
  [ kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) ] +
  [ kp.grafana[name] for name in std.objectFields(kp.grafana) ] +
  // [ kp.pyrra[name] for name in std.objectFields(kp.pyrra) ] +
  [ kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) ] +
  [ kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) ] +
  [ kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) ] +
  [ kp.prometheus[name] for name in std.objectFields(kp.prometheus) ] +
  [ kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) ];

manifests
