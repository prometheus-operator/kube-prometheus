local k = import 'github.com/ksonnet/ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

{
  _config+:: {
    eks: {
      minimumAvailableIPs: 10,
      minimumAvailableIPsTime: '10m'
    }
  },
  prometheus+: {
    serviceMonitorCoreDNS+: {
        spec+: {
          endpoints: [
            {
              bearerTokenFile: "/var/run/secrets/kubernetes.io/serviceaccount/token",
              interval: "15s",
              targetPort: 9153
            }
          ]
        },
      },
    AwsEksCniMetricService:
        service.new('aws-node', { 'k8s-app' : 'aws-node' } , servicePort.newNamed('cni-metrics-port', 61678, 61678)) +
        service.mixin.metadata.withNamespace('kube-system') +
        service.mixin.metadata.withLabels({ 'k8s-app': 'aws-node' }) +
        service.mixin.spec.withClusterIp('None'),
    serviceMonitorAwsEksCNI:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'awsekscni',
          namespace: $._config.namespace,
          labels: {
            'k8s-app': 'eks-cni',
          },
        },
        spec: {
          jobLabel: 'k8s-app',
          selector: {
            matchLabels: {
              'k8s-app': 'aws-node',
            },
          },
          namespaceSelector: {
            matchNames: [
              'kube-system',
            ],
          },
          endpoints: [
            {
              port: 'cni-metrics-port',
              interval: '30s',
              path: '/metrics',
            },
          ],
        },
      },
  },
  prometheusRules+: {
    groups+: [
      {
        name: 'kube-prometheus-eks.rules',
        rules: [
          {
            expr: 'sum by(instance) (awscni_total_ip_addresses) - sum by(instance) (awscni_assigned_ip_addresses) < %s' % $._config.eks.minimumAvailableIPs,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Instance {{ $labels.instance }} has less than 10 IPs available.'
            },
            'for': $._config.eks.minimumAvailableIPsTime,
            alert: 'EksAvailableIPs'
          },
        ],
      },
    ],
  },
}
