// Example: Customizing Grafana Self-Monitoring
//
// This example demonstrates how to customize various aspects of Grafana monitoring
// in kube-prometheus, including alert labels, scrape intervals, and runbook URLs.

local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },

      // Customize Grafana monitoring configuration
      grafana+: {
        // Add custom labels to all Grafana monitoring alerts
        mixin+: {
          ruleLabels: {
            // Add team ownership label
            team: 'platform-observability',

            // Add severity labels for paging integration
            severity_page: 'true',

            // Add component label
            component: 'grafana',

            // Custom label for your organization
            environment: 'production',
          },

          // Customize mixin configuration
          _config+: {
            // Override runbook URL pattern to point to your documentation
            runbookURLPattern: 'https://runbooks.example.com/grafana/%s',

            // You can also add custom mixin configuration here
            // For example, thresholds or other mixin-specific settings
            // (Check the Grafana mixin source for available options)
          },
        },
      },
    },

    // Further customize the Grafana ServiceMonitor
    grafana+: {
      serviceMonitor+: {
        spec+: {
          endpoints: [
            {
              port: 'http',
              // Change scrape interval from default 15s to 30s
              interval: '30s',

              // Add custom relabeling if needed
              // relabelings: [
              //   {
              //     sourceLabels: ['__meta_kubernetes_pod_name'],
              //     targetLabel: 'pod',
              //   },
              // ],

              // Add metric relabeling to drop unwanted metrics
              // metricRelabelings: [
              //   {
              //     sourceLabels: ['__name__'],
              //     regex: 'grafana_plugin_.*',
              //     action: 'drop',
              //   },
              // ],
            },
          ],
        },
      },

      // Customize the PrometheusRule if needed
      prometheusRule+: {
        spec+: {
          // You can modify alert thresholds by overriding specific rules
          // Note: This is an advanced use case
          groups: std.map(
            function(group)
              if group.name == 'GrafanaAlerts' then
                group {
                  rules: std.map(
                    function(rule)
                      if std.objectHas(rule, 'alert') && rule.alert == 'GrafanaRequestsFailing' then
                        // Customize the GrafanaRequestsFailing alert
                        rule {
                          // Change severity to critical instead of warning
                          labels+: {
                            severity: 'critical',
                          },
                          // Add additional annotations
                          annotations+: {
                            summary: 'Grafana is experiencing high error rates',
                            dashboard_url: 'https://grafana.example.com/d/grafana-overview',
                          },
                          // Modify the threshold (change from 50% to 25%)
                          expr: std.strReplace(
                            rule.expr,
                            '> 50',
                            '> 25'
                          ),
                        }
                      else
                        rule,
                    group.rules
                  ),
                }
              else
                group,
            super.groups
          ),
        },
      },
    },
  };

// Generate manifests
{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter(function(name) name != 'serviceMonitor' && name != 'prometheusRule', std.objectFields(kp.prometheusOperator))
} +
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +

// Generate Grafana manifests with customizations
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +

{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
