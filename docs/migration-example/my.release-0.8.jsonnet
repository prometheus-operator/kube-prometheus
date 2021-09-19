// Has the following customisations
// 	Custom alert manager config
// 	Ingresses for the alert manager, prometheus and grafana
// 	Grafana admin user password
// 	Custom prometheus rules
// 	Custom grafana dashboards
// 	Custom prometheus config - Data retention, memory, etc.
//	Node exporter role and role binding so we can use a PSP for the node exporter

// for help with expected content, see https://github.com/thaum-xyz/ankhmorpork

// External variables
// See https://jsonnet.org/learning/tutorial.html
local cluster_identifier = std.extVar('cluster_identifier');
local etcd_ip = std.extVar('etcd_ip');
local etcd_tls_ca = std.extVar('etcd_tls_ca');
local etcd_tls_cert = std.extVar('etcd_tls_cert');
local etcd_tls_key = std.extVar('etcd_tls_key');
local grafana_admin_password = std.extVar('grafana_admin_password');
local prometheus_data_retention_period = std.extVar('prometheus_data_retention_period');
local prometheus_request_memory = std.extVar('prometheus_request_memory');


// Derived variables
local alert_manager_host = 'alertmanager.' + cluster_identifier + '.myorg.local';
local grafana_host = 'grafana.' + cluster_identifier + '.myorg.local';
local prometheus_host = 'prometheus.' + cluster_identifier + '.myorg.local';


// ksonnet no longer required


local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // kubeadm now achieved by setting platform value - see 9 lines below
  (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  (import 'kube-prometheus/addons/podsecuritypolicies.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },

      // Add kubeadm platform-specific items,
      // including kube-contoller-manager and kube-scheduler discovery
      kubePrometheus+: {
        platform: 'kubeadm',
      },

      // Override alert manager config
      // See https://github.com/prometheus-operator/kube-prometheus/blob/main/examples/alertmanager-config-external.jsonnet
      alertmanager+: {
        config: importstr 'alertmanager.yaml',
      },

      // Override etcd config
      // See https://github.com/prometheus-operator/kube-prometheus/blob/main/jsonnet/kube-prometheus/addons/static-etcd.libsonnet
      // See https://github.com/prometheus-operator/kube-prometheus/blob/main/examples/etcd-skip-verify.jsonnet
      etcd+:: {
        clientCA: etcd_tls_ca,
        clientCert: etcd_tls_cert,
        clientKey: etcd_tls_key,
        ips: [etcd_ip],
      },

      // Override grafana config
      // anonymous access
      // 	See http://docs.grafana.org/installation/configuration/
      // 	See http://docs.grafana.org/auth/overview/#anonymous-authentication
      // admin_password
      // 	See http://docs.grafana.org/installation/configuration/#admin-password
      grafana+:: {
        config: {
          sections: {
            'auth.anonymous': {
              enabled: true,
            },
            security: {
              admin_password: grafana_admin_password,
            },
          },
        },
        // Additional grafana dashboards
        dashboards+:: {
          'my-specific.json': (import 'my-grafana-dashboard-definitions.json'),
        },
      },
    },


    // Alert manager needs an externalUrl
    alertmanager+:: {
      alertmanager+: {
        spec+: {

          // See https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/exposing-prometheus-alertmanager-grafana-ingress.md
          externalUrl: 'https://' + alert_manager_host,
        },
      },
    },


    // Add additional ingresses
    // See https://github.com/prometheus-operator/kube-prometheus/blob/main/examples/ingress.jsonnet
    ingress+:: {
      alertmanager: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: 'alertmanager',
          namespace: $.values.common.namespace,
          annotations: {
            'kubernetes.io/ingress.class': 'nginx-api',
          },
        },
        spec: {
          rules: [{
            host: alert_manager_host,
            http: {
              paths: [{
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: 'alertmanager-operated',
                    port: {
                      number: 9093,
                    },
                  },
                },
              }],
            },
          }],
          tls: [{

            hosts: [alert_manager_host],
          }],
        },
      },
      grafana: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: 'grafana',
          namespace: $.values.common.namespace,
          annotations: {
            'kubernetes.io/ingress.class': 'nginx-api',
          },
        },
        spec: {
          rules: [{
            host: grafana_host,
            http: {
              paths: [{
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: 'grafana',
                    port: {
                      number: 3000,
                    },
                  },
                },
              }],
            },
          }],
          tls: [{

            hosts: [grafana_host],
          }],
        },
      },
      prometheus: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: 'prometheus',
          namespace: $.values.common.namespace,
          annotations: {
            'kubernetes.io/ingress.class': 'nginx-api',
          },
        },
        spec: {
          rules: [{
            host: prometheus_host,
            http: {
              paths: [{
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: 'prometheus-operated',
                    port: {
                      number: 9090,
                    },
                  },
                },
              }],
            },
          }],
          tls: [{

            hosts: [prometheus_host],
          }],
        },
      },
    },


    // Node exporter PSP role and role binding
    nodeExporter+: {
      'psp-role'+: {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'Role',
        metadata: {
          name: 'node-exporter-psp',
          namespace: $.values.common.namespace,
        },
        rules: [{
          apiGroups: ['policy'],
          resources: ['podsecuritypolicies'],
          verbs: ['use'],
          resourceNames: ['node-exporter'],
        }],
      },
      'psp-rolebinding'+: {

        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'RoleBinding',
        metadata: {
          name: 'node-exporter-psp',
          namespace: $.values.common.namespace,
        },
        roleRef: {
          apiGroup: 'rbac.authorization.k8s.io',
          name: 'node-exporter-psp',
          kind: 'Role',
        },
        subjects: [{
          kind: 'ServiceAccount',
          name: 'node-exporter',
        }],
      },
    },

    // Prometheus needs some extra custom config
    prometheus+:: {
      prometheus+: {
        spec+: {

          externalLabels: {
            cluster: cluster_identifier,
          },

          // See https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/exposing-prometheus-alertmanager-grafana-ingress.md
          externalUrl: 'https://' + prometheus_host,
          // Override reuest memory
          resources: {
            requests: {
              memory: prometheus_request_memory,
            },
          },
          // Override data retention period
          retention: prometheus_data_retention_period,
        },
      },
    },


    // Additional prometheus rules
    // See https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/developing-prometheus-rules-and-grafana-dashboards.md#pre-rendered-rules
    // cat my-prometheus-rules.yaml | gojsontoyaml -yamltojson | jq . > my-prometheus-rules.json
    prometheusMe: {
      rules: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: 'my-prometheus-rule',
          namespace: $.values.common.namespace,
          labels: {
            'app.kubernetes.io/name': 'kube-prometheus',
            'app.kubernetes.io/part-of': 'kube-prometheus',
            prometheus: 'k8s',
            role: 'alert-rules',
          },
        },
        spec: {
          groups: import 'my-prometheus-rules.json',
        },
      },
    },
  };


// Render
{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ [name + '-ingress']: kp.ingress[name] for name in std.objectFields(kp.ingress) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +

{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
+ { ['prometheus-my-' + name]: kp.prometheusMe[name] for name in std.objectFields(kp.prometheusMe) }
