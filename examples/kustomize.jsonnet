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
  { 'setup/0-namespace': kp.kubePrometheus.namespace } +
  {
    ['setup/prometheus-operator/' + name]: kp.prometheusOperator[name]
    for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
  } +
  // serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
  { 'prometheus-operator/serviceMonitor': kp.prometheusOperator.serviceMonitor } +
  { 'prometheus-operator/prometheusRule': kp.prometheusOperator.prometheusRule } +
  { 'kube-prometheus/prometheusRule': kp.kubePrometheus.prometheusRule } +
  { ['node-exporter/' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
  { ['blackbox-exporter/' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
  { ['kube-state-metrics/' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
  { ['alertmanager/' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
  { ['prometheus/' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
  { ['prometheus/namespaced/' + name]: kp.rbac.namespaced[name], for name in std.objectFields(kp.rbac.namespaced) } +
  { ['prometheus/cluster/' + name]: kp.rbac.cluster[name], for name in std.objectFields(kp.rbac.cluster) } +
  { ['prometheus-adapter/' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
  { ['grafana/' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
  { ['control-plane/' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) };

local kustomizationPaths = std.foldl(
  function (result, file) (
    local parts = std.split(file, '/');
    local i = std.length(parts)-1;
    local key = std.join('/', parts[:i]);
    local value = parts[i];
    result + ({ [key]+: [ value + '.yaml' ] })
  ),
  std.objectFields(manifests),
  {},
);

local isDirectDescendant(base) = function(child) (
  local baseParts = (if base == '/' then [] else std.split(base, '/'));
  local childParts = std.split(child, '/');
  std.length(std.setInter(childParts, baseParts)) == std.length(baseParts) &&
  std.length(std.setDiff(childParts, baseParts)) == 1
);

local buildKustomization(resources) = (
  {
    apiVersion: 'kustomize.config.k8s.io/v1beta1',
    kind: 'Kustomization',
    resources: resources,
  }
);

local buildKustomizationFromPath(base) = buildKustomization(
  kustomizationPaths[base] + std.filterMap(
    isDirectDescendant(base),
    function(path) (std.strReplace(path, base + '/', '')),
    std.objectFields(kustomizationPaths),
  ),
);

manifests {
  '/kustomization': buildKustomization(
    std.filter(isDirectDescendant('/'), std.objectFields(kustomizationPaths))
  ),
} + {
  [path + '/kustomization']: buildKustomizationFromPath(path), for path in std.objectFields(kustomizationPaths)
}
