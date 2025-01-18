local defaults = {
  local defaults = self,
  name:: 'metrics-server',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  resources:: {
    requests: { cpu: '100m', memory: '200Mi' },
    limits: { cpu: '200m', memory: '200Mi' },
  },
  commonLabels:: {
    'app.kubernetes.io/name': 'metrics-server',
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'metrics-api',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local ms = self,
  _config:: defaults + params,
  
  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: ms._config.name,
      namespace: ms._config.namespace,
      labels: ms._config.commonLabels,
    },
    automountServiceAccountToken: true,
  },

  clusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: ms._config.name,
      labels: ms._config.commonLabels,
    },
    rules: [{
      apiGroups: [''],
      resources: ['pods', 'nodes', 'nodes/stats', 'namespaces'],
      verbs: ['get', 'list', 'watch'],
    }],
  },

  clusterRoleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding', 
    metadata: {
      name: ms._config.name,
      labels: ms._config.commonLabels,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: ms._config.name,
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: ms._config.name,
      namespace: ms._config.namespace,
    }],
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: ms._config.name,
      namespace: ms._config.namespace,
      labels: ms._config.commonLabels,
    },
    spec: {
      ports: [{
        name: 'https',
        port: 443,
        targetPort: 4443,
      }],
      selector: ms._config.selectorLabels,
    },
  },

  deployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: ms._config.name,
      namespace: ms._config.namespace,
      labels: ms._config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: ms._config.selectorLabels,
      },
      template: {
        metadata: {
          labels: ms._config.commonLabels,
        },
        spec: {
          containers: [{
            name: 'metrics-server',
            image: ms._config.image,
            args: [
              '--cert-dir=/tmp',
              '--secure-port=4443',
              '--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname',
              '--kubelet-use-node-status-port',
              '--metric-resolution=15s',
            ],
            ports: [{
              name: 'https',
              containerPort: 4443,
              protocol: 'TCP',
            }],
            resources: ms._config.resources,
            securityContext: {
              allowPrivilegeEscalation: false,
              readOnlyRootFilesystem: true,
              runAsNonRoot: true,
              runAsUser: 1000,
            },
          }],
          nodeSelector: { 'kubernetes.io/os': 'linux' },
          serviceAccountName: ms._config.name,
          priorityClassName: 'system-cluster-critical',
        },
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
        name: ms._config.name,
        namespace: ms._config.namespace,
      },
      group: 'metrics.k8s.io',
      version: 'v1beta1',
      insecureSkipTLSVerify: true,
      groupPriorityMinimum: 100,
      versionPriority: 100,
    },
  },
}