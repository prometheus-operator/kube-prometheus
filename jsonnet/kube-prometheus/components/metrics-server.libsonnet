local defaults = {
  local defaults = self,
  name:: 'metrics-server',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  resources:: {
    requests: { cpu: '100m', memory: '200Mi' },
  },
  replicas:: 2,
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'metrics-server',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  kubeletInsecureTLS:: false,
  priorityClassName:: 'system-cluster-critical',
  metricResolution:: '15s',
  securePort:: 10250,
  certDir:: '/tmp',
  tlsCipherSuites:: [
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
  extraArgs:: [],
  insecureSkipTLSVerify:: true,
  podAntiAffinity:: 'hard',
  podAntiAffinityTopologyKey:: 'kubernetes.io/hostname',
};

function(params) {
  local ms = self,
  _config:: defaults + params,
  assert std.isObject(ms._config.resources),

  _metadata:: {
    name: ms._config.name,
    namespace: ms._config.namespace,
    labels: ms._config.commonLabels,
  },

  _metadata_no_ns:: {
    name: ms._config.name,
    labels: ms._config.commonLabels,
  },

  local baseArgs = [
                     '--cert-dir=' + ms._config.certDir,
                     '--secure-port=%d' % ms._config.securePort,
                     '--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname',
                     '--kubelet-use-node-status-port',
                     '--metric-resolution=' + ms._config.metricResolution,
                     '--tls-cipher-suites=' + std.join(',', ms._config.tlsCipherSuites),
                   ] + (if ms._config.kubeletInsecureTLS then ['--kubelet-insecure-tls'] else [])
                   + ms._config.extraArgs,

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: ms._metadata,
    automountServiceAccountToken: false,
  },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: ms._metadata_no_ns {
      name: 'system:metrics-server',
    },
    rules: [
      {
        apiGroups: [''],
        resources: ['nodes/metrics'],
        verbs: ['get'],
      },
      {
        apiGroups: [''],
        resources: ['pods', 'nodes'],
        verbs: ['get', 'list', 'watch'],
      },
    ],
  },

  clusterRoleAggregatedMetricsReader: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: ms._metadata_no_ns {
      name: 'system:aggregated-metrics-reader',
      labels+: {
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
    metadata: ms._metadata {
      name: 'metrics-server-auth-reader',
      namespace: 'kube-system',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'extension-apiserver-authentication-reader',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: ms._config.namespace,
    }],
  },

  clusterRoleBindingDelegator: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: ms._metadata_no_ns {
      name: 'metrics-server:system:auth-delegator',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'system:auth-delegator',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: ms._config.namespace,
    }],
  },

  clusterRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: ms._metadata_no_ns {
      name: 'system:metrics-server',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: $.clusterRole.metadata.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: $.serviceAccount.metadata.name,
      namespace: ms._config.namespace,
    }],
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: ms._metadata,
    spec: {
      ports: [{
        name: 'https',
        port: 443,
        protocol: 'TCP',
        targetPort: 'https',
        appProtocol: 'https',
      }],
      selector: ms._config.selectorLabels,
    },
  },

  deployment:
    local c = {
      name: ms._config.name,
      image: ms._config.image,
      imagePullPolicy: 'IfNotPresent',
      args: baseArgs,
      resources: ms._config.resources,
      ports: [{
        containerPort: ms._config.securePort,
        name: 'https',
        protocol: 'TCP',
      }],
      livenessProbe: {
        failureThreshold: 3,
        httpGet: {
          path: '/livez',
          port: 'https',
          scheme: 'HTTPS',
        },
        periodSeconds: 10,
      },
      readinessProbe: {
        failureThreshold: 6,
        httpGet: {
          path: '/readyz',
          port: 'https',
          scheme: 'HTTPS',
        },
        initialDelaySeconds: 20,
        periodSeconds: 20,
      },
      securityContext: {
        allowPrivilegeEscalation: false,
        capabilities: { drop: ['ALL'] },
        readOnlyRootFilesystem: true,
        runAsNonRoot: true,
        runAsUser: 1000,
        seccompProfile: { type: 'RuntimeDefault' },
      },
      volumeMounts: [{
        mountPath: ms._config.certDir,
        name: 'tmp-dir',
      }],
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: ms._metadata,
      spec: {
        replicas: ms._config.replicas,
        selector: {
          matchLabels: ms._config.selectorLabels,
        },
        strategy: {
          rollingUpdate: {
            maxUnavailable: 1,
          },
        },
        template: {
          metadata: {
            labels: ms._config.commonLabels,
          },
          spec: {
            affinity: if ms._config.replicas > 1 then {
              podAntiAffinity: if ms._config.podAntiAffinity == 'hard' then {
                requiredDuringSchedulingIgnoredDuringExecution: [{
                  labelSelector: {
                    matchLabels: ms._config.selectorLabels,
                  },
                  namespaces: [ms._config.namespace],
                  topologyKey: ms._config.podAntiAffinityTopologyKey,
                }],
              } else if ms._config.podAntiAffinity == 'soft' then {
                preferredDuringSchedulingIgnoredDuringExecution: [{
                  weight: 100,
                  podAffinityTerm: {
                    labelSelector: {
                      matchLabels: ms._config.selectorLabels,
                    },
                    namespaces: [ms._config.namespace],
                    topologyKey: ms._config.podAntiAffinityTopologyKey,
                  },
                }],
              } else error 'podAntiAffinity must be either "soft" or "hard"',
            } else {},
            containers: [c],
            nodeSelector: { 'kubernetes.io/os': 'linux' },
            priorityClassName: ms._config.priorityClassName,
            serviceAccountName: $.serviceAccount.metadata.name,
            volumes: [{
              name: 'tmp-dir',
              emptyDir: {},
            }],
          },
        },
      },
    },

  [if (defaults + params).replicas > 1 then 'podDisruptionBudget']: {
    apiVersion: 'policy/v1',
    kind: 'PodDisruptionBudget',
    metadata: ms._metadata,
    spec: {
      minAvailable: 1,
      selector: {
        matchLabels: ms._config.selectorLabels,
      },
    },
  },

  apiService: {
    apiVersion: 'apiregistration.k8s.io/v1',
    kind: 'APIService',
    metadata: {
      name: 'v1beta1.metrics.k8s.io',
      labels: ms._config.commonLabels,
    },
    spec: {
      service: {
        name: $.service.metadata.name,
        namespace: ms._config.namespace,
        port: 443,
      },
      group: 'metrics.k8s.io',
      version: 'v1beta1',
      insecureSkipTLSVerify: ms._config.insecureSkipTLSVerify,
      groupPriorityMinimum: 100,
      versionPriority: 100,
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: ms._metadata,
    spec: {
      selector: {
        matchLabels: ms._config.selectorLabels,
      },
      endpoints: [{
        port: 'https',
        scheme: 'https',
        interval: '30s',
        tlsConfig: {
          insecureSkipVerify: true,
        },
        bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
      }],
    },
  },

  networkPolicy: {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'NetworkPolicy',
    metadata: ms.service.metadata,
    spec: {
      podSelector: {
        matchLabels: ms._config.selectorLabels,
      },
      policyTypes: ['Ingress', 'Egress'],
      ingress: [{
        ports: [{
          port: ms._config.securePort,
          protocol: 'TCP',
        }],
      }],
      egress: [{}],
    },
  },

}
