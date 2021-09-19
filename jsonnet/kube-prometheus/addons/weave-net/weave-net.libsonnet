{
  prometheus+: {
    local p = self,
    serviceWeaveNet: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'weave-net',
        namespace: 'kube-system',
        labels: { 'app.kubernetes.io/name': 'weave-net' },
      },
      spec: {
        ports: [
          { name: 'weave-net-metrics', targetPort: 6782, port: 6782 },
        ],
        selector: { name: 'weave-net' },
        clusterIP: 'None',
      },
    },
    serviceMonitorWeaveNet: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'weave-net',
        labels: {
          'app.kubernetes.io/name': 'weave-net',
        },
        namespace: 'monitoring',
      },
      spec: {
        jobLabel: 'app.kubernetes.io/name',
        endpoints: [
          {
            port: 'weave-net-metrics',
            path: '/metrics',
            interval: '15s',
          },
        ],
        namespaceSelector: {
          matchNames: [
            'kube-system',
          ],
        },
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'weave-net',
          },
        },
      },
    },
    prometheusRuleWeaveNet: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        labels: p._config.mixin.ruleLabels,
        name: 'weave-net-rules',
        namespace: p._config.namespace,
      },
      spec: {
        groups: [{
          name: 'weave-net',
          rules: (import './alerts.libsonnet'),
        }],
      },
    },
    mixin+:: {
      grafanaDashboards+:: {
        'weave-net.json': (import './grafana-weave-net.json'),
        'weave-net-cluster.json': (import './grafana-weave-net-cluster.json'),
      },
    },
  },
}
