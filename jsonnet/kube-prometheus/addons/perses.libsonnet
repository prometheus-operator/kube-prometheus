{
  values+:: {
    common+: {
      versions+: {
        perses: error 'must provide version',
        persesOperator: error 'must provide version',
      } + (import '../versions.json'),
      images+: {
        perses: 'persesdev/perses:v' + $.values.common.versions.perses,
        persesOperator: 'persesdev/perses-operator:v' + $.values.common.versions.persesOperator,
      },
    },
    perses+: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.perses,
      image: $.values.common.images.perses,
      operatorVersion: $.values.common.versions.persesOperator,
      operatorImage: $.values.common.images.persesOperator,
    },
    prometheus+: {
      externalLabels+: {
        cluster: 'kube-prometheus',
      },
    },
  },

  local defaults = {
    local defaults = self,
    name:: 'perses',
    operatorName:: 'perses-operator',
    namespace:: error 'must provide namespace',
    version:: error 'must provide version',
    image:: error 'must provide image',
    operatorVersion:: error 'must provide operator version',
    operatorImage:: error 'must provide operator image',
    // Enable conversion webhooks (v1alpha1 <-> v1alpha2). Requires cert-manager.
    enableWebhooks:: false,
    // Rewire community-mixins job selectors to match kube-prometheus kubernetesControlPlane mixin.
    cadvisorJobSelector:: 'job="kubelet", metrics_path="/metrics/cadvisor"',
    kubeApiserverJobSelector:: 'job="apiserver"',
    commonLabels:: {
      'app.kubernetes.io/name': defaults.name,
      'app.kubernetes.io/version': defaults.version,
      'app.kubernetes.io/part-of': 'kube-prometheus',
    },
  },

  local persesOperatorLib = import 'github.com/perses/perses-operator/jsonnet/perses-operator.libsonnet',

  local perses = function(params) {
    local p = self,
    _config:: defaults + params,
    local ns = p._config.namespace,

    local queryRewrites = [
      { from: 'job="cadvisor"', to: p._config.cadvisorJobSelector },
      { from: 'job="kube-apiserver"', to: p._config.kubeApiserverJobSelector },
    ],

    local rewireQuery(query) =
      std.foldl(
        function(q, rewrite) std.strReplace(q, rewrite.from, rewrite.to),
        queryRewrites,
        query,
      ),

    local patchDashboard(dashboard) = dashboard {
      metadata+: { namespace: ns },
      spec+: {
        config+: {
          panels: {
            [panelKey]: dashboard.spec.config.panels[panelKey] {
              spec+: if std.objectHas(dashboard.spec.config.panels[panelKey].spec, 'queries') then {
                queries: [
                  query {
                    spec+: {
                      plugin+: if std.objectHas(query.spec.plugin, 'spec') && std.objectHas(query.spec.plugin.spec, 'query') then {
                        spec+: {
                          query: rewireQuery(query.spec.plugin.spec.query),
                        },
                      } else {},
                    },
                  }
                  for query in dashboard.spec.config.panels[panelKey].spec.queries
                ],
              } else {},
            }
            for panelKey in std.objectFields(dashboard.spec.config.panels)
          },
          variables: if std.objectHas(dashboard.spec.config, 'variables') then [
            variable {
              spec+: {
                plugin+: if std.objectHas(variable.spec.plugin, 'spec') && std.objectHas(variable.spec.plugin.spec, 'matchers') then {
                  spec+: {
                    matchers: [
                      rewireQuery(matcher)
                      for matcher in variable.spec.plugin.spec.matchers
                    ],
                  },
                } else {},
              },
            }
            for variable in dashboard.spec.config.variables
          ] else [],
        },
      },
    },

    operator:: persesOperatorLib({
      name: p._config.operatorName,
      namespace: p._config.namespace,
      version: p._config.operatorVersion,
      image: p._config.operatorImage,
    }),

    '0persesCustomResourceDefinition': p.operator['0persesCustomResourceDefinition'],
    '0persesdashboardsCustomResourceDefinition': p.operator['0persesdashboardsCustomResourceDefinition'],
    '0persesdatasourcesCustomResourceDefinition': p.operator['0persesdatasourcesCustomResourceDefinition'],
    '0persesglobaldatasourcesCustomResourceDefinition': p.operator['0persesglobaldatasourcesCustomResourceDefinition'],

    operatorDeployment: p.operator.deployment {
      spec+: {
        template+: {
          spec+: {
            containers: [
              c {
                env+: if !p._config.enableWebhooks then [{ name: 'ENABLE_WEBHOOKS', value: 'false' }] else [],
              }
              for c in p.operator.deployment.spec.template.spec.containers
            ],
          },
        },
      },
    },
    operatorServiceAccount: p.operator.serviceAccount,
    operatorRole: p.operator.role,
    operatorRoleBinding: p.operator.roleBinding,
    operatorLeaderElectionRole: p.operator.leaderElectionRole,
    operatorLeaderElectionRoleBinding: p.operator.leaderElectionRoleBinding,
    operatorPersesEditorRole: p.operator.persesEditorRole,
    operatorPersesViewerRole: p.operator.persesViewerRole,
    operatorPersesDashboardEditorRole: p.operator.persesDashboardEditorRole,
    operatorPersesDashboardViewerRole: p.operator.persesDashboardViewerRole,
    operatorPersesDatasourceEditorRole: p.operator.persesDatasourceEditorRole,
    operatorPersesDatasourceViewerRole: p.operator.persesDatasourceViewerRole,
    operatorPersesGlobalDatasourceEditorRole: p.operator.persesGlobalDatasourceEditorRole,
    operatorPersesGlobalDatasourceViewerRole: p.operator.persesGlobalDatasourceViewerRole,
    operatorServiceMonitor: p.operator.serviceMonitor,
    operatorPrometheusRule: p.operator.prometheusRule,

    persesInstance: {
      apiVersion: 'perses.dev/v1alpha2',
      kind: 'Perses',
      metadata: {
        name: p._config.name,
        namespace: p._config.namespace,
        labels: p._config.commonLabels,
      },
      spec: {
        containerPort: 8080,
        image: p._config.image,
        config: {
          security: {
            readonly: false,
            enable_auth: false,
            cookie: {
              secure: false,
            },
          },
          database: {
            file: {
              folder: '/perses/data',
              extension: 'json',
            },
          },
        },
      },
    },

    prometheusGlobalDatasource: {
      apiVersion: 'perses.dev/v1alpha2',
      kind: 'PersesGlobalDatasource',
      metadata: {
        name: 'prometheus-datasource',
        labels: p._config.commonLabels,
      },
      spec: {
        instanceSelector: {
          matchLabels: {
            'app.kubernetes.io/name': p._config.name,
          },
        },
        config: {
          display: {
            name: 'Prometheus',
          },
          default: true,
          plugin: {
            kind: 'PrometheusDatasource',
            spec: {
              proxy: {
                kind: 'HTTPProxy',
                spec: {
                  url: 'http://prometheus-k8s.%s.svc.cluster.local:9090' % p._config.namespace,
                },
              },
            },
          },
        },
      },
    },

    'dashboard-api-server-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/api-server-overview.json'),
    'dashboard-controller-manager-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/controller-manager-overview.json'),
    'dashboard-kubelet-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubelet-overview.json'),
    'dashboard-kubernetes-cluster-networking-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-cluster-networking-overview.json'),
    'dashboard-kubernetes-cluster-resources-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-cluster-resources-overview.json'),
    'dashboard-kubernetes-multi-cluster-resources-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-multi-cluster-resources-overview.json'),
    'dashboard-kubernetes-namespace-networking-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-namespace-networking-overview.json'),
    'dashboard-kubernetes-namespace-resources-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-namespace-resources-overview.json'),
    'dashboard-kubernetes-node-resources-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-node-resources-overview.json'),
    'dashboard-kubernetes-persistent-volume-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-persistent-volume-overview.json'),
    'dashboard-kubernetes-pod-networking-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-pod-networking-overview.json'),
    'dashboard-kubernetes-pod-resources-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-pod-resources-overview.json'),
    'dashboard-kubernetes-workload-networking-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-workload-networking-overview.json'),
    'dashboard-kubernetes-workload-ns-networking-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-workload-ns-networking-overview.json'),
    'dashboard-kubernetes-workload-ns-resources-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-workload-ns-resources-overview.json'),
    'dashboard-kubernetes-workload-resources-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/kubernetes-workload-resources-overview.json'),
    'dashboard-proxy-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/proxy-overview.json'),
    'dashboard-scheduler-overview':
      patchDashboard(import 'github.com/perses/community-mixins/jsonnet/dashboards/operator/kubernetes/scheduler-overview.json'),
  },

  prometheus+: {
    networkPolicy+: {
      spec+: {
        ingress+: [{
          from: [{
            podSelector: {
              matchLabels: {
                'app.kubernetes.io/name': 'perses',
              },
            },
          }],
          ports: [{
            port: 9090,
            protocol: 'TCP',
          }],
        }],
      },
    },
  },

  perses: perses($.values.perses),
}
