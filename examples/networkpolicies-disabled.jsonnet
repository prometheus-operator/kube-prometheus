local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/addons/networkpolicies-disabled.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
};

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
}
