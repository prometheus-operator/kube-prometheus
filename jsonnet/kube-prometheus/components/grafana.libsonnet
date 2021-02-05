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
  // TODO(paulfantom): expose those to have a stable API. After kubernetes-grafana refactor those could probably be removed.
  rawDashboards: {},
  folderDashboards: {},
  containers: [],
  datasources: [],
  config: {},
};

function(params) {
  local g = self,
  cfg:: defaults + params,
  // Safety check
  assert std.isObject(g.cfg.resources),

  local glib = (import 'github.com/brancz/kubernetes-grafana/grafana/grafana.libsonnet') + {
    _config+:: {
      namespace: g.cfg.namespace,
      versions+:: {
        grafana: g.cfg.version,
      },
      imageRepos+:: {
        grafana: g.cfg.imageRepos,
      },
      prometheus+:: {
        name: g.cfg.prometheusName,
      },
      grafana+:: {
        labels: g.cfg.commonLabels,
        dashboards: g.cfg.dashboards,
        resources: g.cfg.resources,
        rawDashboards: g.cfg.rawDashboards,
        folderDashboards: g.cfg.folderDashboards,
        containers: g.cfg.containers,
        config+: g.cfg.config,
      } + (
        // Conditionally overwrite default setting.
        if std.length(g.cfg.datasources) > 0 then
          { datasources: g.cfg.datasources }
        else {}
      ),
    },
  },

  // Add object only if user passes config and config is not empty
  [if std.objectHas(params, 'config') && std.length(params.config) > 0 then 'config']: glib.grafana.config,
  service: glib.grafana.service,
  serviceAccount: glib.grafana.serviceAccount,
  deployment: glib.grafana.deployment,
  dashboardDatasources: glib.grafana.dashboardDatasources,
  dashboardSources: glib.grafana.dashboardSources,

  dashboardDefinitions: if std.length(g.cfg.dashboards) > 0 then {
    apiVersion: 'v1',
    kind: 'ConfigMapList',
    items: glib.grafana.dashboardDefinitions,
  },
  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'grafana',
      namespace: g.cfg.namespace,
      labels: g.cfg.commonLabels,
    },
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
