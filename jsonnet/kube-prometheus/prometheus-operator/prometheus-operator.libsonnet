local krp = (import '../kube-rbac-proxy/container.libsonnet');
local prometheusOperator = import 'github.com/prometheus-operator/prometheus-operator/jsonnet/prometheus-operator/prometheus-operator.libsonnet';

local defaults = {
  local defaults = self,
  name: 'prometheus-operator',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  configReloaderImage: error 'must provide config reloader image',
  resources: {
    limits: { cpu: '200m', memory: '200Mi' },
    requests: { cpu: '100m', memory: '100Mi' },
  },
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'controller',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) {
  local po = self,
  config:: defaults + params,
  // Safety check
  assert std.isObject(po.config.resources),

  //TODO(paulfantom): it would be better to include it on the same level as self.
  local polib = prometheusOperator(po.config),

  '0alertmanagerConfigCustomResourceDefinition': polib['0alertmanagerConfigCustomResourceDefinition'],
  '0alertmanagerCustomResourceDefinition': polib['0alertmanagerCustomResourceDefinition'],
  '0podmonitorCustomResourceDefinition': polib['0podmonitorCustomResourceDefinition'],
  '0probeCustomResourceDefinition': polib['0probeCustomResourceDefinition'],
  '0prometheusCustomResourceDefinition': polib['0prometheusCustomResourceDefinition'],
  '0prometheusruleCustomResourceDefinition': polib['0prometheusruleCustomResourceDefinition'],
  '0servicemonitorCustomResourceDefinition': polib['0servicemonitorCustomResourceDefinition'],
  '0thanosrulerCustomResourceDefinition': polib['0thanosrulerCustomResourceDefinition'],

  serviceAccount: polib.serviceAccount,
  service: polib.service {
    spec+: {
      ports: [
        {
          name: 'https',
          port: 8443,
          targetPort: 'https',
        },
      ],
    },
  },

  serviceMonitor: polib.serviceMonitor {
    spec+: {
      endpoints: [
        {
          port: 'https',
          scheme: 'https',
          honorLabels: true,
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          tlsConfig: {
            insecureSkipVerify: true,
          },
        },
      ],
    },
  },

  clusterRoleBinding: polib.clusterRoleBinding,
  clusterRole: polib.clusterRole {
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

  local kubeRbacProxy = krp({
    name: 'kube-rbac-proxy',
    upstream: 'http://127.0.0.1:8080/',
    secureListenAddress: ':8443',
    ports: [
      { name: 'https', containerPort: 8443 },
    ],
  }),

  deployment: polib.deployment {
    spec+: {
      template+: {
        spec+: {
          containers+: [kubeRbacProxy],
        },
      },
    },
  },
}
