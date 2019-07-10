local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

{
  _config+:: {
    versions+:: {
      thanos: 'v0.5.0',
    },
    imageRepos+:: {
      thanos: 'improbable/thanos',
    },
    thanos+:: {
      objectStorageConfig: {
        key: 'thanos.yaml',  // How the file inside the secret is called
        name: 'thanos-objstore-config',  // This is the name of your Kubernetes secret with the config
      },
    },
  },
  prometheus+:: {
    prometheus+: {
      spec+: {
        thanos+: {
          version: $._config.versions.thanos,
          baseImage: $._config.imageRepos.thanos,
          objectStorageConfig: $._config.thanos.objectStorageConfig,
        },
      },
    },
    thanosQueryDeployment:
      local deployment = k.apps.v1.deployment;
      local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;

      local thanosQueryContainer =
        container.new('thanos-query', $._config.imageRepos.thanos + ':' + $._config.versions.thanos) +
        container.withPorts([
          containerPort.newNamed(10902, 'http'),
          containerPort.newNamed(10901, 'grpc'),
        ]) +
        container.withArgs([
          'query',
          '--log.level=debug',
          '--query.replica-label=prometheus_replica',
          '--query.auto-downsampling',
          '--store=dnssrv+thanos-store.' + $._config.namespace + '.svc:10901',
        ]);
      local podLabels = { app: 'thanos-query' };
      deployment.new('thanos-query', 1, thanosQueryContainer, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.template.spec.withServiceAccountName('prometheus-' + $._config.prometheus.name),
    thanosQueryService:
      local thanosQueryPort = servicePort.newNamed('http', 10902, 'http');
      service.new('thanos-query', { app: 'thanos-query' }, thanosQueryPort) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ app: 'thanos-query' }),
    thanosStoreStatefulset:
      local statefulSet = k.apps.v1.statefulSet;
      local volume = statefulSet.mixin.spec.template.spec.volumesType;
      local container = statefulSet.mixin.spec.template.spec.containersType;
      local containerEnv = container.envType;
      local containerVolumeMount = container.volumeMountsType;

      local labels = { app: 'thanos-store' };

      local c =
        container.new('thanos-store', $._config.imageRepos.thanos + ':' + $._config.versions.thanos) +
        container.withArgs([
          'store',
          '--log.level=debug',
          '--data-dir=/var/thanos/store',
          '--objstore.config=$(OBJSTORE_CONFIG)',
        ]) +
        container.withEnv([
          containerEnv.fromSecretRef(
            'OBJSTORE_CONFIG',
            $._config.thanos.objectStorageConfig.name,
            $._config.thanos.objectStorageConfig.key,
          ),
        ]) +
        container.withPorts([
          { name: 'grpc', containerPort: 10901 },
          { name: 'http', containerPort: 10902 },
        ]) +
        container.withVolumeMounts([
          containerVolumeMount.new('data', '/var/thanos/store', false),
        ]);

      statefulSet.new('thanos-store', 1, c, [], labels) +
      statefulSet.mixin.metadata.withNamespace($._config.namespace) +
      statefulSet.mixin.spec.selector.withMatchLabels(labels) +
      statefulSet.mixin.spec.withServiceName('thanos-store') +
      statefulSet.mixin.spec.template.spec.withVolumes([
        volume.fromEmptyDir('data'),
      ]),
    thanosStoreService:
      local thanosSidecarPort = servicePort.newNamed('grpc', 10901, 'grpc');
      service.new('thanos-store', { app: 'thanos-store' }, thanosSidecarPort) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ app: 'thanos-store' }) +
      service.mixin.spec.withSelector({ app: 'thanos-store' }), 
    serviceMonitorThanosCompactor:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'thanos-compactor',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'thanos-compactor',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          endpoints: [
            {
              port: 'http',
              interval: '30s',
            },
          ],
          selector: {
            matchLabels: {
              app: 'thanos-compactor',
            },
          },
        },
      },

    thanosCompactorService:
      service.new(
        'thanos-compactor',
        { app: 'thanos-compactor' },
        servicePort.newNamed('http', 9090, 'http'),
      ) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ app: 'thanos-compactor' }),

    thanosCompactorStatefulset:
      local statefulSet = k.apps.v1.statefulSet;
      local volume = statefulSet.mixin.spec.template.spec.volumesType;
      local container = statefulSet.mixin.spec.template.spec.containersType;
      local containerEnv = container.envType;
      local containerVolumeMount = container.volumeMountsType;

      local labels = { app: 'thanos-compactor' };

      local c =
        container.new('thanos-compactor', $._config.imageRepos.thanos + ':' + $._config.versions.thanos) +
        container.withArgs([
          'compact',
          '--log.level=debug',
          '--data-dir=/var/thanos/store',
          '--objstore.config=$(OBJSTORE_CONFIG)',
          '--wait',
        ]) +
        container.withEnv([
          containerEnv.fromSecretRef(
            'OBJSTORE_CONFIG',
            $._config.thanos.objectStorageConfig.name,
            $._config.thanos.objectStorageConfig.key,
          ),
        ]) +
        container.withPorts([
          { name: 'http', containerPort: 10902 },
        ]) +
        container.withVolumeMounts([
          containerVolumeMount.new('data', '/var/thanos/store', false),
        ]);

      statefulSet.new('thanos-compactor', 1, c, [], labels) +
      statefulSet.mixin.metadata.withNamespace($._config.namespace) +
      statefulSet.mixin.spec.selector.withMatchLabels(labels) +
      statefulSet.mixin.spec.withServiceName('thanos-compactor') +
      statefulSet.mixin.spec.template.spec.withVolumes([
        volume.fromEmptyDir('data'),
      ]),
  },
}
