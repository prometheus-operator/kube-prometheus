local defaults = {
  local defaults = self,
  name: 'prometheus-adapter',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  resources: {
    requests: { cpu: '102m', memory: '180Mi' },
    limits: { cpu: '250m', memory: '180Mi' },
  },
  listenAddress: '127.0.0.1',
  port: 9100,
  commonLabels:: {
    'app.kubernetes.io/name': 'prometheus-adapter',
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'metrics-adapter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },

  prometheusURL: error 'must provide prometheusURL',
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
};

function(params) {
  local pa = self,
  config:: defaults + params,
  // Safety check
  assert std.isObject(pa.config.resources),

  apiService: {
    apiVersion: 'apiregistration.k8s.io/v1',
    kind: 'APIService',
    metadata: {
      name: 'v1beta1.metrics.k8s.io',
      labels: pa.config.commonLabels,
    },
    spec: {
      service: {
        name: $.service.metadata.name,
        namespace: pa.config.namespace,
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
      namespace: pa.config.namespace,
      labels: pa.config.commonLabels,
    },
    data: { 'config.yaml': std.manifestYamlDoc(pa.config.config) },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: pa.config.name,
      namespace: pa.config.namespace,
      labels: pa.config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: pa.config.selectorLabels,
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
      name: pa.config.name,
      namespace: pa.config.namespace,
      labels: pa.config.commonLabels,
    },
    spec: {
      ports: [
        { name: 'https', targetPort: 6443, port: 443 },
      ],
      selector: pa.config.selectorLabels,
    },
  },

  deployment:
    local c = {
      name: pa.config.name,
      image: pa.config.image,
      args: [
        '--cert-dir=/var/run/serving-cert',
        '--config=/etc/adapter/config.yaml',
        '--logtostderr=true',
        '--metrics-relist-interval=1m',
        '--prometheus-url=' + pa.config.prometheusURL,
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
        name: pa.config.name,
        namespace: pa.config.namespace,
        labels: pa.config.commonLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: pa.config.selectorLabels },
        strategy: {
          rollingUpdate: {
            maxSurge: 1,
            maxUnavailable: 0,
          },
        },
        template: {
          metadata: { labels: pa.config.commonLabels },
          spec: {
            containers: [c],
            serviceAccountName: $.serviceAccount.metadata.name,
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
      name: pa.config.name,
      namespace: pa.config.namespace,
      labels: pa.config.commonLabels,
    },
  },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: pa.config.name,
      labels: pa.config.commonLabels,
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
      name: pa.config.name,
      labels: pa.config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: $.clusterRole.metadata.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: pa.config.namespace,
    }],
  },

  clusterRoleBindingDelegator: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      name: 'resource-metrics:system:auth-delegator',
      labels: pa.config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'system:auth-delegator',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: pa.config.namespace,
    }],
  },

  clusterRoleServerResources: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'resource-metrics-server-resources',
      labels: pa.config.commonLabels,
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
      } + pa.config.commonLabels,
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
      labels: pa.config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'extension-apiserver-authentication-reader',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: pa.config.namespace,
    }],
  },
}
