---
weight: 303
toc: true
title: Expose via Gateway API
menu:
    docs:
        parent: kube
lead: This guide will help you exposing Prometheus, Alertmanager and Grafana using the Gateway API.
images: []
draft: false
description: This guide will help you exposing Prometheus, Alertmanager and Grafana using the Gateway API.
---

In order to access the web interfaces via the Internet, the [Gateway API](https://gateway-api.sigs.k8s.io/) is the recommended option. This guide explains how the Gateway API can be used to expose the Prometheus, Alertmanager and Grafana UIs, that are included in the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) project.

Note: before continuing, it is recommended to first get familiar with the [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) stack by itself.

## Prerequisites

Apart from a running Kubernetes cluster with a running [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) stack, a [Gateway API](https://gateway-api.sigs.k8s.io/) controller must be installed and a `GatewayClass` must be available. The Gateway API is implemented by a number of controllers, for example Istio, Envoy Gateway and Contour; refer to the [list of implementations](https://gateway-api.sigs.k8s.io/) and follow your controller's installation instructions. The `gatewayClassName` referenced below must match a `GatewayClass` that exists in your cluster.

## Setting up routing

The Gateway API splits the configuration into two resources: a `Gateway`, which defines the entry point (its listeners, ports and protocols) and is usually created once and shared, and an `HTTPRoute`, which attaches to a `Gateway` and forwards traffic to a Service. The setup of `HTTPRoute` objects is the same for Prometheus, Alertmanager and Grafana. Therefore this guide demonstrates it in detail for Prometheus as it can easily be adapted for the other applications.

As monitoring data may contain sensitive data, these endpoints should be protected with authentication. The Gateway API does not define a portable authentication mechanism. Authentication is instead configured through the APIs of your Gateway controller — for example an external authorization filter or a policy attached to the `Gateway` or `HTTPRoute` — or by placing an authenticating proxy such as [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) in front of the Services. Consult the documentation of your Gateway API implementation for the supported options.

Also, the applications provide external links to themselves in alerts and various places. When a Gateway is used in front of the applications these links need to be based on the external URL's. This can be configured for each application in jsonnet.

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },
    prometheus+:: {
      prometheus+: {
        spec+: {
          externalUrl: 'http://prometheus.example.com',
        },
      },
    },
    gatewayAPI+:: {
      // The Gateway is the entry point for external traffic. It is normally
      // created once and shared by all routes. 'gatewayClassName' selects the
      // controller that implements it and must match a GatewayClass in your
      // cluster.
      gateway: {
        apiVersion: 'gateway.networking.k8s.io/v1',
        kind: 'Gateway',
        metadata: {
          name: 'main',
          namespace: $.values.common.namespace,
        },
        spec: {
          gatewayClassName: 'example',
          listeners: [{
            name: 'http',
            protocol: 'HTTP',
            port: 80,
            allowedRoutes: {
              namespaces: {
                from: 'Same',
              },
            },
          }],
        },
      },
      // The HTTPRoute attaches to the Gateway and forwards the hostname to the
      // Prometheus Service. backendRefs use the numeric Service port (9090).
      'prometheus-k8s': {
        apiVersion: 'gateway.networking.k8s.io/v1',
        kind: 'HTTPRoute',
        metadata: {
          name: $.prometheus.service.metadata.name,
          namespace: $.values.common.namespace,
        },
        spec: {
          parentRefs: [{
            name: 'main',
          }],
          hostnames: ['prometheus.example.com'],
          rules: [{
            matches: [{
              path: {
                type: 'PathPrefix',
                value: '/',
              },
            }],
            backendRefs: [{
              name: $.prometheus.service.metadata.name,
              port: 9090,
            }],
          }],
        },
      },
    },
  };

// Render the Gateway and HTTPRoute objects as individual manifests
{ ['gateway-api-' + name]: kp.gatewayAPI[name] for name in std.objectFields(kp.gatewayAPI) }
```

In order to expose Alertmanager and Grafana, simply create additional `HTTPRoute` objects, but simply pointing at the `alertmanager-main` or `grafana` Service instead of the `prometheus-k8s` Service. Make sure to also use the correct numeric port respectively, for Alertmanager it is `9093`, for Grafana it is `3000`. Be sure to also specify the appropriate external URL. Note that the external URL for Grafana is set in a different way than the external URL for Prometheus or Alertmanager. See [ingress.jsonnet](https://github.com/prometheus-operator/kube-prometheus/tree/main/examples/ingress.jsonnet) for how to set the Grafana external URL.

In order to render the Gateway and `HTTPRoute` objects similar to the other objects use as demonstrated in the [main readme](https://github.com/prometheus-operator/kube-prometheus/tree/main/README.md):

```jsonnet
{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['gateway-api-' + name]: kp.gatewayAPI[name] for name in std.objectFields(kp.gatewayAPI) }
```

Note, that in comparison only the last line was added, the rest is identical to the original.

See [ingress.jsonnet](https://github.com/prometheus-operator/kube-prometheus/tree/main/examples/ingress.jsonnet) for an example implementation.

## Adding the Gateway namespace to NetworkPolicies

NetworkPolicies restricting access to the components are added by default. These can either be removed as in
[networkpolicies-disabled.jsonnet](https://github.com/prometheus-operator/kube-prometheus/tree/main/examples/networkpolicies-disabled.jsonnet) or modified to allow traffic from the namespace where your Gateway controller's data plane runs, as
described here.

This is an example for Alertmanager, but the same can be applied to Grafana and Prometheus. Replace `gateway-system` with the namespace of your Gateway controller.

```jsonnet
{
  alertmanager+:: {
    networkPolicy+: {
      spec+: {
        ingress: [
          super.ingress[0] + {
            from+: [
              {
                namespaceSelector: {
                  matchLabels: {
                    'kubernetes.io/metadata.name': 'gateway-system',
                  },
                },
              },
            ],
          },
        ] + super.ingress[1:],
      },
    },
  },
}
```
