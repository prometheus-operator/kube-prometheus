{
  _config+:: {
    namespace: 'default',
    versions+:: { nodeExporter: 'v1.0.1' },
    imageRepos+:: { nodeExporter: 'quay.io/prometheus/node-exporter' },

    nodeExporter+:: {
      listenAddress: '127.0.0.1',
      port: 9100,
      labels: {
        'app.kubernetes.io/name': 'node-exporter',
        'app.kubernetes.io/version': $._config.versions.nodeExporter,
      },
      selectorLabels: {
        [labelName]: $._config.nodeExporter.labels[labelName]
        for labelName in std.objectFields($._config.nodeExporter.labels)
        if !std.setMember(labelName, ['app.kubernetes.io/version'])
      },
    },
  },

  nodeExporter+:: {
    clusterRoleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'node-exporter',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'node-exporter',
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: 'node-exporter',
        namespace: $._config.namespace,
      }],
    },

    clusterRole: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'node-exporter',
      },
      rules: [
        {
          apiGroups: ['authentication.k8s.io'],
          resources: ['tokenreviews'],
          verbs: ['create'],
        },
        {
          apiGroups: ['authorization.k8s.io'],
          resources: ['subjectaccessreviews'],
          verbs: ['create'],
        },
      ],
    },

    daemonset:
      local nodeExporter = {
        name: 'node-exporter',
        image: $._config.imageRepos.nodeExporter + ':' + $._config.versions.nodeExporter,
        args: [
          '--web.listen-address=' + std.join(':', [$._config.nodeExporter.listenAddress, std.toString($._config.nodeExporter.port)]),
          '--path.procfs=/host/proc',
          '--path.sysfs=/host/sys',
          '--path.rootfs=/host/root',
          '--no-collector.wifi',
          '--no-collector.hwmon',
          '--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)',
        ],
        volumeMounts: [
          { name: 'proc', mountPath: '/host/proc', mountPropagation: 'HostToContainer', readOnly: true },
          { name: 'sys', mountPath: '/host/sys', mountPropagation: 'HostToContainer', readOnly: true },
          { name: 'root', mountPath: '/host/root', mountPropagation: 'HostToContainer', readOnly: true },
        ],
        resources: $._config.resources['node-exporter'],
      };

      local proxy = {
        name: 'kube-rbac-proxy',
        image: $._config.imageRepos.kubeRbacProxy + ':' + $._config.versions.kubeRbacProxy,
        args: [
          '--logtostderr',
          '--secure-listen-address=[$(IP)]:' + $._config.nodeExporter.port,
          '--tls-cipher-suites=' + std.join(',', $._config.tlsCipherSuites),
          '--upstream=http://127.0.0.1:' + $._config.nodeExporter.port + '/',
        ],
        env: [
          { name: 'IP', valueFrom: { fieldRef: { fieldPath: 'status.podIP' } } },
        ],
        // Keep `hostPort` here, rather than in the node-exporter container
        // because Kubernetes mandates that if you define a `hostPort` then
        // `containerPort` must match. In our case, we are splitting the
        // host port and container port between the two containers.
        // We'll keep the port specification here so that the named port
        // used by the service is tied to the proxy container. We *could*
        // forgo declaring the host port, however it is important to declare
        // it so that the scheduler can decide if the pod is schedulable.
        ports: [
          { name: 'https', containerPort: $._config.nodeExporter.port, hostPort: $._config.nodeExporter.port },
        ],
        resources: $._config.resources['kube-rbac-proxy'],
        securityContext: {
          runAsUser: 65532,
          runAsGroup: 65532,
          runAsNonRoot: true,
        },
      };

      {
        apiVersion: 'apps/v1',
        kind: 'DaemonSet',
        metadata: {
          name: 'node-exporter',
          namespace: $._config.namespace,
          labels: $._config.nodeExporter.labels,
        },
        spec: {
          selector: { matchLabels: $._config.nodeExporter.selectorLabels },
          updateStrategy: {
            type: 'RollingUpdate',
            rollingUpdate: { maxUnavailable: '10%' },
          },
          template: {
            metadata: { labels: $._config.nodeExporter.labels },
            spec: {
              nodeSelector: { 'kubernetes.io/os': 'linux' },
              tolerations: [{
                operator: 'Exists',
              }],
              containers: [nodeExporter, proxy],
              volumes: [
                { name: 'proc', hostPath: { path: '/proc' } },
                { name: 'sys', hostPath: { path: '/sys' } },
                { name: 'root', hostPath: { path: '/' } },
              ],
              serviceAccountName: 'node-exporter',
              securityContext: {
                runAsUser: 65534,
                runAsNonRoot: true,
              },
              hostPID: true,
              hostNetwork: true,
            },
          },
        },
      },

    serviceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'node-exporter',
        namespace: $._config.namespace,
      },
    },

    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'node-exporter',
        namespace: $._config.namespace,
        labels: $._config.nodeExporter.labels,
      },
      spec: {
        jobLabel: 'app.kubernetes.io/name',
        selector: {
          matchLabels: $._config.nodeExporter.selectorLabels,
        },
        endpoints: [{
          port: 'https',
          scheme: 'https',
          interval: '15s',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          relabelings: [
            {
              action: 'replace',
              regex: '(.*)',
              replacement: '$1',
              sourceLabels: ['__meta_kubernetes_pod_node_name'],
              targetLabel: 'instance',
            },
          ],
          tlsConfig: {
            insecureSkipVerify: true,
          },
        }],
      },
    },

    service: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'node-exporter',
        namespace: $._config.namespace,
        labels: $._config.nodeExporter.labels,
      },
      spec: {
        ports: [
          { name: 'https', targetPort: 'https', port: $._config.nodeExporter.port },
        ],
        selector: $._config.nodeExporter.selectorLabels,
        clusterIP: 'None',
      },
    },
  },
}
