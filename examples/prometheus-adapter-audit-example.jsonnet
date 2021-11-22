local kp = (import 'kube-prometheus/main.libsonnet') +
           (import 'kube-prometheus/addons/prometheus-adapter-audit.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
    pa+: {
      auditProfile: 'request',
    },
  },
};

{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
