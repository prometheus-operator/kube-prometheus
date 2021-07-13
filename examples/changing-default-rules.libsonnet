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

{ 'kubernetesControlPlane-prometheusRule': kp.kubernetesControlPlane.prometheusRule } +
{ ['exampleApplication-' + name]: kp.exampleApplication[name] for name in std.objectFields(kp.exampleApplication) }
