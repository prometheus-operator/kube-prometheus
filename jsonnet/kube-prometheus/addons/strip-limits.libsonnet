// Strips spec.containers[].limits for certain containers
// https://github.com/prometheus-operator/kube-prometheus/issues/72

{
  local noLimit(c) =
    //if std.objectHas(c, 'resources') && c.name != 'kube-state-metrics'
    if c.name != 'kube-state-metrics'
    then c { resources+: { limits: {} } }
    else c,

  nodeExporter+: {
    daemonset+: {
      spec+: {
        template+: {
          spec+: {
            containers: std.map(noLimit, super.containers),
          },
        },
      },
    },
  },
  kubeStateMetrics+: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: std.map(noLimit, super.containers),
          },
        },
      },
    },
  },
  prometheusOperator+: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            local addArgs(c) =
              if c.name == 'prometheus-operator'
              then c { args+: ['--config-reloader-cpu=0'] }
              else c,
            containers: std.map(addArgs, super.containers),
          },
        },
      },
    },
  },
}
