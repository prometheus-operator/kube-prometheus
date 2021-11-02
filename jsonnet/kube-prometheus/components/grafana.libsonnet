local kubernetesGrafana = import 'github.com/brancz/kubernetes-grafana/grafana/grafana.libsonnet';

local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  name:: 'grafana',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  resources:: {
    requests: { cpu: '100m', memory: '100Mi' },
    limits: { cpu: '200m', memory: '200Mi' },
  },
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'grafana',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  prometheusName:: error 'must provide prometheus name',
};

function(params)
  local config = defaults + params;
  // Safety check
  assert std.isObject(config.resources);

  kubernetesGrafana(config) {
    local g = self,
    _config+:: config,
    _metadata:: {
      name: 'grafana',
      namespace: g._config.namespace,
      labels: g._config.commonLabels,
    },

    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: g._metadata,
      spec: {
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'grafana',
          },
        },
        endpoints: [{
          port: 'http',
          interval: '15s',
        }],
      },
    },
  }
