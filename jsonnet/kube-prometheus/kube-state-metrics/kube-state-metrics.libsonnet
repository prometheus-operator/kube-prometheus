{
  kubeStateMetrics+:: (import 'kube-state-metrics/kube-state-metrics.libsonnet') +
                      {
                        local ksm = self,
                        name:: 'kube-state-metrics',
                        namespace:: 'monitoring',
                        version:: '1.9.4',  //$._config.versions.kubeStateMetrics,
                        image:: 'quay.io/coreos/kube-state-metrics:v' + ksm.version,
                        serviceMonitor: {
                          apiVersion: 'monitoring.coreos.com/v1',
                          kind: 'ServiceMonitor',
                          metadata: {
                            name: ksm.name,
                            namespace: ksm.namespace,
                            labels: ksm.commonLabels,
                          },
                          spec: {
                            jobLabel: 'app.kubernetes.io/name',
                            selector: {
                              matchLabels: ksm.commonLabels,
                            },
                            endpoints: [
                              {
                                port: 'http-metrics',
                                interval: '30s',
                                scrapeTimeout: '30s',
                                honorLabels: true,
                                relabelings: [
                                  {
                                    regex: '(pod|service|endpoint|namespace)',
                                    action: 'labeldrop',
                                  },
                                ],
                              },
                              {
                                port: 'telemetry',
                                interval: '30s',
                              },
                            ],
                          },
                        },
                      },
}
