local krp = import './kube-rbac-proxy.libsonnet';

local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  name:: 'kube-state-metrics',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  kubeRbacProxyImage:: error 'must provide kubeRbacProxyImage',
  resources:: {
    requests: { cpu: '10m', memory: '190Mi' },
    limits: { cpu: '100m', memory: '250Mi' },
  },

  kubeRbacProxyMain:: {
    ports: [
      { name: 'http-metrics', containerPort: 8443 },
    ],
    resources+: {
      limits+: { cpu: '40m' },
      requests+: { cpu: '20m' },
    },
  },
  kubeRbacProxySelf:: {
    ports: [
      { name: 'telemetry', containerPort: 9443 },
    ],
    resources+: {
      limits+: { cpu: '20m' },
      requests+: { cpu: '10m' },
    },
  },
  scrapeInterval:: '30s',
  scrapeTimeout:: '30s',
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'exporter',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  mixin:: {
    ruleLabels: {},
    _config: {
      kubeStateMetricsSelector: 'job="' + defaults.name + '"',
      runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/kube-state-metrics/%s',
    },
  },
  // `enableProbes` allows users to opt-into upstream definitions for health probes.
  enableProbes:: false,
};

function(params) (import 'github.com/kubernetes/kube-state-metrics/jsonnet/kube-state-metrics/kube-state-metrics.libsonnet') {
  local ksm = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(ksm._config.resources),
  assert std.isObject(ksm._config.mixin._config),

  name:: ksm._config.name,
  namespace:: ksm._config.namespace,
  version:: ksm._config.version,
  image:: ksm._config.image,
  commonLabels:: ksm._config.commonLabels,
  podLabels:: ksm._config.selectorLabels,

  _metadata:: {
    labels: ksm._config.commonLabels,
    name: ksm._config.name,
    namespace: ksm._config.namespace,
  },

  mixin:: (import 'github.com/kubernetes/kube-state-metrics/jsonnet/kube-state-metrics-mixin/mixin.libsonnet') +
          (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') {
            _config+:: ksm._config.mixin._config,
          },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: ksm._metadata {
      labels+: ksm._config.mixin.ruleLabels,
      name: ksm._config.name + '-rules',
    },
    spec: {
      local r = if std.objectHasAll(ksm.mixin, 'prometheusRules') then ksm.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(ksm.mixin, 'prometheusAlerts') then ksm.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },

  service+: {
    spec+: {
      ports: [
        {
          name: defaults.kubeRbacProxyMain.ports[0].name,
          port: defaults.kubeRbacProxyMain.ports[0].containerPort,
          targetPort: defaults.kubeRbacProxyMain.ports[0].name,
        },
        {
          name: defaults.kubeRbacProxySelf.ports[0].name,
          port: defaults.kubeRbacProxySelf.ports[0].containerPort,
          targetPort: defaults.kubeRbacProxySelf.ports[0].name,
        },
      ],
    },
  },

  local kubeRbacProxyMain = krp(ksm._config.kubeRbacProxyMain {
    name: 'kube-rbac-proxy-main',
    upstream: 'http://127.0.0.1:8081/',
    secureListenAddress: ':' + std.toString(defaults.kubeRbacProxyMain.ports[0].containerPort),
    image: ksm._config.kubeRbacProxyImage,
    // When enabling probes, kube-rbac-proxy needs to always allow the /livez endpoint.
    ignorePaths: if ksm._config.enableProbes then ['/livez'] else super.ignorePaths,
  }),

  local kubeRbacProxySelf = krp(ksm._config.kubeRbacProxySelf {
    name: 'kube-rbac-proxy-self',
    upstream: 'http://127.0.0.1:8082/',
    secureListenAddress: ':' + std.toString(defaults.kubeRbacProxySelf.ports[0].containerPort),
    image: ksm._config.kubeRbacProxyImage,
    // When enabling probes, kube-rbac-proxy needs to always allow the /readyz endpoint.
    ignorePaths: if ksm._config.enableProbes then ['/readyz'] else super.ignorePaths,
  }),

  networkPolicy: {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'NetworkPolicy',
    metadata: ksm.service.metadata,
    spec: {
      podSelector: {
        matchLabels: ksm._config.selectorLabels,
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
        }, ksm.service.spec.ports),
      }],
    },
  },

  deployment+: {
    spec+: {
      template+: {
        metadata+: {
          annotations+: {
            'kubectl.kubernetes.io/default-container': 'kube-state-metrics',
          },
        },
        spec+: {
          automountServiceAccountToken: true,
          containers: std.map(function(c) c {
            securityContext+: {
              runAsGroup: 65534,
            },
            args: ['--host=127.0.0.1', '--port=8081', '--telemetry-host=127.0.0.1', '--telemetry-port=8082'],
            resources: ksm._config.resources,
          } + if !ksm._config.enableProbes then {
            ports:: null,
            livenessProbe:: null,
            readinessProbe:: null,
          } else {
            ports: defaults.kubeRbacProxyMain.ports + defaults.kubeRbacProxySelf.ports,
            livenessProbe: {
              httpGet: {
                path: '/livez',
                port: defaults.kubeRbacProxyMain.ports[0].name,
                scheme: 'HTTPS',
              },
            },
            readinessProbe: {
              httpGet: {
                path: '/readyz',
                port: defaults.kubeRbacProxySelf.ports[0].name,
                scheme: 'HTTPS',
              },
            },
          }, super.containers) + [kubeRbacProxyMain, kubeRbacProxySelf],
        },
      },
    },
  },
  serviceMonitor:
    {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: ksm._metadata,
      spec: {
        jobLabel: 'app.kubernetes.io/name',
        selector: {
          matchLabels: ksm._config.selectorLabels,
        },
        endpoints: [
          {
            port: 'http-metrics',
            scheme: 'https',
            interval: ksm._config.scrapeInterval,
            scrapeTimeout: ksm._config.scrapeTimeout,
            honorLabels: true,
            bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
            relabelings: [
              {
                regex: '(pod|service|endpoint|namespace)',
                action: 'labeldrop',
              },
            ],
            metricRelabelings: [
              {
                // Dropping metric deprecated from kube-state-metrics 2.6.0 & 2.14.0 versions
                sourceLabels: ['__name__'],
                regex: 'kube_(endpoint_(address_not_ready|address_available|ports))',
                action: 'drop',
              },
            ],
            tlsConfig: {
              insecureSkipVerify: true,
            },
          },
          {
            port: 'telemetry',
            scheme: 'https',
            interval: ksm._config.scrapeInterval,
            bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
            tlsConfig: {
              insecureSkipVerify: true,
            },
          },
        ],
      },
    },
}
