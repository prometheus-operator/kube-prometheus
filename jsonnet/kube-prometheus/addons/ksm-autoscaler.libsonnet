{
  values+:: {
    clusterVerticalAutoscaler: {
      version: '0.8.1',
      image: 'gcr.io/google_containers/cpvpa-amd64:v0.8.1',
      baseCPU: '1m',
      stepCPU: '1m',
      baseMemory: '1Mi',
      stepMemory: '2Mi',
    },
  },
  ksmAutoscaler+: {
    clusterRole: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: { name: 'ksm-autoscaler' },
      rules: [{
        apiGroups: [''],
        resources: ['nodes'],
        verbs: ['list', 'watch'],
      }],
    },

    clusterRoleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: { name: 'ksm-autoscaler' },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'ksm-autoscaler',
      },
      subjects: [{ kind: 'ServiceAccount', name: 'ksm-autoscaler', namespace: $.values.kubeStateMetrics.namespace }],
    },

    roleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBinding',
      metadata: {
        name: 'ksm-autoscaler',
        namespace: $.values.kubeStateMetrics.namespace,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'ksm-autoscaler',
      },
      subjects: [{ kind: 'ServiceAccount', name: 'ksm-autoscaler' }],
    },

    role: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'Role',
      metadata: {
        name: 'ksm-autoscaler',
        namespace: $.values.kubeStateMetrics.namespace,
      },
      rules: [
        {
          apiGroups: ['extensions'],
          resources: ['deployments'],
          verbs: ['patch'],
          resourceNames: ['kube-state-metrics'],
        },
        {
          apiGroups: ['apps'],
          resources: ['deployments'],
          verbs: ['patch'],
          resourceNames: ['kube-state-metrics'],
        },
      ],
    },

    serviceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'ksm-autoscaler',
        namespace: $.values.kubeStateMetrics.namespace,
      },
    },

    deployment:
      local podLabels = { 'app.kubernetes.io/name': 'ksm-autoscaler' };
      local c = {
        name: 'ksm-autoscaler',
        image: $.values.clusterVerticalAutoscaler.image,
        args: [
          '/cpvpa',
          '--target=deployment/kube-state-metrics',
          '--namespace=' + $.values.kubeStateMetrics.namespace,
          '--logtostderr=true',
          '--poll-period-seconds=10',
          '--default-config={"kube-state-metrics":{"requests":{"cpu":{"base":"' + $.values.clusterVerticalAutoscaler.baseCPU +
          '","step":"' + $.values.clusterVerticalAutoscaler.stepCPU +
          '","nodesPerStep":1},"memory":{"base":"' + $.values.clusterVerticalAutoscaler.baseMemory +
          '","step":"' + $.values.clusterVerticalAutoscaler.stepMemory +
          '","nodesPerStep":1}},"limits":{"cpu":{"base":"' + $.values.clusterVerticalAutoscaler.baseCPU +
          '","step":"' + $.values.clusterVerticalAutoscaler.stepCPU +
          '","nodesPerStep":1},"memory":{"base":"' + $.values.clusterVerticalAutoscaler.baseMemory +
          '","step":"' + $.values.clusterVerticalAutoscaler.stepMemory + '","nodesPerStep":1}}}}',
        ],
        resources: {
          requests: { cpu: '20m', memory: '10Mi' },
        },
      };

      {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: 'ksm-autoscaler',
          namespace: $.values.kubeStateMetrics.namespace,
          labels: podLabels,
        },
        spec: {
          replicas: 1,
          selector: { matchLabels: podLabels },
          template: {
            metadata: {
              labels: podLabels,
            },
            spec: {
              containers: [c],
              serviceAccount: 'ksm-autoscaler',
              nodeSelector: { 'kubernetes.io/os': 'linux' },
              securityContext: {
                runAsNonRoot: true,
                runAsUser: 65534,
              },
            },
          },
        },
      },
  },
}
