(import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet') + {
  values+:: {
    etcd: {
      ips: [],
      clientCA: null,
      clientKey: null,
      clientCert: null,
      serverName: null,
      insecureSkipVerify: null,
    },
  },
  prometheus+: {
    serviceEtcd: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'etcd',
        namespace: 'kube-system',
        labels: { 'app.kubernetes.io/name': 'etcd' },
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
        labels: { 'app.kubernetes.io/name': 'etcd' },
      },
      subsets: [{
        addresses: [
          { ip: etcdIP }
          for etcdIP in $.values.etcd.ips
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
          'app.kubernetes.io/name': 'etcd',
        },
      },
      spec: {
        jobLabel: 'app.kubernetes.io/name',
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
              [if $.values.etcd.serverName != null then 'serverName']: $.values.etcd.serverName,
              [if $.values.etcd.insecureSkipVerify != null then 'insecureSkipVerify']: $.values.etcd.insecureSkipVerify,
            },
          },
        ],
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'etcd',
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
        namespace: $.values.prometheus.namespace,
      },
      data: {
        'etcd-client-ca.crt': std.base64($.values.etcd.clientCA),
        'etcd-client.key': std.base64($.values.etcd.clientKey),
        'etcd-client.crt': std.base64($.values.etcd.clientCert),
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
