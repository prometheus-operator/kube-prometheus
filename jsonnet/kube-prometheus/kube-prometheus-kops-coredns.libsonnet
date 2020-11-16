{
  prometheus+:: {
    kubeDnsPrometheusDiscoveryService: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'kube-dns-prometheus-discovery',
        namespace: 'kube-system',
        labels: { 'k8s-app': 'kube-dns' },
      },
      spec: {
        ports: [
          { name: 'metrics', port: 9153, targetPort: 9153 },
        ],
        selector: { 'k8s-app': 'kube-dns' },
        clusterIP: 'None',
      },
    },
  },
}
