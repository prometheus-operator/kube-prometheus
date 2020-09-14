local k = import 'github.com/ksonnet/ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

{
  prometheus+: {
    serviceWeaveNet:
      service.new('weave-net', { 'name': 'weave-net' }, servicePort.newNamed('weave-net-metrics', 6782, 6782)) +
      service.mixin.metadata.withNamespace('kube-system') +
      service.mixin.metadata.withLabels({ 'k8s-app': 'weave-net' }) +
      service.mixin.spec.withClusterIp('None'),
    serviceMonitorWeaveNet: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'weave-net',
        labels: {
          'k8s-app': 'weave-net',
        },
        namespace: 'monitoring',
      },
      spec: {
        jobLabel: 'k8s-app',
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
            'k8s-app': 'weave-net',
          },
        },
      },
    },
  },
  prometheusRules+: {
    groups+: [
      {
        name: 'weave-net',
        rules: [
          {
            alert: 'WeaveNetIPAMSplitBrain',
            expr: 'max(weave_ipam_unreachable_percentage) - min(weave_ipam_unreachable_percentage) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Percentage of all IP addresses owned by unreachable peers is not same for every node.',
              description: 'actionable: Weave Net network has a split brain problem. Please find the problem and fix it.',
            },
          },
          {
            alert: 'WeaveNetIPAMUnreachable',
            expr: 'weave_ipam_unreachable_percentage > 25',
            'for': '10m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Percentage of all IP addresses owned by unreachable peers is above threshold.',
              description: 'actionable: Please find the problem and fix it.',
            },
          },
          {
            alert: 'WeaveNetIPAMPendingAllocates',
            expr: 'sum(weave_ipam_pending_allocates) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Number of pending allocates is above the threshold.',
              description: 'actionable: Please find the problem and fix it.',
            },
          },
          {
            alert: 'WeaveNetIPAMPendingClaims',
            expr: 'sum(weave_ipam_pending_claims) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Number of pending claims is above the threshold.',
              description: 'actionable: Please find the problem and fix it.',
            },
          },
          {
            alert: 'WeaveNetFastDPFlowsLow',
            expr: 'sum(weave_flows) < 15000',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Number of FastDP flows is below the threshold.',
              description: 'actionable: Please find the reason for FastDP flows to go below the threshold and fix it.',
            },
          },
          {
            alert: 'WeaveNetFastDPFlowsOff',
            expr: 'sum(weave_flows == bool 0) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'FastDP flows is zero.',
              description: 'actionable: Please find the reason for FastDP flows to be off and fix it.',
            },
          },
          {
            alert: 'WeaveNetHighConnectionTerminationRate',
            expr: 'rate(weave_connection_terminations_total[5m]) > 0.1',
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'A lot of connections are getting terminated.',
              description: 'actionable: Please find the reason for the high connection termination rate and fix it.',
            },
          },
          {
            alert: 'WeaveNetConnectionsConnecting',
            expr: 'sum(weave_connections{state="connecting"}) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'A lot of connections are in connecting state.',
              description: 'actionable: Please find the reason for this and fix it.',
            },
          },
          {
            alert: 'WeaveNetConnectionsRetying',
            expr: 'sum(weave_connections{state="retrying"}) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'A lot of connections are in retrying state.',
              description: 'actionable: Please find the reason for this and fix it.',
            },
          },
          {
            alert: 'WeaveNetConnectionsPending',
            expr: 'sum(weave_connections{state="pending"}) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'A lot of connections are in pending state.',
              description: 'actionable: Please find the reason for this and fix it.',
            },
          },
          {
            alert: 'WeaveNetConnectionsFailed',
            expr: 'sum(weave_connections{state="failed"}) > 0',
            'for': '3m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'A lot of connections are in failed state.',
              description: 'actionable: Please find the reason and fix it.',
            },
          },
        ],
      },
    ],
  },
  grafanaDashboards+:: {
    'weave-net.json': (import './grafana-weave-net.json'),
    'weave-net-cluster.json': (import './grafana-weave-net-cluster.json'),
  },
}
