local krp = import './kube-rbac-proxy.libsonnet';
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
  mixin: {
    ruleLabels: {
      role: 'alert-rules',
      prometheus: defaults.name,
    },
    _config: {
      prometheusOperatorSelector: 'job="prometheus-operator",namespace="' + defaults.namespace + '"',
    },
  },
};

function(params)
  local config = defaults + params;
  // Safety check
  assert std.isObject(config.resources);

  prometheusOperator(config) {
    local po = self,
    mixin:: (import 'github.com/prometheus-operator/prometheus-operator/jsonnet/mixin/mixin.libsonnet') {
      _config+:: config.mixin._config,
    },

    prometheusRule: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        labels: config.commonLabels + config.mixin.ruleLabels,
        name: config.name + '-rules',
        namespace: config.namespace,
      },
      spec: {
        local r = if std.objectHasAll(po.mixin, 'prometheusRules') then po.mixin.prometheusRules.groups else [],
        local a = if std.objectHasAll(po.mixin, 'prometheusAlerts') then po.mixin.prometheusAlerts.groups else [],
        groups: a + r,
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

    local kubeRbacProxy = krp({
      name: 'kube-rbac-proxy',
      upstream: 'http://127.0.0.1:8080/',
      secureListenAddress: ':8443',
      ports: [
        { name: 'https', containerPort: 8443 },
      ],
    }),

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers+: [kubeRbacProxy],
          },
        },
      },
    },
  }
