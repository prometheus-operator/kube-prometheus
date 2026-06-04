local pyrra = import 'github.com/pyrra-dev/pyrra/jsonnet/pyrra/kubernetes.libsonnet';

local defaults = {
  name:: 'pyrra',
  namespace:: error 'must provide namespace',
  version:: error 'must provide version',
  image:: error 'must provide image',
  resources:: {
    limits: { cpu: '200m', memory: '512Mi' },
    requests: { cpu: '100m', memory: '100Mi' },
  },
};

function(params)
  local config = defaults {
    values+:: {
      common+: {
        namespace: params.namespace,
        versions+: { pyrra: params.version },
        images+: { pyrra: params.image },
      },
      pyrra+: params,
    },
  };
  // Safety check
  assert std.isObject(config.resources);

  (pyrra + config).pyrra {
    // Enable generic rules for kube-prometheus by default
    kubernetesDeployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              c {
                args+: [
                  '--generic-rules',
                ],
              }
              for c in super.containers
            ],
          },
        },
      },
    },

    // Suppress upstream SLOs that are redefined in their owning component files
    // with correct kube-prometheus job selectors and richer metadata.
    'slo-kubelet-request-errors':: super['slo-kubelet-request-errors'],
    'slo-kubelet-runtime-errors':: super['slo-kubelet-runtime-errors'],
    'slo-coredns-response-errors':: super['slo-coredns-response-errors'],
    'slo-prometheus-operator-reconcile-errors':: super['slo-prometheus-operator-reconcile-errors'],
    'slo-prometheus-operator-http-errors':: super['slo-prometheus-operator-http-errors'],
  }
