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
      kubeRbacProxyImage: $.values.common.images.kubeRbacProxy,
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
    kubeRbacProxyImage:: error 'must provide kubeRbacProxyImage',
    kubeRbacProxy:: {
      resources+: {
        requests: { cpu: '10m', memory: '20Mi' },
        limits: { cpu: '20m', memory: '40Mi' },
      },
    },
    // Enable conversion webhooks (v1alpha1 <-> v1alpha2). Requires cert-manager.
    enableWebhooks:: false,
    // community-mixins packages aligned with default kube-prometheus Grafana mixin dashboards.
    dashboardComponents:: [
      'kubernetes',
      'prometheus',
      'alertmanager',
      'node-exporter',
    ],
    dashboardCommonLabels:: {
      'app.kubernetes.io/component': 'dashboard',
      'app.kubernetes.io/name': 'perses-dashboard',
      'app.kubernetes.io/part-of': 'kube-prometheus',
    },
    globalDatasourceName:: 'prometheus-datasource',
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
  local communityMixinsDashboards = import 'github.com/perses/community-mixins/jsonnet/dashboards.libsonnet',
  local krp = import '../components/kube-rbac-proxy.libsonnet',

  local dashboardResources(config) = {
    local importedDashboards = communityMixinsDashboards({
      namespace: config.namespace,
      commonLabels: config.dashboardCommonLabels,
      datasource: config.globalDatasourceName,
      components: config.dashboardComponents,
    }).dashboards,

    local queryRewrites = [
      { from: 'job="cadvisor"', to: config.cadvisorJobSelector },
      { from: 'job="kube-apiserver"', to: config.kubeApiserverJobSelector },
    ],

    local rewireQuery(query) =
      std.foldl(
        function(q, rewrite) std.strReplace(q, rewrite.from, rewrite.to),
        queryRewrites,
        query,
      ),

    local rewireDashboard(dashboard) = dashboard {
      spec+: {
        config+: {
          panels: {
            [panelKey]: dashboard.spec.config.panels[panelKey] {
              spec+: if std.objectHas(dashboard.spec.config.panels[panelKey].spec, 'queries') then {
                queries: [
                  query {
                    spec+: if std.objectHas(query.spec.plugin, 'spec') && std.objectHas(query.spec.plugin.spec, 'query') then {
                      plugin+: {
                        spec+: {
                          query: rewireQuery(query.spec.plugin.spec.query),
                        },
                      },
                    } else {},
                  }
                  for query in dashboard.spec.config.panels[panelKey].spec.queries
                ],
              } else {},
            }
            for panelKey in std.objectFields(dashboard.spec.config.panels)
          },
          variables: if std.objectHas(dashboard.spec.config, 'variables') then [
            variable {
              spec+: if std.objectHas(variable.spec.plugin, 'spec') && std.objectHas(variable.spec.plugin.spec, 'matchers') then {
                plugin+: {
                  spec+: {
                    matchers: [
                      rewireQuery(matcher)
                      for matcher in variable.spec.plugin.spec.matchers
                    ],
                  },
                },
              } else {},
            }
            for variable in dashboard.spec.config.variables
          ] else [],
        },
      },
    },

    resources: std.foldl(
      function(acc, dashboard) acc {
        ['dashboard-' + dashboard.metadata.name]: rewireDashboard(dashboard),
      },
      importedDashboards,
      {},
    ),
  }.resources,

  local perses = function(params) {
    local p = self,
    _config:: defaults + params,

    operator:: persesOperatorLib({
      name: p._config.operatorName,
      namespace: p._config.namespace,
      version: p._config.operatorVersion,
      image: p._config.operatorImage,
    }),

    local operatorSelectorLabels = p.operator.deployment.spec.selector.matchLabels,
    local operatorLabels = p.operator.deployment.metadata.labels,

    local kubeRbacProxy = krp(p._config.kubeRbacProxy {
      name: 'kube-rbac-proxy',
      upstream: 'http://127.0.0.1:8082/',
      secureListenAddress: ':8443',
      ports: [
        { name: 'https', containerPort: 8443 },
      ],
      image: p._config.kubeRbacProxyImage,
    }),

    '0persesCustomResourceDefinition': p.operator['0persesCustomResourceDefinition'],
    '0persesdashboardsCustomResourceDefinition': p.operator['0persesdashboardsCustomResourceDefinition'],
    '0persesdatasourcesCustomResourceDefinition': p.operator['0persesdatasourcesCustomResourceDefinition'],
    '0persesglobaldatasourcesCustomResourceDefinition': p.operator['0persesglobaldatasourcesCustomResourceDefinition'],

    operatorDeployment: p.operator.deployment {
      spec+: {
        template+: {
          spec+: {
            automountServiceAccountToken: true,
            containers: [
              c {
                args+: if c.name == 'manager' then ['--metrics-bind-address=127.0.0.1:8082'] else [],
                env+: if !p._config.enableWebhooks then [{ name: 'ENABLE_WEBHOOKS', value: 'false' }] else [],
              }
              for c in p.operator.deployment.spec.template.spec.containers
            ] + [kubeRbacProxy],
          },
        },
      },
    },
    operatorService: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: p._config.operatorName,
        namespace: p._config.namespace,
        labels: operatorLabels,
      },
      spec: {
        clusterIP: 'None',
        ports: [{
          name: 'https',
          port: 8443,
          targetPort: 'https',
        }],
        selector: operatorSelectorLabels,
      },
    },
    operatorServiceAccount: p.operator.serviceAccount,
    operatorRole: p.operator.role {
      rules+: [
        {
          apiGroups: ['authentication.k8s.io'],
          resources: ['tokenreviews'],
          verbs: ['create'],
        },
        {
          apiGroups: ['authorization.k8s.io'],
          resources: ['subjectaccessreviews'],
          verbs: ['create'],
        },
      ],
    },
    operatorMetricsReaderClusterRole: (import 'github.com/perses/perses-operator/jsonnet/generated/auth_proxy_client_clusterrole.json') {
      metadata+: {
        name: p._config.operatorName + '-metrics-reader',
        labels: operatorLabels {
          'app.kubernetes.io/component': 'kube-rbac-proxy',
          'app.kubernetes.io/instance': 'metrics-reader',
        },
      },
    },
    operatorMetricsReaderClusterRoleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: p._config.operatorName + '-metrics-reader',
        labels: operatorLabels {
          'app.kubernetes.io/component': 'kube-rbac-proxy',
          'app.kubernetes.io/instance': 'metrics-reader-binding',
        },
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: p._config.operatorName + '-metrics-reader',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: 'prometheus-k8s',
        namespace: p._config.namespace,
      }],
    },
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
    operatorServiceMonitor: p.operator.serviceMonitor {
      spec+: {
        jobLabel: 'app.kubernetes.io/name',
        endpoints: [{
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          path: '/metrics',
          port: 'https',
          scheme: 'https',
          tlsConfig: {
            insecureSkipVerify: true,
          },
        }],
      },
    },
    operatorNetworkPolicy: {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'NetworkPolicy',
      metadata: {
        name: p._config.operatorName,
        namespace: p._config.namespace,
        labels: operatorLabels,
      },
      spec: {
        podSelector: {
          matchLabels: operatorSelectorLabels,
        },
        policyTypes: ['Egress', 'Ingress'],
        egress: [{}],
        ingress: [{
          from: [{
            podSelector: {
              matchLabels: {
                'app.kubernetes.io/name': 'prometheus',
              },
            },
          }],
          ports: [{
            port: 'https',
            protocol: 'TCP',
          }],
        }],
      },
    },
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
        name: p._config.globalDatasourceName,
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

  perses: perses($.values.perses) + dashboardResources(defaults + $.values.perses),
}
