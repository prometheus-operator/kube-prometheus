{
  prometheus+:: {
    kubeDnsPrometheusDiscoveryService: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'kube-dns-prometheus-discovery',
        namespace: 'kube-system',
        labels: { 'app.kubernetes.io/name': 'kube-dns' },
      },
      spec: {
        ports: [
          { name: 'metrics', port: 9153, targetPort: 9153 },
        ],
        selector: { 'app.kubernetes.io/name': 'kube-dns' },
        clusterIP: 'None',
      },
    },
  },
}
