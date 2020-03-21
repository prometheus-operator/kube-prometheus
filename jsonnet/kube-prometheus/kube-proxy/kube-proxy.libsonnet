local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  prometheus+:: {
    serviceKubeProxy:
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;

      local kubeServicePort = servicePort.newNamed('http-metrics', 10249, 10249);

      service.new('kube-proxy', null, kubeServicePort) +
      service.mixin.metadata.withNamespace('kube-system') +
      service.mixin.metadata.withLabels({ 'k8s-app': 'kube-proxy' }) +
      service.mixin.spec.withClusterIp('None') +
      service.mixin.spec.withSelector({ 'k8s-app': 'kube-proxy' }),
    serviceMonitorKubeProxy:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'kube-proxy',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'kube-proxy',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          endpoints: [
            {
              port: 'http-metrics',
              interval: '30s',
            },
          ],
          selector: {
            matchLabels: {
              'k8s-app': 'kube-proxy',
            },
          },
          namespaceSelector: {
            matchNames: [
              'kube-system',
            ],
          },
        },
      },
  },
}
