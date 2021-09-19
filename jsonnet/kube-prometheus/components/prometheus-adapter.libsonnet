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
  replicas: 2,
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
  // Default range intervals are equal to 4 times the default scrape interval.
  // This is done in order to follow Prometheus rule of thumb with irate().
  rangeIntervals: {
    kubelet: '4m',
    nodeExporter: '4m',
    windowsExporter: '4m',
  },

  prometheusURL: error 'must provide prometheusURL',
  config: {
    resourceRules: {
      cpu: {
        containerQuery: |||
          sum by (<<.GroupBy>>) (
            irate (
                container_cpu_usage_seconds_total{<<.LabelMatchers>>,container!="",pod!=""}[%(kubelet)s]
            )
          )
        ||| % $.rangeIntervals,
        nodeQuery: |||
          sum by (<<.GroupBy>>) (
            1 - irate(
              node_cpu_seconds_total{mode="idle"}[%(nodeExporter)s]
            )
            * on(namespace, pod) group_left(node) (
              node_namespace_pod:kube_pod_info:{<<.LabelMatchers>>}
            )
          )
          or sum by (<<.GroupBy>>) (
            1 - irate(
              windows_cpu_time_total{mode="idle", job="windows-exporter",<<.LabelMatchers>>}[%(windowsExporter)s]
            )
          )
        ||| % $.rangeIntervals,
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
        containerQuery: |||
          sum by (<<.GroupBy>>) (
            container_memory_working_set_bytes{<<.LabelMatchers>>,container!="",pod!=""}
          )
        |||,
        nodeQuery: |||
          sum by (<<.GroupBy>>) (
            node_memory_MemTotal_bytes{job="node-exporter",<<.LabelMatchers>>}
            -
            node_memory_MemAvailable_bytes{job="node-exporter",<<.LabelMatchers>>}
          )
          or sum by (<<.GroupBy>>) (
            windows_cs_physical_memory_bytes{job="windows-exporter",<<.LabelMatchers>>}
            -
            windows_memory_available_bytes{job="windows-exporter",<<.LabelMatchers>>}
          )
        |||,
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
  tlsCipherSuites: [
    'TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305',
    'TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305',
    'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
    'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
    'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256',
    'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384',
    'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA',
    'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256',
    'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA',
    'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA',
    'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA',
    'TLS_RSA_WITH_AES_128_GCM_SHA256',
    'TLS_RSA_WITH_AES_256_GCM_SHA384',
    'TLS_RSA_WITH_AES_128_CBC_SHA',
    'TLS_RSA_WITH_AES_256_CBC_SHA',
  ],
};

function(params) {
  local pa = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(pa._config.resources),

  apiService: {
    apiVersion: 'apiregistration.k8s.io/v1',
    kind: 'APIService',
    metadata: {
      name: 'v1beta1.metrics.k8s.io',
      labels: pa._config.commonLabels,
    },
    spec: {
      service: {
        name: $.service.metadata.name,
        namespace: pa._config.namespace,
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
      namespace: pa._config.namespace,
      labels: pa._config.commonLabels,
    },
    data: { 'config.yaml': std.manifestYamlDoc(pa._config.config) },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: pa._config.name,
      namespace: pa._config.namespace,
      labels: pa._config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: pa._config.selectorLabels,
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
      name: pa._config.name,
      namespace: pa._config.namespace,
      labels: pa._config.commonLabels,
    },
    spec: {
      ports: [
        { name: 'https', targetPort: 6443, port: 443 },
      ],
      selector: pa._config.selectorLabels,
    },
  },

  deployment:
    local c = {
      name: pa._config.name,
      image: pa._config.image,
      args: [
        '--cert-dir=/var/run/serving-cert',
        '--config=/etc/adapter/config.yaml',
        '--logtostderr=true',
        '--metrics-relist-interval=1m',
        '--prometheus-url=' + pa._config.prometheusURL,
        '--secure-port=6443',
        '--tls-cipher-suites=' + std.join(',', pa._config.tlsCipherSuites),
      ],
      resources: pa._config.resources,
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
        name: pa._config.name,
        namespace: pa._config.namespace,
        labels: pa._config.commonLabels,
      },
      spec: {
        replicas: pa._config.replicas,
        selector: { matchLabels: pa._config.selectorLabels },
        strategy: {
          rollingUpdate: {
            maxSurge: 1,
            maxUnavailable: 1,
          },
        },
        template: {
          metadata: { labels: pa._config.commonLabels },
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
      name: pa._config.name,
      namespace: pa._config.namespace,
      labels: pa._config.commonLabels,
    },
  },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: pa._config.name,
      labels: pa._config.commonLabels,
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
      name: pa._config.name,
      labels: pa._config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: $.clusterRole.metadata.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: pa._config.namespace,
    }],
  },

  clusterRoleBindingDelegator: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      name: 'resource-metrics:system:auth-delegator',
      labels: pa._config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'system:auth-delegator',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: pa._config.namespace,
    }],
  },

  clusterRoleServerResources: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'resource-metrics-server-resources',
      labels: pa._config.commonLabels,
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
      } + pa._config.commonLabels,
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
      labels: pa._config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'extension-apiserver-authentication-reader',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: pa._config.namespace,
    }],
  },

  [if (defaults + params).replicas > 1 then 'podDisruptionBudget']: {
    apiVersion: 'policy/v1beta1',
    kind: 'PodDisruptionBudget',
    metadata: {
      name: pa._config.name,
      namespace: pa._config.namespace,
      labels: pa._config.commonLabels,
    },
    spec: {
      minAvailable: 1,
      selector: {
        matchLabels: pa._config.selectorLabels,
      },
    },
  },
}
