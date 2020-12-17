local service(name, namespace, labels, selector, ports) = {
  apiVersion: 'v1',
  kind: 'Service',
  metadata: {
    name: name,
    namespace: namespace,
    labels: labels,
  },
  spec: {
    ports+: ports,
    selector: selector,
    clusterIP: 'None',
  },
};

{

  prometheus+: {
    kubeControllerManagerPrometheusDiscoveryService: service(
      'kube-controller-manager-prometheus-discovery',
      'kube-system',
      { 'app.kubernetes.io/name': 'kube-controller-manager' },
      { 'app.kubernetes.io/name': 'kube-controller-manager' },
      [{ name: 'https-metrics', port: 10257, targetPort: 10257 }]
    ),

    kubeSchedulerPrometheusDiscoveryService: service(
      'kube-scheduler-prometheus-discovery',
      'kube-system',
      { 'app.kubernetes.io/name': 'kube-scheduler' },
      { 'app.kubernetes.io/name': 'kube-scheduler' },
      [{ name: 'https-metrics', port: 10259, targetPort: 10259 }],
    ),

    serviceMonitorKubeScheduler+: {
      spec+: {
        selector+: {
          matchLabels: {
            'app.kubernetes.io/name': 'kube-scheduler',
          },
        },
      },
    },

    serviceMonitorKubeControllerManager+: {
      spec+: {
        selector+: {
          matchLabels: {
            'app.kubernetes.io/name': 'kube-controller-manager',
          },
        },
      },
    },

  },
}
