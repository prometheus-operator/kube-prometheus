// Custom metrics API allows the HPA v2 to scale based on arbirary metrics.
// For more details on usage visit https://github.com/DirectXMan12/k8s-prometheus-adapter#quick-links

{
  values+:: {
    prometheusAdapter+: {
      // Rules for custom-metrics
      config+:: {
        rules+: [
          {
            seriesQuery: '{__name__=~"^container_.*",container!="POD",namespace!="",pod!=""}',
            seriesFilters: [],
            resources: {
              overrides: {
                namespace: { resource: 'namespace' },
                pod: { resource: 'pod' },
              },
            },
            name: { matches: '^container_(.*)_seconds_total$', as: '' },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>,container!="POD"}[1m])) by (<<.GroupBy>>)',
          },
          {
            seriesQuery: '{__name__=~"^container_.*",container!="POD",namespace!="",pod!=""}',
            seriesFilters: [
              { isNot: '^container_.*_seconds_total$' },
            ],
            resources: {
              overrides: {
                namespace: { resource: 'namespace' },
                pod: { resource: 'pod' },
              },
            },
            name: { matches: '^container_(.*)_total$', as: '' },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>,container!="POD"}[1m])) by (<<.GroupBy>>)',
          },
          {
            seriesQuery: '{__name__=~"^container_.*",container!="POD",namespace!="",pod!=""}',
            seriesFilters: [
              { isNot: '^container_.*_total$' },
            ],
            resources: {
              overrides: {
                namespace: { resource: 'namespace' },
                pod: { resource: 'pod' },
              },
            },
            name: { matches: '^container_(.*)$', as: '' },
            metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>,container!="POD"}) by (<<.GroupBy>>)',
          },
          {
            seriesQuery: '{namespace!="",__name__!~"^container_.*"}',
            seriesFilters: [
              { isNot: '.*_total$' },
            ],
            resources: { template: '<<.Resource>>' },
            name: { matches: '', as: '' },
            metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)',
          },
          {
            seriesQuery: '{namespace!="",__name__!~"^container_.*"}',
            seriesFilters: [
              { isNot: '.*_seconds_total' },
            ],
            resources: { template: '<<.Resource>>' },
            name: { matches: '^(.*)_total$', as: '' },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)',
          },
          {
            seriesQuery: '{namespace!="",__name__!~"^container_.*"}',
            seriesFilters: [],
            resources: { template: '<<.Resource>>' },
            name: { matches: '^(.*)_seconds_total$', as: '' },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)',
          },
        ],
      },
    },
  },

  prometheusAdapter+: {
    customMetricsApiService: {
      apiVersion: 'apiregistration.k8s.io/v1',
      kind: 'APIService',
      metadata: {
        name: 'v1beta1.custom.metrics.k8s.io',
      },
      spec: {
        service: {
          name: $.prometheusAdapter.service.metadata.name,
          namespace: $.values.prometheusAdapter.namespace,
        },
        group: 'custom.metrics.k8s.io',
        version: 'v1beta1',
        insecureSkipTLSVerify: true,
        groupPriorityMinimum: 100,
        versionPriority: 100,
      },
    },
    customMetricsApiServiceV1Beta2: {
      apiVersion: 'apiregistration.k8s.io/v1',
      kind: 'APIService',
      metadata: {
        name: 'v1beta2.custom.metrics.k8s.io',
      },
      spec: {
        service: {
          name: $.prometheusAdapter.service.metadata.name,
          namespace: $.values.prometheusAdapter.namespace,
        },
        group: 'custom.metrics.k8s.io',
        version: 'v1beta2',
        insecureSkipTLSVerify: true,
        groupPriorityMinimum: 100,
        versionPriority: 200,
      },
    },
    customMetricsClusterRoleServerResources: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'custom-metrics-server-resources',
      },
      rules: [{
        apiGroups: ['custom.metrics.k8s.io'],
        resources: ['*'],
        verbs: ['*'],
      }],
    },
    customMetricsClusterRoleBindingServerResources: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'custom-metrics-server-resources',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'custom-metrics-server-resources',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: $.prometheusAdapter.serviceAccount.metadata.name,
        namespace: $.values.prometheusAdapter.namespace,
      }],
    },
    customMetricsClusterRoleBindingHPA: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'hpa-controller-custom-metrics',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'custom-metrics-server-resources',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: 'horizontal-pod-autoscaler',
        namespace: 'kube-system',
      }],
    },
  },
}
