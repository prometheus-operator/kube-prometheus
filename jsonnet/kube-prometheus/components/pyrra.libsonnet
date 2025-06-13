local pyrra = import 'github.com/pyrra-dev/pyrra/jsonnet/pyrra/kubernetes.libsonnet';

local defaults = {
  local defaults = self,

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
      pyrra+: params,
    },
  };
  // Safety check
  assert std.isObject(config.resources);

  (pyrra + config).pyrra {
    // Enable generic rules for kube-promethues by default
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
  }
