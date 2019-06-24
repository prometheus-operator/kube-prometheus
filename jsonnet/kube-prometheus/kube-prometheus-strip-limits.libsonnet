// Strips spec.containers[].limits for certain containers
// https://github.com/coreos/kube-prometheus/issues/72
{
  nodeExporter+: {
    daemonset+: {
      spec+: {
        template+: {
          spec+: {
            local stripLimits(c) =
                if std.count([
                    'node-exporter',
                    'kube-rbac-proxy'
                ], c.name) > 0
                then c + {resources+: {limits: {}}}
                else c,
            containers: std.map(stripLimits, super.containers),
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
                then c + {args+: ['--config-reloader-cpu=0']}
                else c,
            containers: std.map(addArgs, super.containers),
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
            local stripLimits(c) =
                if std.count([
                    'kube-rbac-proxy-main',
                    'kube-rbac-proxy-self',
                    'addon-resizer'
                ], c.name) > 0
                then c + {resources+: {limits: {}}}
                else c,
            containers: std.map(stripLimits, super.containers),
          },
        },
      },
    },
  },
}
