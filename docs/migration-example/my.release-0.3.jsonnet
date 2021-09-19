// Has the following customisations
// 	Custom alert manager config
// 	Ingresses for the alert manager, prometheus and grafana
// 	Grafana admin user password
// 	Custom prometheus rules
// 	Custom grafana dashboards
// 	Custom prometheus config - Data retention, memory, etc.
//	Node exporter role and role binding so we can use a PSP for the node exporter


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


// Imports
local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local ingress = k.extensions.v1beta1.ingress;
local ingressRule = ingress.mixin.spec.rulesType;
local ingressRuleHttpPath = ingressRule.mixin.http.pathsType;
local ingressTls = ingress.mixin.spec.tlsType;
local role = k.rbac.v1.role;
local roleBinding = k.rbac.v1.roleBinding;
local roleRulesType = k.rbac.v1.role.rulesType;


local kp =
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
  (import 'kube-prometheus/kube-prometheus-kubeadm.libsonnet') +
  (import 'kube-prometheus/kube-prometheus-static-etcd.libsonnet') +

  {
    _config+:: {
      // Override namespace
      namespace: 'monitoring',


      // Override alert manager config
      // See https://github.com/coreos/kube-prometheus/tree/master/examples/alertmanager-config-external.jsonnet
      alertmanager+: {
        config: importstr 'alertmanager.yaml',
      },

      // Override etcd config
      // See https://github.com/coreos/kube-prometheus/blob/master/jsonnet/kube-prometheus/kube-prometheus-static-etcd.libsonnet
      // See https://github.com/coreos/kube-prometheus/blob/master/examples/etcd-skip-verify.jsonnet
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


      },
    },

    // Additional grafana dashboards
    grafanaDashboards+:: {
      'my-specific.json': (import 'my-grafana-dashboard-definitions.json'),
    },

    // Alert manager needs an externalUrl
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          // See https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md
          // See https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/exposing-prometheus-and-alertmanager.md
          externalUrl: 'https://' + alert_manager_host,
        },
      },
    },


    // Add additional ingresses
    // See https://github.com/coreos/kube-prometheus/tree/master/examples/ingress.jsonnet
    ingress+:: {
      alertmanager:
        ingress.new() +


        ingress.mixin.metadata.withName('alertmanager') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
          'kubernetes.io/ingress.class': 'nginx-api',
        }) +

        ingress.mixin.spec.withRules(
          ingressRule.new() +
          ingressRule.withHost(alert_manager_host) +
          ingressRule.mixin.http.withPaths(
            ingressRuleHttpPath.new() +


            ingressRuleHttpPath.mixin.backend.withServiceName('alertmanager-operated') +

            ingressRuleHttpPath.mixin.backend.withServicePort(9093)
          ),
        ) +


        // Note we do not need a TLS secretName here as we are going to use the nginx-ingress default secret which is a wildcard
        // secretName would need to be in the same namespace at this time, see https://github.com/kubernetes/ingress-nginx/issues/2371
        ingress.mixin.spec.withTls(
          ingressTls.new() +
          ingressTls.withHosts(alert_manager_host)
        ),


      grafana:
        ingress.new() +


        ingress.mixin.metadata.withName('grafana') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
          'kubernetes.io/ingress.class': 'nginx-api',
        }) +

        ingress.mixin.spec.withRules(
          ingressRule.new() +
          ingressRule.withHost(grafana_host) +
          ingressRule.mixin.http.withPaths(
            ingressRuleHttpPath.new() +


            ingressRuleHttpPath.mixin.backend.withServiceName('grafana') +

            ingressRuleHttpPath.mixin.backend.withServicePort(3000)
          ),
        ) +


        // Note we do not need a TLS secretName here as we are going to use the nginx-ingress default secret which is a wildcard
        // secretName would need to be in the same namespace at this time, see https://github.com/kubernetes/ingress-nginx/issues/2371
        ingress.mixin.spec.withTls(
          ingressTls.new() +
          ingressTls.withHosts(grafana_host)
        ),


      prometheus:
        ingress.new() +


        ingress.mixin.metadata.withName('prometheus') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
          'kubernetes.io/ingress.class': 'nginx-api',
        }) +
        ingress.mixin.spec.withRules(
          ingressRule.new() +

          ingressRule.withHost(prometheus_host) +
          ingressRule.mixin.http.withPaths(
            ingressRuleHttpPath.new() +


            ingressRuleHttpPath.mixin.backend.withServiceName('prometheus-operated') +

            ingressRuleHttpPath.mixin.backend.withServicePort(9090)
          ),
        ) +


        // Note we do not need a TLS secretName here as we are going to use the nginx-ingress default secret which is a wildcard
        // secretName would need to be in the same namespace at this time, see https://github.com/kubernetes/ingress-nginx/issues/2371
        ingress.mixin.spec.withTls(
          ingressTls.new() +
          ingressTls.withHosts(prometheus_host)
        ),
    },


    // Node exporter PSP role and role binding
    // Add a new top level field for this, the "node-exporter" PSP already exists, so not defining here just referencing
    // See https://github.com/coreos/prometheus-operator/issues/787
    nodeExporterPSP: {
      role:
        role.new() +


        role.mixin.metadata.withName('node-exporter-psp') +
        role.mixin.metadata.withNamespace($._config.namespace) +
        role.withRules([
          roleRulesType.new() +
          roleRulesType.withApiGroups(['policy']) +
          roleRulesType.withResources(['podsecuritypolicies']) +
          roleRulesType.withVerbs(['use']) +
          roleRulesType.withResourceNames(['node-exporter']),
        ]),

      roleBinding:
        roleBinding.new() +
        roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +


        roleBinding.mixin.metadata.withName('node-exporter-psp') +
        roleBinding.mixin.metadata.withNamespace($._config.namespace) +


        roleBinding.mixin.roleRef.withName('node-exporter-psp') +
        roleBinding.mixin.roleRef.mixinInstance({ kind: 'Role' }) +


        roleBinding.withSubjects([{ kind: 'ServiceAccount', name: 'node-exporter' }]),


    },


    // Prometheus needs some extra custom config
    prometheus+:: {
      prometheus+: {
        spec+: {
          // See https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#prometheusspec
          externalLabels: {
            cluster: cluster_identifier,
          },
          // See https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md
          // See https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/exposing-prometheus-and-alertmanager.md
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
    // See https://github.com/coreos/kube-prometheus/docs/developing-prometheus-rules-and-grafana-dashboards.md
    // cat my-prometheus-rules.yaml | gojsontoyaml -yamltojson | jq . > my-prometheus-rules.json
    prometheusRules+:: {


      groups+: import 'my-prometheus-rules.json',


    },
  };


// Render
{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +


{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +


{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +

{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +

{ [name + '-ingress']: kp.ingress[name] for name in std.objectFields(kp.ingress) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['node-exporter-psp-' + name]: kp.nodeExporterPSP[name] for name in std.objectFields(kp.nodeExporterPSP) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
