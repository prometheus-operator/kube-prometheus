// Strips spec.containers[].limits for certain containers
// https://github.com/prometheus-operator/kube-prometheus/issues/72

{
  //TODO(arthursens): Expand example once kube-rbac-proxy can be managed with a first-class
  // object inside node-exporter, kube-state-metrics and prometheus-operator.
  // See also: https://github.com/prometheus-operator/kube-prometheus/issues/1500#issuecomment-966727623
  values+:: {
    alertmanager+: {
      resources+: {
        limits: {},
      },
    },

    blackboxExporter+: {
      resources+: {
        limits: {},
      },
    },

    grafana+: {
      resources+: {
        limits: {},
      },
    },

    kubeStateMetrics+: {
      resources+: {
        limits: {},
      },
    },

    nodeExporter+: {
      resources+: {
        limits: {},
      },
    },

    prometheusAdapter+: {
      resources+: {
        limits: {},
      },
    },

    prometheusOperator+: {
      resources+: {
        limits: {},
      },
    },

    prometheus+: {
      resources+: {
        limits: {},
      },
    },
  },
}
