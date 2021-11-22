### Monitoring additional namespaces

In order to monitor additional namespaces, the Prometheus server requires the appropriate `Role` and `RoleBinding` to be able to discover targets from that namespace. By default the Prometheus server is limited to the three namespaces it requires: default, kube-system and the namespace you configure the stack to run in via `$.values.namespace`. This is specified in `$.values.prometheus.namespaces`, to add new namespaces to monitor, simply append the additional namespaces:

```jsonnet mdox-exec="cat examples/additional-namespaces.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },

    prometheus+: {
      namespaces+: ['my-namespace', 'my-second-namespace'],
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

#### Defining the ServiceMonitor for each additional Namespace

In order to Prometheus be able to discovery and scrape services inside the additional namespaces specified in previous step you need to define a ServiceMonitor resource.

> Typically it is up to the users of a namespace to provision the ServiceMonitor resource, but in case you want to generate it with the same tooling as the rest of the cluster monitoring infrastructure, this is a guide on how to achieve this.

You can define ServiceMonitor resources in your `jsonnet` spec. See the snippet bellow:

```jsonnet mdox-exec="cat examples/additional-namespaces-servicemonitor.jsonnet"
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
    prometheus+:: {
      namespaces+: ['my-namespace', 'my-second-namespace'],
    },
  },
  exampleApplication: {
    serviceMonitorMyNamespace: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'my-servicemonitor',
        namespace: 'my-namespace',
      },
      spec: {
        jobLabel: 'app',
        endpoints: [
          {
            port: 'http-metrics',
          },
        ],
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'myapp',
          },
        },
      },
    },
  },

};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['example-application-' + name]: kp.exampleApplication[name] for name in std.objectFields(kp.exampleApplication) }
```

> NOTE: make sure your service resources have the right labels (eg. `'app': 'myapp'`) applied. Prometheus uses kubernetes labels to discover resources inside the namespaces.
