local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local secret = k.core.v1.secret;
local ingress = k.extensions.v1beta1.ingress;
local ingressTls = ingress.mixin.spec.tlsType;
local ingressRule = ingress.mixin.spec.rulesType;
local httpIngressPath = ingressRule.mixin.http.pathsType;

local kp =
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
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
      'kube-prometheus':
        ingress.new() +
        ingress.mixin.metadata.withName('prometheus-k8s') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
            'nginx.ingress.kubernetes.io/auth-type': 'basic',
            'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
            'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
        }) +
          ingress.mixin.spec.withRules([
            ingressRule.new() +
            ingressRule.withHost('prometheus.dev.kepler-ops.io') +
            ingressRule.mixin.http.withPaths(
                httpIngressPath.new() +
                httpIngressPath.mixin.backend.withServiceName('prometheus-k8s') +
                httpIngressPath.mixin.backend.withServicePort('web')
            ) ,            
            ingressRule.withHost('alertmanager.example.com') +
            ingressRule.mixin.http.withPaths(
                httpIngressPath.new() +
                httpIngressPath.mixin.backend.withServiceName('alertmanager-main') +
                httpIngressPath.mixin.backend.withServicePort('web')
            ),
            ingressRule.withHost('grafana.example.com') +
              ingressRule.mixin.http.withPaths(
                  httpIngressPath.new() +
                  httpIngressPath.mixin.backend.withServiceName('grafana') +
                  httpIngressPath.mixin.backend.withServicePort('http')
          )]
        ),
    }, + {
    // Create basic auth secret - replace 'auth' file with your own
    ingress+:: {
      'basic-auth-secret':
        secret.new('basic-auth', { auth: std.base64(importstr 'auth') }) +
        secret.mixin.metadata.withNamespace($._config.namespace),
    },
  };

{ [name + '-ingress']: kp.ingress[name] for name in std.objectFields(kp.ingress) }
