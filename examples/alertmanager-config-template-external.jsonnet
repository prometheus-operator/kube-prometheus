local configmap(name, namespace, data) = {
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: name,
    namespace: namespace,
  },
  data: data,
};

local kp =
  // different libsonnet imported
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
      alertmanager+: {
        config: importstr 'alertmanager-config.yaml',
      },
    },
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          // the important field configmaps:
          configMaps: ['alert-templates'],  // goes to etc/alermanager/configmaps
        },
      },
    },
    configmap+:: {
      'alert-templates': configmap(
        'alert-templates',
        $.values.common.namespace,  // could be $._config.namespace to assign namespace once
        { 'alertmanager-alert-template.tmpl': importstr 'alertmanager-alert-template.tmpl' },
      ),
    },
  };
{ [name + '-configmap']: kp.configmap[name] for name in std.objectFields(kp.configmap) }
