local krp = import './kube-rbac-proxy.libsonnet';

local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide version',
  resources:: {
    requests: { cpu: '10m', memory: '20Mi' },
    limits: { cpu: '20m', memory: '40Mi' },
  },
  kubeRbacProxy:: {
    resources+: {
      requests: { cpu: '10m', memory: '20Mi' },
      limits: { cpu: '20m', memory: '40Mi' },
    },
  },
  commonLabels:: {
    'app.kubernetes.io/name': 'blackbox-exporter',
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'exporter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  configmapReloaderImage:: error 'must provide version',
  kubeRbacProxyImage:: error 'must provide kubeRbacProxyImage',

  port:: 9115,
  internalPort:: 19115,
  replicas:: 1,
  modules:: {
    http_2xx: {
      prober: 'http',
      http: {
        preferred_ip_protocol: 'ip4',
      },
    },
    http_post_2xx: {
      prober: 'http',
      http: {
        method: 'POST',
        preferred_ip_protocol: 'ip4',
      },
    },
    tcp_connect: {
      prober: 'tcp',
      tcp: {
        preferred_ip_protocol: 'ip4',
      },
    },
    pop3s_banner: {
      prober: 'tcp',
      tcp: {
        query_response: [
          { expect: '^+OK' },
        ],
        tls: true,
        tls_config: {
          insecure_skip_verify: false,
        },
        preferred_ip_protocol: 'ip4',
      },
    },
    ssh_banner: {
      prober: 'tcp',
      tcp: {
        query_response: [
          { expect: '^SSH-2.0-' },
        ],
        preferred_ip_protocol: 'ip4',
      },
    },
    irc_banner: {
      prober: 'tcp',
      tcp: {
        query_response: [
          { send: 'NICK prober' },
          { send: 'USER prober prober prober :prober' },
          { expect: 'PING :([^ ]+)', send: 'PONG ${1}' },
          { expect: '^:[^ ]+ 001' },
        ],
        preferred_ip_protocol: 'ip4',
      },
    },
  },
  privileged::
    local icmpModules = [self.modules[m] for m in std.objectFields(self.modules) if self.modules[m].prober == 'icmp'];
    std.length(icmpModules) > 0,
};


function(params) {
  local bb = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(bb._config.resources),
  _metadata:: {
    name: 'blackbox-exporter',
    namespace: bb._config.namespace,
    labels: bb._config.commonLabels,
  },

  configuration: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: bb._metadata {
      name: 'blackbox-exporter-configuration',
    },
    data: {
      'config.yml': std.manifestYamlDoc({ modules: bb._config.modules }),
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: bb._metadata,
    automountServiceAccountToken: false,
  },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'blackbox-exporter',
    },
    rules: [
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

  clusterRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      name: 'blackbox-exporter',
      labels: bb._config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'blackbox-exporter',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: 'blackbox-exporter',
      namespace: bb._config.namespace,
    }],
  },

  deployment:
    local blackboxExporter = {
      name: 'blackbox-exporter',
      image: bb._config.image,
      args: [
        '--config.file=/etc/blackbox_exporter/config.yml',
        '--web.listen-address=:%d' % bb._config.internalPort,
      ],
      ports: [{
        name: 'http',
        containerPort: bb._config.internalPort,
      }],
      resources: bb._config.resources,
      securityContext: if bb._config.privileged then {
        runAsNonRoot: false,
        capabilities: { drop: ['ALL'], add: ['NET_RAW'] },
        readOnlyRootFilesystem: true,
      } else {
        runAsNonRoot: true,
        runAsUser: 65534,
        allowPrivilegeEscalation: false,
        readOnlyRootFilesystem: true,
        capabilities: { drop: ['ALL'] },
      },
      volumeMounts: [{
        mountPath: '/etc/blackbox_exporter/',
        name: 'config',
        readOnly: true,
      }],
    };

    local reloader = {
      name: 'module-configmap-reloader',
      image: bb._config.configmapReloaderImage,
      args: [
        '--webhook-url=http://localhost:%d/-/reload' % bb._config.internalPort,
        '--volume-dir=/etc/blackbox_exporter/',
      ],
      resources: bb._config.resources,
      securityContext: {
        runAsNonRoot: true,
        runAsUser: 65534,
        allowPrivilegeEscalation: false,
        readOnlyRootFilesystem: true,
        capabilities: { drop: ['ALL'] },
      },
      terminationMessagePath: '/dev/termination-log',
      terminationMessagePolicy: 'FallbackToLogsOnError',
      volumeMounts: [{
        mountPath: '/etc/blackbox_exporter/',
        name: 'config',
        readOnly: true,
      }],
    };

    local kubeRbacProxy = krp(bb._config.kubeRbacProxy {
      name: 'kube-rbac-proxy',
      upstream: 'http://127.0.0.1:' + bb._config.internalPort + '/',
      resources: bb._config.resources,
      secureListenAddress: ':' + bb._config.port,
      ports: [
        { name: 'https', containerPort: bb._config.port },
      ],
      image: bb._config.kubeRbacProxyImage,
    });

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: bb._metadata,
      spec: {
        replicas: bb._config.replicas,
        selector: {
          matchLabels: bb._config.selectorLabels,
        },
        template: {
          metadata: {
            labels: bb._config.commonLabels,
            annotations: {
              'kubectl.kubernetes.io/default-container': blackboxExporter.name,
            },
          },
          spec: {
            containers: [blackboxExporter, reloader, kubeRbacProxy],
            nodeSelector: { 'kubernetes.io/os': 'linux' },
            automountServiceAccountToken: true,
            serviceAccountName: 'blackbox-exporter',
            volumes: [{
              name: 'config',
              configMap: { name: 'blackbox-exporter-configuration' },
            }],
          },
        },
      },
    },

  networkPolicy: {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'NetworkPolicy',
    metadata: bb.service.metadata,
    spec: {
      podSelector: {
        matchLabels: bb._config.selectorLabels,
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
        ports: std.map(function(o) {
          port: o.port,
          protocol: 'TCP',
        }, bb.service.spec.ports),
      }],
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: bb._metadata,
    spec: {
      ports: [{
        name: 'https',
        port: bb._config.port,
        targetPort: 'https',
      }, {
        name: 'probe',
        port: bb._config.internalPort,
        targetPort: 'http',
      }],
      selector: bb._config.selectorLabels,
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: bb._metadata,
    spec: {
      endpoints: [{
        bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
        interval: '30s',
        path: '/metrics',
        port: 'https',
        scheme: 'https',
        tlsConfig: {
          insecureSkipVerify: true,
        },
      }],
      selector: {
        matchLabels: bb._config.selectorLabels,
      },
    },
  },
}
