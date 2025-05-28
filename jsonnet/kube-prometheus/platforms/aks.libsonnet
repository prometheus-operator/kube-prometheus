(import '../addons/managed-cluster.libsonnet') + {
  values+:: {
    prometheusAdapter+: {
      config+: {
        resourceRules:: null,
      },
    },
  },

  prometheusAdapter+:: {
    apiService:: null,
  },

  kubernetesControlPlane+: {
    kubeDnsPrometheusStackService: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'kube-dns-metrics',
        namespace: 'kube-system',
        labels: {
          'k8s-app': 'kube-dns',
          // This label is used as the job name in Prometheus
          'app.kubernetes.io/name': 'kube-dns',
        },
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
