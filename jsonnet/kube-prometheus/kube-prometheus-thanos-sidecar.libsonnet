local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

{
  _config+:: {
    versions+:: {
      thanos: 'v0.7.0',
    },
    imageRepos+:: {
      thanos: 'quay.io/thanos/thanos',
    },
    thanos+:: {
      objectStorageConfig: {
        key: 'thanos.yaml',  // How the file inside the secret is called
        name: 'thanos-objectstorage',  // This is the name of your Kubernetes secret with the config
      },
    },
  },
  prometheus+:: {
    // Add the grpc port to the Prometheus service to be able to query it with the Thanos Querier
    service+: {
      spec+: {
        ports+: [
          servicePort.newNamed('grpc', 10901, 10901),
        ],
      },
    },
    prometheus+: {
      spec+: {
        thanos+: {
          version: $._config.versions.thanos,
          baseImage: $._config.imageRepos.thanos,
          objectStorageConfig: $._config.thanos.objectStorageConfig,
        },
      },
    },
  },
}
