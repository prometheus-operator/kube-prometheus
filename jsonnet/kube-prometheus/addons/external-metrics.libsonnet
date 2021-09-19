// External metrics API allows the HPA v2 to scale based on metrics coming from outside of Kubernetes cluster
// For more details on usage visit https://github.com/DirectXMan12/k8s-prometheus-adapter#quick-links

{
  values+:: {
    prometheusAdapter+: {
      namespace: $.values.common.namespace,
      // Rules for external-metrics
      config+:: {
        externalRules+: [
          // {
          //   seriesQuery: '{__name__=~"^.*_queue$",namespace!=""}',
          //   seriesFilters: [],
          //   resources: {
          //     overrides: {
          //       namespace: { resource: 'namespace' }
          //     },
          //   },
          //   name: { matches: '^.*_queue$', as: '$0' },
          //   metricsQuery: 'max(<<.Series>>{<<.LabelMatchers>>})',
          // },
        ],
      },
    },
  },

  prometheusAdapter+: {
    externalMetricsApiService: {
      apiVersion: 'apiregistration.k8s.io/v1',
      kind: 'APIService',
      metadata: {
        name: 'v1beta1.external.metrics.k8s.io',
      },
      spec: {
        service: {
          name: $.prometheusAdapter.service.metadata.name,
          namespace: $.values.prometheusAdapter.namespace,
        },
        group: 'external.metrics.k8s.io',
        version: 'v1beta1',
        insecureSkipTLSVerify: true,
        groupPriorityMinimum: 100,
        versionPriority: 100,
      },
    },
    externalMetricsClusterRoleServerResources: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'external-metrics-server-resources',
      },
      rules: [{
        apiGroups: ['external.metrics.k8s.io'],
        resources: ['*'],
        verbs: ['*'],
      }],
    },
    externalMetricsClusterRoleBindingServerResources: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'external-metrics-server-resources',
      },

      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'external-metrics-server-resources',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: $.prometheusAdapter.serviceAccount.metadata.name,
        namespace: $.values.prometheusAdapter.namespace,
      }],
    },
    externalMetricsClusterRoleBindingHPA: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'hpa-controller-external-metrics',
      },

      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'external-metrics-server-resources',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: 'horizontal-pod-autoscaler',
        namespace: 'kube-system',
      }],
    },
  },
}
