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
  kubernetesControlPlane+: {
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
      [{ name: 'https-metrics', port: 10259, targetPort: 10259 }]
    ),

    kubeDnsPrometheusDiscoveryService: service(
      'kube-dns-prometheus-discovery',
      'kube-system',
      { 'app.kubernetes.io/name': 'kube-dns' },
      { 'app.kubernetes.io/name': 'kube-dns' },
      [{ name: 'http-metrics-skydns', port: 10055, targetPort: 10055 }, { name: 'http-metrics-dnsmasq', port: 10054, targetPort: 10054 }]
    ),
  },
}
