local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local deployment = k.apps.v1.deployment;
local container = deployment.mixin.spec.template.spec.containersType;

{
  _config+:: {
    namespace: 'default',

    versions+:: {
      promLabelProxy: 'v0.1.0',
    },

    imageRepos+:: {
      promLabelProxy: 'quay.io/coreos/prom-label-proxy',
    },
  },

  local plp = self,
  config+:: {
    promLabelProxy: {
      image: error 'must provide image',
      name: error 'must provide name',
      insecureListenAddress: error 'must provide insecureListenAddress',
      upstream: error 'must provide upstream',
      label: error 'must provide label',
    },
  },

  specMixin:: {
    spec+: {
      containers+: [
        container.new(plp.config.promLabelProxy.name, plp.config.promLabelProxy.image) +
        container.withArgs([
          '--insecure-listen-address=' + plp.config.promLabelProxy.insecureListenAddress,
          '--upstream=' + plp.config.promLabelProxy.upstream,
          '--label=' + plp.config.promLabelProxy.label,
        ]),
      ],
    },
  },
}
