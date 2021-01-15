local defaults = {
  local defaults = self,
  name: 'grafana',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  // image: error 'must provide image',
  imageRepos: 'grafana/grafana',
  resources: {
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
  prometheusName: error 'must provide prometheus name',
  dashboards: {},
};

function(params) {
  local g = self,
  config:: defaults + params,
  //local g.config = defaults + params,
  // Safety check
  assert std.isObject(g.config.resources),

  local glib = (import 'github.com/brancz/kubernetes-grafana/grafana/grafana.libsonnet') + {
    _config+:: {
      namespace: g.config.namespace,
      versions+:: {
        grafana: g.config.version,
      },
      imageRepos+:: {
        grafana: g.config.imageRepos,
      },
      prometheus+:: {
        name: g.config.prometheusName,
      },
      grafana+:: {
        labels: g.config.commonLabels,
        dashboards: g.config.dashboards,
        resources: g.config.resources,
      },
    },
  },

  service: glib.grafana.service,
  serviceAccount: glib.grafana.serviceAccount,
  deployment: glib.grafana.deployment,
  dashboardDatasources: glib.grafana.dashboardDatasources,
  dashboardSources: glib.grafana.dashboardSources,

  dashboardDefinitions: if std.length(g.config.dashboards) > 0 then {
    apiVersion: 'v1',
    kind: 'ConfigMapList',
    items: glib.grafana.dashboardDefinitions,
  },
  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'grafana',
      namespace: g.config.namespace,
      labels: g.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: {
          app: 'grafana',
        },
      },
      endpoints: [{
        port: 'http',
        interval: '15s',
      }],
    },
  },
}
