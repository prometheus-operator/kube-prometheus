local configmap(name, namespace, data) = {
    apiVersion: "v1",
    kind: "ConfigMap",
    metadata : {
        name: name,
        namespace: namespace,
    },
    data: data,
 };

local kp =
    // different libsonnet imported
  {
      configmap+:: {
          'alert-templates': configmap(
          'alertmanager-alert-template.tmpl',
          $._config.namespace,
          {"data": importstr 'alertmanager-alert-template.tmpl'},
          )
      },
      alertmanager+:{
            spec+:{
                # the important field configmaps:
                configMaps: ['alert-templates',], # goes to etc/alermanager/configmaps
            },
      },
};
{ [name + '-configmap']: kp.configmap[name] for name in std.objectFields(kp.configmap) }
