local filter = {
  kubernetesControlPlane+: {
    prometheusRule+:: {
      spec+: {
        groups: std.map(
          function(group)
            if group.name == 'kubernetes-apps' then
              group {
                rules: std.filter(
                  function(rule)
                    rule.alert != 'KubeStatefulSetReplicasMismatch',
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
local update = {
  kubernetesControlPlane+: {
    prometheusRule+:: {
      spec+: {
        groups: std.map(
          function(group)
            if group.name == 'kubernetes-apps' then
              group {
                rules: std.map(
                  function(rule)
                    if rule.alert == 'KubePodCrashLooping' then
                      rule {
                        expr: 'rate(kube_pod_container_status_restarts_total{namespace=kube-system,job="kube-state-metrics"}[10m]) * 60 * 5 > 0',
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

local add = {
  exampleApplication:: {
    prometheusRule+: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        name: 'example-application-rules',
        namespace: $.values.common.namespace,
      },
      spec: (import 'existingrule.json'),
    },
  },
};
local kp = (import 'kube-prometheus/main.libsonnet') +
           filter +
           update +
           add + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
};

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) } +
{ ['exampleApplication-' + name]: kp.exampleApplication[name] for name in std.objectFields(kp.exampleApplication) }
