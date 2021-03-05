(import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet') + {
  _config+:: {
    etcd: {
      ips: [],
      clientCA: null,
      clientKey: null,
      clientCert: null,
      serverName: null,
      insecureSkipVerify: null,
    },
  },
  prometheus+:: {
    serviceEtcd: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'etcd',
        namespace: 'kube-system',
        labels: { 'k8s-app': 'etcd' },
      },
      spec: {
        ports: [
          { name: 'metrics', targetPort: 2379, port: 2379 },
        ],
        clusterIP: 'None',
      },
    },
    endpointsEtcd: {
      apiVersion: 'v1',
      kind: 'Endpoints',
      metadata: {
        name: 'etcd',
        namespace: 'kube-system',
        labels: { 'k8s-app': 'etcd' },
      },
      subsets: [{
        addresses: [
          { ip: etcdIP }
          for etcdIP in $._config.etcd.ips
        ],
        ports: [
          { name: 'metrics', port: 2379, protocol: 'TCP' },
        ],
      }],
    },
    serviceMonitorEtcd: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'etcd',
        namespace: 'kube-system',
        labels: {
          'k8s-app': 'etcd',
        },
      },
      spec: {
        jobLabel: 'k8s-app',
        endpoints: [
          {
            port: 'metrics',
            interval: '30s',
            scheme: 'https',
            // Prometheus Operator (and Prometheus) allow us to specify a tlsConfig. This is required as most likely your etcd metrics end points is secure.
            tlsConfig: {
              caFile: '/etc/prometheus/secrets/kube-etcd-client-certs/etcd-client-ca.crt',
              keyFile: '/etc/prometheus/secrets/kube-etcd-client-certs/etcd-client.key',
              certFile: '/etc/prometheus/secrets/kube-etcd-client-certs/etcd-client.crt',
              [if $._config.etcd.serverName != null then 'serverName']: $._config.etcd.serverName,
              [if $._config.etcd.insecureSkipVerify != null then 'insecureSkipVerify']: $._config.etcd.insecureSkipVerify,
            },
          },
        ],
        selector: {
          matchLabels: {
            'k8s-app': 'etcd',
          },
        },
      },
    },
    secretEtcdCerts: {
      // Prometheus Operator allows us to mount secrets in the pod. By loading the secrets as files, they can be made available inside the Prometheus pod.
      apiVersion: 'v1',
      kind: 'Secret',
      type: 'Opaque',
      metadata: {
        name: 'kube-etcd-client-certs',
        namespace: $._config.namespace,
      },
      data: {
        'etcd-client-ca.crt': std.base64($._config.etcd.clientCA),
        'etcd-client.key': std.base64($._config.etcd.clientKey),
        'etcd-client.crt': std.base64($._config.etcd.clientCert),
      },
    },
    prometheus+: {
      // Reference info: https://coreos.com/operators/prometheus/docs/latest/api.html#prometheusspec
      spec+: {
        secrets+: [$.prometheus.secretEtcdCerts.metadata.name],
      },
    },
  },
}
