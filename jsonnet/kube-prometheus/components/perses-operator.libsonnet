local persesOperator = import 'github.com/perses/perses-operator/jsonnet/perses-operator.libsonnet';
local communityDashboards = import 'github.com/saswatamcode/community-dashboards/jsonnet/dashboards.libsonnet';

local defaults = {
  local defaults = self,
  name:: 'perses-operator',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  persesImage:: error 'must provide perses image',
  prometheusName:: error 'must provide prometheus name',
  components:: error 'must provide components',
  resources:: {
    requests: { cpu: '100m', memory: '100Mi' },
    limits: { cpu: '200m', memory: '200Mi' },
  },
  commonLabels:: {
    'app.kubernetes.io/name': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'perses-operator',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
};

function(params)
  local config = defaults + params;
  // Safety check
  assert std.isObject(config.resources);
  assert std.isArray(config.components);

  local po = persesOperator(config);
  local cd = communityDashboards(config {
    datasource: 'prometheus-' + config.prometheusName + '-datasource',
  });

  po {
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
  } + {
    [dashboard.metadata.name]: dashboard
    for dashboard in cd.dashboards
  } + {
    datasource: {
      apiVersion: 'perses.dev/v1alpha1',
      kind: 'PersesDatasource',
      metadata: {
        name: 'prometheus-' + config.prometheusName + '-datasource',
        labels: config.commonLabels {
          'app.kubernetes.io/instance': 'perses-datasource',
        },
        namespace: config.namespace,
      },
      spec: {
        config: {
          default: true,
          display: {
            name: 'Prometheus ' + config.prometheusName + ' Datasource',
          },
          plugin: {
            kind: 'PrometheusDatasource',
            spec: {
              proxy: {
                kind: 'HTTPProxy',
                spec: {
                  url: 'http://prometheus-' + config.prometheusName + '.' + config.namespace + '.svc:9090',
                },
              },
            },
          },
        },
      },
    },
  } + {
    perses: {
      apiVersion: 'perses.dev/v1alpha1',
      kind: 'Perses',
      metadata: {
        finalizers: ['perses.dev/finalizer'],
        labels: config.commonLabels {
          'app.kubernetes.io/instance': 'perses-' + config.prometheusName,
        },
        name: 'perses-' + config.prometheusName,
        namespace: config.namespace,
      },
      spec: {
        image: config.persesImage,
        config: {
          database: {
            file: {
              extension: 'yaml',
              folder: '/perses',
              case_sensitive: false,
            },
          },
          ephemeral_dashboard: {
            cleanup_interval: '1s',
            enable: true,
          },
          frontend: {
            disable: false,
            explorer: {
              enable: true,
            },
            time_range: {
              disable_custom: false,
            },
          },
          security: {
            authentication: {
              disable_sign_up: false,
              providers: {
                enable_native: false,
              },
            },
            cookie: {
              secure: false,
            },
            enable_auth: false,
            readonly: false,
          },
        },
        containerPort: 8080,
        livenessProbe: {
          failureThreshold: 5,
          initialDelaySeconds: 10,
          periodSeconds: 10,
          successThreshold: 1,
          timeoutSeconds: 5,
        },
        readinessProbe: {
          failureThreshold: 5,
          initialDelaySeconds: 10,
          periodSeconds: 10,
          successThreshold: 1,
          timeoutSeconds: 5,
        },
        storage: {
          size: '1Gi',
        },
        metadata: {
          labels: {
            'app.kubernetes.io/instance': 'perses-' + config.prometheusName,
          },
        },
      },
    },
  } + {
    //TODO(saswatamcode): Add proper labels.
    networkPolicy: {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'NetworkPolicy',
      metadata: {
        name: 'perses-' + config.prometheusName,
        namespace: config.namespace,
        labels: config.commonLabels {
          'app.kubernetes.io/instance': 'perses-' + config.prometheusName,
        },
      },
      spec: {
        podSelector: {
          matchLabels: config.selectorLabels,
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
          ports: [
            {
              port: 8080,
              protocol: 'TCP',
            },
          ],
        }],
      },
    },
  }
