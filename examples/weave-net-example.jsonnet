local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/addons/weave-net/weave-net.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
  kubernetesControlPlane+: {
    prometheusRuleWeaveNet+: {
      spec+: {
        groups: std.map(
          function(group)
            if group.name == 'weave-net' then
              group {
                rules: std.map(
                  function(rule)
                    if rule.alert == 'WeaveNetFastDPFlowsLow' then
                      rule {
                        expr: 'sum(weave_flows) < 20000',
                      }
                    else if rule.alert == 'WeaveNetIPAMUnreachable' then
                      rule {
                        expr: 'weave_ipam_unreachable_percentage > 25',
                      }
                    else
                      rule
                  ,
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

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
