local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

{
  prometheus+: {
    serviceWeaveNet:
      service.new('weave-net', { 'k8s-app': 'weave-net' }, servicePort.newNamed('weave-net-metrics', 6782, 6782)) +
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
            port: 'weave-metrics',
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
              summary: 'WeaveNetIPAM has a split brain. Go to the below prometheus link for details.',
              description: 'Actionable: Every node should see same unreachability percentage. Please check and fix why it is not so.',
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
              summary: 'WeaveNetIPAM unreachability percentage is above threshold. Go to the below prometheus link for details.',
              description: 'Actionable: Find why the unreachability threshold have increased from threshold and fix it. WeaveNet is responsible to keep it under control. Weave rm peer deployment can help clean things.',
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
              summary: 'WeaveNet IPAM has pending allocates. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason for IPAM allocates to be in pending state and fix it.',
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
              summary: 'WeaveNet IPAM has pending claims. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason for IPAM claims to be in pending state and fix it.',
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
              summary: 'WeaveNet total FastDP flows is below threshold. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason for fast dp flows dropping below the threshold.',
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
              summary: 'WeaveNet FastDP flows is not happening in some or all nodes. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason for fast dp being off.',
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
              summary: 'A lot of connections are getting terminated. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason for high connection termination rate and fix it.',
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
              summary: 'A lot of connections are in connecting state. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason and fix it.',
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
              summary: 'A lot of connections are in retrying state. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason and fix it.',
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
              summary: 'A lot of connections are in pending state. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason and fix it.',
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
              summary: 'A lot of connections are in failed state. Go to the below prometheus link for details.',
              description: 'Actionable: Find the reason and fix it.',
            },
          },
        ],
      },
    ],
  },
  grafanaDashboards+:: {
    'weavenet.json': (import 'grafana-weavenet.json'),
    'weavenet-cluster.json': (import 'grafana-weavenet-cluster.json'),
  },
}
