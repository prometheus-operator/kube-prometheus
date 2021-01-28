local krp = import './kube-rbac-proxy.libsonnet';

local defaults = {
  local defaults = self,
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide version',
  resources: {
    requests: { cpu: '10m', memory: '20Mi' },
    limits: { cpu: '20m', memory: '40Mi' },
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
  configmapReloaderImage: 'jimmidyson/configmap-reload:v0.5.0',

  port: 9115,
  internalPort: 19115,
  replicas: 1,
  modules: {
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
  privileged:
    local icmpModules = [self.modules[m] for m in std.objectFields(self.modules) if self.modules[m].prober == 'icmp'];
    std.length(icmpModules) > 0,
};


function(params) {
  local bb = self,
  config:: defaults + params,
  // Safety check
  assert std.isObject(bb.config.resources),

  configuration: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'blackbox-exporter-configuration',
      namespace: bb.config.namespace,
      labels: bb.config.commonLabels,
    },
    data: {
      'config.yml': std.manifestYamlDoc({ modules: bb.config.modules }),
    },
  },

  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: 'blackbox-exporter',
      namespace: bb.config.namespace,
    },
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
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'blackbox-exporter',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: 'blackbox-exporter',
      namespace: bb.config.namespace,
    }],
  },

  deployment:
    local blackboxExporter = {
      name: 'blackbox-exporter',
      image: bb.config.image,
      args: [
        '--config.file=/etc/blackbox_exporter/config.yml',
        '--web.listen-address=:%d' % bb.config.internalPort,
      ],
      ports: [{
        name: 'http',
        containerPort: bb.config.internalPort,
      }],
      resources: bb.config.resources,
      securityContext: if bb.config.privileged then {
        runAsNonRoot: false,
        capabilities: { drop: ['ALL'], add: ['NET_RAW'] },
      } else {
        runAsNonRoot: true,
        runAsUser: 65534,
      },
      volumeMounts: [{
        mountPath: '/etc/blackbox_exporter/',
        name: 'config',
        readOnly: true,
      }],
    };

    local reloader = {
      name: 'module-configmap-reloader',
      image: bb.config.configmapReloaderImage,
      args: [
        '--webhook-url=http://localhost:%d/-/reload' % bb.config.internalPort,
        '--volume-dir=/etc/blackbox_exporter/',
      ],
      resources: bb.config.resources,
      securityContext: { runAsNonRoot: true, runAsUser: 65534 },
      terminationMessagePath: '/dev/termination-log',
      terminationMessagePolicy: 'FallbackToLogsOnError',
      volumeMounts: [{
        mountPath: '/etc/blackbox_exporter/',
        name: 'config',
        readOnly: true,
      }],
    };

    local kubeRbacProxy = krp({
      name: 'kube-rbac-proxy',
      upstream: 'http://127.0.0.1:' + bb.config.internalPort + '/',
      secureListenAddress: ':' + bb.config.port,
      ports: [
        { name: 'https', containerPort: bb.config.port },
      ],
    });

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'blackbox-exporter',
        namespace: bb.config.namespace,
        labels: bb.config.commonLabels,
      },
      spec: {
        replicas: bb.config.replicas,
        selector: { matchLabels: bb.config.selectorLabels },
        template: {
          metadata: { labels: bb.config.commonLabels },
          spec: {
            containers: [blackboxExporter, reloader, kubeRbacProxy],
            nodeSelector: { 'kubernetes.io/os': 'linux' },
            serviceAccountName: 'blackbox-exporter',
            volumes: [{
              name: 'config',
              configMap: { name: 'blackbox-exporter-configuration' },
            }],
          },
        },
      },
    },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'blackbox-exporter',
      namespace: bb.config.namespace,
      labels: bb.config.commonLabels,
    },
    spec: {
      ports: [{
        name: 'https',
        port: bb.config.port,
        targetPort: 'https',
      }, {
        name: 'probe',
        port: bb.config.internalPort,
        targetPort: 'http',
      }],
      selector: bb.config.selectorLabels,
    },
  },

  serviceMonitor:
    {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'blackbox-exporter',
        namespace: bb.config.namespace,
        labels: bb.config.commonLabels,
      },
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
          matchLabels: bb.config.selectorLabels,
        },
      },
    },
}
