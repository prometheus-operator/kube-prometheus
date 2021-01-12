local krp = (import '../kube-rbac-proxy/container.libsonnet');

local defaults = {
  local defaults = self,
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide version',
  resources: {
    requests: { cpu: '10m', memory: '190Mi' },
    limits: { cpu: '100m', memory: '250Mi' },
  },

  scrapeInterval: '30s',
  scrapeTimeout: '30s',
  commonLabels:: {
    'app.kubernetes.io/name': 'kube-state-metrics',
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'exporter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params) (import 'github.com/kubernetes/kube-state-metrics/jsonnet/kube-state-metrics/kube-state-metrics.libsonnet') {
  local ksm = self,
  config:: defaults + params,
  // Safety check
  assert std.isObject(ksm.config.resources),

  name:: 'kube-state-metrics',
  namespace:: ksm.config.namespace,
  version:: ksm.config.version,
  image:: ksm.config.image,
  commonLabels:: ksm.config.commonLabels,
  podLabels:: ksm.config.selectorLabels,

  service+: {
    spec+: {
      ports: [
        {
          name: 'https-main',
          port: 8443,
          targetPort: 'https-main',
        },
        {
          name: 'https-self',
          port: 9443,
          targetPort: 'https-self',
        },
      ],
    },
  },

  local kubeRbacProxyMain = krp({
    name: 'kube-rbac-proxy-main',
    upstream: 'http://127.0.0.1:8081/',
    secureListenAddress: ':8443',
    ports: [
      { name: 'https-main', containerPort: 8443 },
    ],
  }),

  local kubeRbacProxySelf = krp({
    name: 'kube-rbac-proxy-self',
    upstream: 'http://127.0.0.1:8082/',
    secureListenAddress: ':9443',
    ports: [
      { name: 'https-self', containerPort: 9443 },
    ],
  }),

  deployment+: {
    spec+: {
      template+: {
        spec+: {
          containers: std.map(function(c) c {
            ports:: null,
            livenessProbe:: null,
            readinessProbe:: null,
            args: ['--host=127.0.0.1', '--port=8081', '--telemetry-host=127.0.0.1', '--telemetry-port=8082'],
            resources: ksm.config.resources,
          }, super.containers) + [kubeRbacProxyMain, kubeRbacProxySelf],
        },
      },
    },
  },
  serviceMonitor:
    {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: ksm.name,
        namespace: ksm.config.namespace,
        labels: ksm.config.commonLabels,
      },
      spec: {
        jobLabel: 'app.kubernetes.io/name',
        selector: { matchLabels: ksm.config.selectorLabels },
        endpoints: [
          {
            port: 'https-main',
            scheme: 'https',
            interval: ksm.config.scrapeInterval,
            scrapeTimeout: ksm.config.scrapeTimeout,
            honorLabels: true,
            bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
            relabelings: [
              {
                regex: '(pod|service|endpoint|namespace)',
                action: 'labeldrop',
              },
            ],
            tlsConfig: {
              insecureSkipVerify: true,
            },
          },
          {
            port: 'https-self',
            scheme: 'https',
            interval: ksm.config.scrapeInterval,
            bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
            tlsConfig: {
              insecureSkipVerify: true,
            },
          },
        ],
      },
    },
}
