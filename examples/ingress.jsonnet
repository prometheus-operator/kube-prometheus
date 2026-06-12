// This example exposes Alertmanager, Grafana and Prometheus through the Gateway
// API. It creates one HTTPRoute per application, each attaching to an existing
// Gateway and routing a hostname to the matching Service.
//
// The Gateway (and its GatewayClass) is provided by your Gateway API controller
// (for example Istio, Envoy Gateway or Contour) and is not managed by
// kube-prometheus. This example assumes a Gateway named 'main' already exists in
// the same namespace and accepts routes from it.
local httpRoute(name, namespace, hostname, serviceName, servicePort) = {
  apiVersion: 'gateway.networking.k8s.io/v1',
  kind: 'HTTPRoute',
  metadata: {
    name: name,
    namespace: namespace,
  },
  spec: {
    parentRefs: [{
      name: 'main',
    }],
    hostnames: [hostname],
    rules: [{
      matches: [{
        path: {
          type: 'PathPrefix',
          value: '/',
        },
      }],
      backendRefs: [{
        name: serviceName,
        port: servicePort,
      }],
    }],
  },
};

local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
      grafana+:: {
        config+: {
          sections+: {
            server+: {
              root_url: 'http://grafana.example.com/',
            },
          },
        },
      },
    },
    // Configure External URL's per application
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          externalUrl: 'http://alertmanager.example.com',
        },
      },
    },
    prometheus+:: {
      prometheus+: {
        spec+: {
          externalUrl: 'http://prometheus.example.com',
        },
      },
    },
    // Create an HTTPRoute object per application
    httpRoute+:: {
      'alertmanager-main': httpRoute('alertmanager-main', $.values.common.namespace, 'alertmanager.example.com', 'alertmanager-main', 9093),
      grafana: httpRoute('grafana', $.values.common.namespace, 'grafana.example.com', 'grafana', 3000),
      'prometheus-k8s': httpRoute('prometheus-k8s', $.values.common.namespace, 'prometheus.example.com', 'prometheus-k8s', 9090),
    },
  };

{ [name + '-httproute']: kp.httpRoute[name] for name in std.objectFields(kp.httpRoute) }
