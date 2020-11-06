# Exposing Prometheus, Alertmanager and Grafana UIs via Ingress

In order to access the web interfaces via the Internet [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) is a popular option. This guide explains, how Kubernetes Ingress can be setup, in order to expose the Prometheus, Alertmanager and Grafana UIs, that are included in the [kube-prometheus](https://github.com/coreos/kube-prometheus) project.

Note: before continuing, it is recommended to first get familiar with the [kube-prometheus](https://github.com/coreos/kube-prometheus) stack by itself.

## Prerequisites

Apart from a running Kubernetes cluster with a running [kube-prometheus](https://github.com/coreos/kube-prometheus) stack, a Kubernetes Ingress controller must be installed and functional. This guide was tested with the [nginx-ingress-controller](https://github.com/kubernetes/ingress-nginx). If you wish to reproduce the exact result in as depicted in this guide we recommend using the nginx-ingress-controller.

## Setting up Ingress

The setup of Ingress objects is the same for Prometheus, Alertmanager and Grafana. Therefore this guides demonstrates it in detail for Prometheus as it can easily be adapted for the other applications.

As monitoring data may contain sensitive data, this guide describes how to setup Ingress with basic auth as an example of minimal security. Of course this should be adapted to the preferred authentication mean of any particular organization, but we feel it is important to at least provide an example with a minimum of security.

In order to setup basic auth, a secret with the `htpasswd` formatted file needs to be created. To do this, first install the [`htpasswd`](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) tool.

To create the `htpasswd` formatted file called `auth` run:

```
htpasswd -c auth <username>
```

In order to use this a secret needs to be created containing the name of the `htpasswd`, and with annotations on the Ingress object basic auth can be configured.

Also, the applications provide external links to themselves in alerts and various places. When an ingress is used in front of the applications these links need to be based on the external URL's. This can be configured for each application in jsonnet.

```jsonnet
local kp =
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
  {
    _config+:: {
      namespace: 'monitoring',
    },
    prometheus+:: {
      prometheus+: {
        spec+: {
          externalUrl: 'http://prometheus.example.com',
        },
      },
    },
    ingress+:: {
      'prometheus-k8s': {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: $.prometheus.prometheus.metadata.name,
          namespace: $.prometheus.prometheus.metadata.namespace,
          annotations: {
            'nginx.ingress.kubernetes.io/auth-type': 'basic',
            'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
            'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
          },
        },
        spec: {
          rules: [{
            host: 'prometheus.example.com',
            http: {
              paths: [{
                backend: {
                  service: {
                    name: $.prometheus.service.metadata.name,
                    port: 'web',
                  },
                },
              }],
            },
          }],
        },
    },
  } + {
    ingress+:: {
      'basic-auth-secret': {
        apiVersion: 'v1',
        kind: 'Secret',
        metadata: {
          name: 'basic-auth',
          namespace: $._config.namespace,
        },
        data: { auth: std.base64(importstr 'auth') },
        type: 'Opaque',
      },
    },
  };

k.core.v1.list.new([
  kp.ingress['prometheus-k8s'],
  kp.ingress['basic-auth-secret'],
])
```

In order to expose Alertmanager and Grafana, simply create additional fields containing an ingress object, but simply pointing at the `alertmanager` or `grafana` instead of the `prometheus-k8s` Service. Make sure to also use the correct port respectively, for Alertmanager it is also `web`, for Grafana it is `http`. Be sure to also specify the appropriate external URL. Note that the external URL for grafana is set in a different way than the external URL for Prometheus or Alertmanager. See [ingress.jsonnet](../examples/ingress.jsonnet) for how to set the Grafana external URL.

In order to render the ingress objects similar to the other objects use as demonstrated in the [main readme](../README.md#usage):

```
{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['ingress-' + name]: kp.ingress[name] for name in std.objectFields(kp.ingress) }
```

Note, that in comparison only the last line was added, the rest is identical to the original.

See [ingress.jsonnet](../examples/ingress.jsonnet) for an example implementation.
