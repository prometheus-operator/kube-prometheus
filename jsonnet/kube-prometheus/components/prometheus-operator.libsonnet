local krp = import './kube-rbac-proxy.libsonnet';
local prometheusOperator = import 'github.com/prometheus-operator/prometheus-operator/jsonnet/prometheus-operator/prometheus-operator.libsonnet';

local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  name:: 'prometheus-operator',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  kubeRbacProxyImage:: error 'must provide kubeRbacProxyImage',
  configReloaderImage:: error 'must provide config reloader image',
  resources:: {
    limits: { cpu: '200m', memory: '200Mi' },
    requests: { cpu: '100m', memory: '100Mi' },
  },
  kubeRbacProxy:: {
    resources+: {
      requests: { cpu: '10m', memory: '20Mi' },
      limits: { cpu: '20m', memory: '40Mi' },
    },
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
  mixin:: {
    ruleLabels: {
      role: 'alert-rules',
      prometheus: defaults.name,
    },
    _config: {
      groupLabels: 'cluster,controller,namespace',
      prometheusOperatorSelector: 'job="prometheus-operator",namespace="' + defaults.namespace + '"',
      runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/prometheus-operator/%s',
    },
  },
};

function(params)
  local config = defaults + params;
  // Safety check
  assert std.isObject(config.resources);

  prometheusOperator(config) {
    local po = self,
    // declare variable as a field to allow overriding options and to have unified API across all components
    _config:: config,
    _metadata:: {
      labels: po._config.commonLabels,
      name: po._config.name,
      namespace: po._config.namespace,
    },
    mixin:: (import 'github.com/prometheus-operator/prometheus-operator/jsonnet/mixin/mixin.libsonnet') +
            (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') {
              _config+:: po._config.mixin._config,
            },

    prometheusRule: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        labels: po._config.commonLabels + po._config.mixin.ruleLabels,
        name: po._config.name + '-rules',
        namespace: po._config.namespace,
      },
      spec: {
        local r = if std.objectHasAll(po.mixin, 'prometheusRules') then po.mixin.prometheusRules.groups else [],
        local a = if std.objectHasAll(po.mixin, 'prometheusAlerts') then po.mixin.prometheusAlerts.groups else [],
        groups: a + r,
      },
    },

    networkPolicy: {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'NetworkPolicy',
      metadata: po.service.metadata,
      spec: {
        podSelector: {
          matchLabels: po._config.selectorLabels,
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
          }, po.service.spec.ports),
        }],
      },
    },

    service+: {
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

    serviceMonitor+: {
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

    clusterRole+: {
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

    local kubeRbacProxy = krp(po._config.kubeRbacProxy {
      name: 'kube-rbac-proxy',
      upstream: 'http://127.0.0.1:8080/',
      secureListenAddress: ':8443',
      ports: [
        { name: 'https', containerPort: 8443 },
      ],
      image: po._config.kubeRbacProxyImage,
    }),

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            automountServiceAccountToken: true,
            containers+: [kubeRbacProxy],
          },
        },
      },
    },
  }
