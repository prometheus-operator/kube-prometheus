// Strips spec.containers[].limits for certain containers
// https://github.com/coreos/kube-prometheus/issues/72
{
  _config+:: {
    resources+:: {
      'addon-resizer'+: {
        limits: {},
      },
      'kube-rbac-proxy'+: {
        limits: {},
      },
      'node-exporter'+: {
        limits: {},
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
}
