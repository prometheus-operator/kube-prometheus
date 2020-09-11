local k = import 'github.com/ksonnet/ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

{
  _config+:: {
    versions+:: {
      thanos: 'v0.14.0',
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
    // Create a new service that exposes both sidecar's HTTP metrics port and gRPC StoreAPI
    serviceThanosSidecar:
      local thanosGrpcSidecarPort = servicePort.newNamed('grpc', 10901, 10901);
      local thanosHttpSidecarPort = servicePort.newNamed('http', 10902, 10902);
      service.new('prometheus-' + $._config.prometheus.name + '-thanos-sidecar', { app: 'prometheus', prometheus: $._config.prometheus.name }) +
      service.mixin.spec.withPorts([thanosGrpcSidecarPort, thanosHttpSidecarPort]) +
      service.mixin.spec.withClusterIp('None') +
      service.mixin.metadata.withLabels({'prometheus': $._config.prometheus.name, 'app': 'thanos-sidecar'}) +
      service.mixin.metadata.withNamespace($._config.namespace),
    prometheus+: {
      spec+: {
        thanos+: {
          version: $._config.versions.thanos,
          image: $._config.imageRepos.thanos + ':' + $._config.versions.thanos,
          objectStorageConfig: $._config.thanos.objectStorageConfig,
        },
      },
    },
    serviceMonitorThanosSidecar:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'thanos-sidecar',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'prometheus',
          },
        },
        spec: {
          // Use the service's app label (thanos-sidecar) as the value for the job label.
          jobLabel: 'app',
          selector: {
            matchLabels: {
              prometheus: $._config.prometheus.name,
              app: 'thanos-sidecar',
            },
          },
          endpoints: [
            {
              port: 'http',
              interval: '30s',
            },
          ],
        },
      },
  },
}
