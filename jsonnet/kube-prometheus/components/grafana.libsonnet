local kubernetesGrafana = import 'github.com/brancz/kubernetes-grafana/grafana/grafana.libsonnet';

local defaults = {
  local defaults = self,
  // Convention: Top-level fields related to CRDs are public, other fields are hidden
  // If there is no CRD for the component, everything is hidden in defaults.
  name:: 'grafana',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  resources:: {
    requests: { cpu: '100m', memory: '100Mi' },
    limits: { cpu: '200m', memory: '200Mi' },
  },
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'grafana',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  prometheusName:: error 'must provide prometheus name',
  mixin: {
    ruleLabels: {},
    _config: {
      runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/grafana/%s',
    },
  },
};

function(params)
  local config = defaults + params;
  // Safety check
  assert std.isObject(config.resources);

  kubernetesGrafana(config) {
    local g = self,
    _config+:: config,
    _metadata:: {
      name: 'grafana',
      namespace: g._config.namespace,
      labels: g._config.commonLabels,
    },

    mixin::
      (import 'github.com/grafana/grafana/grafana-mixin/mixin.libsonnet') +
      (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') + {
        _config+:: g._config.mixin._config,
      },

    prometheusRule: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        labels: g._config.commonLabels + g._config.mixin.ruleLabels,
        name: g._config.name + '-rules',
        namespace: g._config.namespace,
      },
      spec: {
        local r = if std.objectHasAll(g.mixin, 'prometheusRules') then g.mixin.prometheusRules.groups else [],
        local a = if std.objectHasAll(g.mixin, 'prometheusAlerts') then g.mixin.prometheusAlerts.groups else [],
        groups: a + r,
      },
    },

    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: g._metadata,
      spec: {
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'grafana',
          },
        },
        endpoints: [{
          port: 'http',
          interval: '15s',
        }],
      },
    },

    networkPolicy: {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'NetworkPolicy',
      metadata: g.service.metadata,
      spec: {
        podSelector: {
          matchLabels: g._config.selectorLabels,
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
          }, g.service.spec.ports),
        }],
      },
    },

    // FIXME(paulfantom): `automountServiceAccountToken` can be removed after porting to brancz/kuberentes-grafana
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            automountServiceAccountToken: false,
            securityContext+: {
              runAsGroup: 65534,
            },
          },
        },
      },
    },
  }
