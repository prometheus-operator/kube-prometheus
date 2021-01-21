local kp =
  (import 'kube-prometheus/main.libsonnet') + {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },
  };

local manifests =
  // Uncomment line below to enable vertical auto scaling of kube-state-metrics
  //{ ['ksm-autoscaler-' + name]: kp.ksmAutoscaler[name] for name in std.objectFields(kp.ksmAutoscaler) } +
  { 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
  {
    ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
    for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
  } +
  // serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
  { 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
  { 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
  { 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
  { ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
  { ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
  { ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
  { ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
  { ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
  { ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
  { ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
  { ['kubernetes-' + name]: kp.kubernetesMixin[name] for name in std.objectFields(kp.kubernetesMixin) };

local kustomizationResourceFile(name) = './manifests/' + name + '.yaml';
local kustomization = {
  apiVersion: 'kustomize.config.k8s.io/v1beta1',
  kind: 'Kustomization',
  resources: std.map(kustomizationResourceFile, std.objectFields(manifests)),
};

manifests {
  '../kustomization': kustomization,
}
