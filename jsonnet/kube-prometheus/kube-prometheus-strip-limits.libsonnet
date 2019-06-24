// Strips spec.containers[].limits for certain containers
// https://github.com/coreos/kube-prometheus/issues/72
{
  nodeExporter+: {
    daemonset+: {
      spec+: {
        template+: {
          spec+: {
            local stripLimits(c) =
                if std.setMember(c.name, [
                  'kube-rbac-proxy',
                  'node-exporter',
                ])
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
                if std.setMember(c.name, [
                  'addon-resizer',
                  'kube-rbac-proxy-main',
                  'kube-rbac-proxy-self',
                ])
                then c + {resources+: {limits: {}}}
                else c,
            containers: std.map(stripLimits, super.containers),
          },
        },
      },
    },
  },
}
