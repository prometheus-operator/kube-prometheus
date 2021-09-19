(import '../addons/aws-vpc-cni.libsonnet') +
(import '../addons/managed-cluster.libsonnet') + {
  kubernetesControlPlane+: {
    serviceMonitorCoreDNS+: {
      spec+: {
        endpoints: [
          {
            bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
            interval: '15s',
            targetPort: 9153,
          },
        ],
      },
    },
  },
}
