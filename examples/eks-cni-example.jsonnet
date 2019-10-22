local kp = (import 'kube-prometheus/kube-prometheus-eks.libsonnet') + {
  local service = kp.core.v1.service,
  local servicePort = kp.core.v1.service.mixin.spec.portsType,
  _config+:: {
    namespace: 'monitoring',
  },
  prometheus+: {
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
          namespace: kp.namespace,
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
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
