{
  _config+:: {
    namespace: 'default',

    versions+:: { prometheusAdapter: 'v0.8.2' },
    imageRepos+:: { prometheusAdapter: 'directxman12/k8s-prometheus-adapter' },

    prometheusAdapter+:: {
      name: 'prometheus-adapter',
      namespace: $._config.namespace,
      labels: { name: $._config.prometheusAdapter.name },
      prometheusURL: 'http://prometheus-' + $._config.prometheus.name + '.' + $._config.namespace + '.svc.cluster.local:9090/',
      config: {
        resourceRules: {
          cpu: {
            containerQuery: 'sum(irate(container_cpu_usage_seconds_total{<<.LabelMatchers>>,container!="POD",container!="",pod!=""}[5m])) by (<<.GroupBy>>)',
            nodeQuery: 'sum(1 - irate(node_cpu_seconds_total{mode="idle"}[5m]) * on(namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:{<<.LabelMatchers>>}) by (<<.GroupBy>>)',
            resources: {
              overrides: {
                node: { resource: 'node' },
                namespace: { resource: 'namespace' },
                pod: { resource: 'pod' },
              },
            },
            containerLabel: 'container',
          },
          memory: {
            containerQuery: 'sum(container_memory_working_set_bytes{<<.LabelMatchers>>,container!="POD",container!="",pod!=""}) by (<<.GroupBy>>)',
            nodeQuery: 'sum(node_memory_MemTotal_bytes{job="node-exporter",<<.LabelMatchers>>} - node_memory_MemAvailable_bytes{job="node-exporter",<<.LabelMatchers>>}) by (<<.GroupBy>>)',
            resources: {
              overrides: {
                instance: { resource: 'node' },
                namespace: { resource: 'namespace' },
                pod: { resource: 'pod' },
              },
            },
            containerLabel: 'container',
          },
          window: '5m',
        },
      },
    },
  },

  prometheusAdapter+:: {
    apiService: {
      apiVersion: 'apiregistration.k8s.io/v1',
      kind: 'APIService',
      metadata: {
        name: 'v1beta1.metrics.k8s.io',
      },
      spec: {
        service: {
          name: $.prometheusAdapter.service.metadata.name,
          namespace: $._config.prometheusAdapter.namespace,
        },
        group: 'metrics.k8s.io',
        version: 'v1beta1',
        insecureSkipTLSVerify: true,
        groupPriorityMinimum: 100,
        versionPriority: 100,
      },
    },

    configMap: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'adapter-config',
        namespace: $._config.prometheusAdapter.namespace,
      },
      data: { 'config.yaml': std.manifestYamlDoc($._config.prometheusAdapter.config) },
    },

    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: $._config.prometheusAdapter.name,
        namespace: $._config.prometheusAdapter.namespace,
        labels: $._config.prometheusAdapter.labels,
      },
      spec: {
        selector: {
          matchLabels: $._config.prometheusAdapter.labels,
        },
        endpoints: [
          {
            port: 'https',
            interval: '30s',
            scheme: 'https',
            tlsConfig: {
              insecureSkipVerify: true,
            },
            bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          },
        ],
      },
    },

    service: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: $._config.prometheusAdapter.name,
        namespace: $._config.prometheusAdapter.namespace,
        labels: $._config.prometheusAdapter.labels,
      },
      spec: {
        ports: [
          { name: 'https', targetPort: 6443, port: 443 },
        ],
        selector: $._config.prometheusAdapter.labels,
      },
    },

    deployment:
      local c = {
        name: $._config.prometheusAdapter.name,
        image: $._config.imageRepos.prometheusAdapter + ':' + $._config.versions.prometheusAdapter,
        args: [
          '--cert-dir=/var/run/serving-cert',
          '--config=/etc/adapter/config.yaml',
          '--logtostderr=true',
          '--metrics-relist-interval=1m',
          '--prometheus-url=' + $._config.prometheusAdapter.prometheusURL,
          '--secure-port=6443',
        ],
        ports: [{ containerPort: 6443 }],
        volumeMounts: [
          { name: 'tmpfs', mountPath: '/tmp', readOnly: false },
          { name: 'volume-serving-cert', mountPath: '/var/run/serving-cert', readOnly: false },
          { name: 'config', mountPath: '/etc/adapter', readOnly: false },
        ],
      };

      {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: $._config.prometheusAdapter.name,
          namespace: $._config.prometheusAdapter.namespace,
        },
        spec: {
          replicas: 1,
          selector: { matchLabels: $._config.prometheusAdapter.labels },
          strategy: {
            rollingUpdate: {
              maxSurge: 1,
              maxUnavailable: 0,
            },
          },
          template: {
            metadata: { labels: $._config.prometheusAdapter.labels },
            spec: {
              containers: [c],
              serviceAccountName: $.prometheusAdapter.serviceAccount.metadata.name,
              nodeSelector: { 'kubernetes.io/os': 'linux' },
              volumes: [
                { name: 'tmpfs', emptyDir: {} },
                { name: 'volume-serving-cert', emptyDir: {} },
                { name: 'config', configMap: { name: 'adapter-config' } },
              ],
            },
          },
        },
      },

    serviceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: $._config.prometheusAdapter.name,
        namespace: $._config.prometheusAdapter.namespace,
      },
    },

    clusterRole: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: $._config.prometheusAdapter.name,
      },
      rules: [{
        apiGroups: [''],
        resources: ['nodes', 'namespaces', 'pods', 'services'],
        verbs: ['get', 'list', 'watch'],
      }],
    },

    clusterRoleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: $._config.prometheusAdapter.name,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: $.prometheusAdapter.clusterRole.metadata.name,
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: $.prometheusAdapter.serviceAccount.metadata.name,
        namespace: $._config.prometheusAdapter.namespace,
      }],
    },

    clusterRoleBindingDelegator: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'resource-metrics:system:auth-delegator',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'system:auth-delegator',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: $.prometheusAdapter.serviceAccount.metadata.name,
        namespace: $._config.prometheusAdapter.namespace,
      }],
    },

    clusterRoleServerResources: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'resource-metrics-server-resources',
      },
      rules: [{
        apiGroups: ['metrics.k8s.io'],
        resources: ['*'],
        verbs: ['*'],
      }],
    },

    clusterRoleAggregatedMetricsReader: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'system:aggregated-metrics-reader',
        labels: {
          'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
          'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
          'rbac.authorization.k8s.io/aggregate-to-view': 'true',
        },
      },
      rules: [{
        apiGroups: ['metrics.k8s.io'],
        resources: ['pods', 'nodes'],
        verbs: ['get', 'list', 'watch'],
      }],
    },

    roleBindingAuthReader: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBinding',
      metadata: {
        name: 'resource-metrics-auth-reader',
        namespace: 'kube-system',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'extension-apiserver-authentication-reader',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: $.prometheusAdapter.serviceAccount.metadata.name,
        namespace: $._config.prometheusAdapter.namespace,
      }],
    },
  },
}
