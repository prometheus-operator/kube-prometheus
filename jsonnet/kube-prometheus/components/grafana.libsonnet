local defaults = {
  local defaults = self,
  name: 'grafana',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
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
  plugins: [],
  env: [],
};

function(params) {
  local g = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(g._config.resources),

  local glib = (import 'github.com/brancz/kubernetes-grafana/grafana/grafana.libsonnet') + {
    _config+:: {
      namespace: g._config.namespace,
      versions+:: {
        grafana: g._config.version,
      },
      imageRepos+:: {
        grafana: std.split(g._config.image, ':')[0],
      },
      prometheus+:: {
        name: g._config.prometheusName,
      },
      grafana+:: {
        labels: g._config.commonLabels,
        dashboards: g._config.dashboards,
        resources: g._config.resources,
        rawDashboards: g._config.rawDashboards,
        folderDashboards: g._config.folderDashboards,
        containers: g._config.containers,
        config+: g._config.config,
        plugins+: g._config.plugins,
        env: g._config.env,
      } + (
        // Conditionally overwrite default setting.
        if std.length(g._config.datasources) > 0 then
          { datasources: g._config.datasources }
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

  dashboardDefinitions: if std.length(g._config.dashboards) > 0 ||
                           std.length(g._config.rawDashboards) > 0 ||
                           std.length(g._config.folderDashboards) > 0 then {
    apiVersion: 'v1',
    kind: 'ConfigMapList',
    items: glib.grafana.dashboardDefinitions,
  },
  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'grafana',
      namespace: g._config.namespace,
      labels: g._config.commonLabels,
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
