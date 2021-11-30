local kp =
  (import 'kube-prometheus/main.libsonnet') + {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },
  };

local manifests =
  {
    ['setup/' + resource]: kp[component][resource]
    for component in std.objectFields(kp)
    for resource in std.filter(
      function(resource)
        kp[component][resource].kind == 'CustomResourceDefinition' || kp[component][resource].kind == 'Namespace', std.objectFields(kp[component])
    )
  } +
  {
    [component + '-' + resource]: kp[component][resource]
    for component in std.objectFields(kp)
    for resource in std.filter(
      function(resource)
        kp[component][resource].kind != 'CustomResourceDefinition' && kp[component][resource].kind != 'Namespace', std.objectFields(kp[component])
    )
  };

local kustomizationResourceFile(name) = './manifests/' + name + '.yaml';
local kustomization = {
  apiVersion: 'kustomize.config.k8s.io/v1beta1',
  kind: 'Kustomization',
  resources: std.map(kustomizationResourceFile, std.objectFields(manifests)),
};

manifests {
  '../kustomization': kustomization,
}
