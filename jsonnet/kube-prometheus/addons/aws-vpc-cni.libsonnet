{
  values+:: {
    awsVpcCni: {
      // `minimumWarmIPs` should be inferior or equal to `WARM_IP_TARGET`.
      //
      // References:
      // https://github.com/aws/amazon-vpc-cni-k8s/blob/v1.9.0/docs/eni-and-ip-target.md
      // https://github.com/aws/amazon-vpc-cni-k8s/blob/v1.9.0/pkg/ipamd/ipamd.go#L61-L71
      minimumWarmIPs: 10,
      minimumWarmIPsTime: '10m',
    },
  },
  kubernetesControlPlane+: {
    serviceAwsVpcCni: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'aws-node',
        namespace: 'kube-system',
        labels: { 'app.kubernetes.io/name': 'aws-node' },
      },
      spec: {
        ports: [
          {
            name: 'cni-metrics-port',
            port: 61678,
            targetPort: 61678,
          },
        ],
        selector: { 'app.kubernetes.io/name': 'aws-node' },
        clusterIP: 'None',
      },
    },

    serviceMonitorAwsVpcCni: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'aws-node',
        namespace: $.values.kubernetesControlPlane.namespace,
        labels: {
          'app.kubernetes.io/name': 'aws-node',
        },
      },
      spec: {
        jobLabel: 'app.kubernetes.io/name',
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'aws-node',
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
            relabelings: [
              {
                action: 'replace',
                regex: '(.*)',
                replacement: '$1',
                sourceLabels: ['__meta_kubernetes_pod_node_name'],
                targetLabel: 'instance',
              },
            ],
          },
        ],
      },
    },

    prometheusRuleAwsVpcCni: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        labels: {
          'app.kubernetes.io/name': 'prometheus-vpc-cni-rules',
          'app.kubernetes.io/component': 'prometheus',
          'app.kubernetes.io/part-of': 'kube-prometheus',
        },
        name: 'aws-vpc-cni-rules',
        namespace: $.values.prometheus.namespace,
      },
      spec: {
        groups: [
          {
            name: 'aws-vpc-cni.rules',
            rules: [
              {
                expr: 'sum by(instance) (awscni_total_ip_addresses) - sum by(instance) (awscni_assigned_ip_addresses) < %s' % $.values.awsVpcCni.minimumWarmIPs,
                labels: {
                  severity: 'critical',
                },
                annotations: {
                  summary: 'AWS VPC CNI has a low warm IP pool',
                  description: |||
                    Instance {{ $labels.instance }} has only {{ $value }} warm IPs which is lower than set threshold of %s.
                    It could mean the current subnet is out of available IP addresses or the CNI is unable to request them from the EC2 API.
                  ||| % $.values.awsVpcCni.minimumWarmIPs,
                },
                'for': $.values.awsVpcCni.minimumWarmIPsTime,
                alert: 'AwsVpcCniWarmIPsLow',
              },
            ],
          },
        ],
      },
    },
  },
}
