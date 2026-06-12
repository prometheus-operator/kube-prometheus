// This example exposes Alertmanager, Grafana and Prometheus through a single
// Gateway API Gateway that acts as one shared entry point for all three
// applications. It creates the Gateway and one HTTPRoute per application, all
// attached to that Gateway.
//
// The GatewayClass referenced by the Gateway is provided by your Gateway API
// controller (for example Istio, Envoy Gateway or Contour). Replace
// 'gatewayClassName' with a GatewayClass that exists in your cluster.
local gatewayName = 'kube-prometheus';
local gatewayClassName = 'example';

local httpRoute(name, namespace, hostname, serviceName, servicePort) = {
  apiVersion: 'gateway.networking.k8s.io/v1',
  kind: 'HTTPRoute',
  metadata: {
    name: name,
    namespace: namespace,
  },
  spec: {
    parentRefs: [{
      name: gatewayName,
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
    // Create one Gateway as a shared entry point and an HTTPRoute per
    // application attached to it.
    gatewayAPI+:: {
      gateway: {
        apiVersion: 'gateway.networking.k8s.io/v1',
        kind: 'Gateway',
        metadata: {
          name: gatewayName,
          namespace: $.values.common.namespace,
        },
        spec: {
          gatewayClassName: gatewayClassName,
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
      'alertmanager-main': httpRoute('alertmanager-main', $.values.common.namespace, 'alertmanager.example.com', 'alertmanager-main', 9093),
      grafana: httpRoute('grafana', $.values.common.namespace, 'grafana.example.com', 'grafana', 3000),
      'prometheus-k8s': httpRoute('prometheus-k8s', $.values.common.namespace, 'prometheus.example.com', 'prometheus-k8s', 9090),
    },
  };

{ [name + '-gateway-api']: kp.gatewayAPI[name] for name in std.objectFields(kp.gatewayAPI) }
