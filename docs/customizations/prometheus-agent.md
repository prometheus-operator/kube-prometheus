### Prometheus-agent mode

***ATTENTION***: Although it is possible to run Prometheus in Agent mode with Prometheus-Operator, it requires strategic merge patches. This practice is not recommended and we do not provide support if Prometheus doesn't work as you expect. **Try it at your own risk!**

```jsonnet mdox-exec="cat examples/prometheus-agent.jsonnet"
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
      prometheus+: {
        resources: {
          requests: { memory: '100Mi' },
        },
        enableFeatures: ['agent'],
      },
    },
    prometheus+: {
      prometheus+: {
        spec+: {
          replicas: 1,
          alerting:: {},
          ruleSelector:: {},
          remoteWrite: [{
            url: 'http://remote-write-url.com',
          }],
          containers+: [
            {
              name: 'prometheus',
              args+: [
                '--config.file=/etc/prometheus/config_out/prometheus.env.yaml',
                '--storage.agent.path=/prometheus',
                '--enable-feature=agent',
                '--web.enable-lifecycle',
              ],
            },
          ],
        },
      },
    },
  };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
```
