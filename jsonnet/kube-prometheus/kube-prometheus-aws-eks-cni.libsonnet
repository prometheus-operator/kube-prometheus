local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

{
  prometheus+: {
    kubePrometheusAwsEksCniMetricService:
        service.new('aws-eks-cni', { 'k8s-app' : 'eks-cni' } , servicePort.newNamed('cni-metrics-port', 61678, 61678)) +
        service.mixin.metadata.withNamespace('kube-system') +
        service.mixin.metadata.withLabels({ 'k8s-app': 'eks-cni' }) +
        service.mixin.spec.withClusterIp('None'),
  },
}
