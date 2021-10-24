local ingress(name, namespace, rules) = {
  apiVersion: 'networking.k8s.io/v1',
  kind: 'Ingress',
  metadata: {
    name: name,
    namespace: namespace,
    annotations: {
      'nginx.ingress.kubernetes.io/auth-type': 'basic',
      'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
      'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
    },
  },
  spec: { rules: rules },
};

local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    _config+:: {
      namespace: 'monitoring',
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
    // Create one ingress object that routes to each individual application
    ingress+:: {
      'kube-prometheus': ingress(
        'kube-prometheus',
        $._config.namespace,
        [
          {
            host: 'alertmanager.example.com',
            http: {
              paths: [{
                backend: {
                  service: {
                    name: 'alertmanager-main',
                    port: 'web',
                  },
                },
              }],
            },
          },
          {
            host: 'grafana.example.com',
            http: {
              paths: [{
                backend: {
                  service: {
                    name: 'grafana',
                    port: 'http',
                  },
                },
              }],
            },
          },
          {
            host: 'alertmanager.example.com',
            http: {
              paths: [{
                backend: {
                  service: {
                    name: 'prometheus-k8s',
                    port: 'web',
                  },
                },
              }],
            },
          },
        ]
      ),

    },
  } + {
    // Create basic auth secret - replace 'auth' file with your own
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

{ [name + '-ingress']: kp.ingress[name] for name in std.objectFields(kp.ingress) }
