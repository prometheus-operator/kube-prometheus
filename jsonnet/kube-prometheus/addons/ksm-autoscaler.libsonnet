{
  values+:: {
    versions+:: { clusterVerticalAutoscaler: '0.8.1' },
    imageRepos+:: { clusterVerticalAutoscaler: 'gcr.io/google_containers/cpvpa-amd64' },

    kubeStateMetrics+:: {
      stepCPU: '1m',
      stepMemory: '2Mi',
    },
  },
  ksmAutoscaler+:: {
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
      subjects: [{ kind: 'ServiceAccount', name: 'ksm-autoscaler', namespace: $.values.common.namespace }],
    },

    roleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBinding',
      metadata: {
        name: 'ksm-autoscaler',
        namespace: $.values.common.namespace,
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
        namespace: $.values.common.namespace,
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
        namespace: $.values.common.namespace,
      },
    },

    deployment:
      local podLabels = { app: 'ksm-autoscaler' };
      local c = {
        name: 'ksm-autoscaler',
        image: $.values.imageRepos.clusterVerticalAutoscaler + ':v' + $.values.versions.clusterVerticalAutoscaler,
        args: [
          '/cpvpa',
          '--target=deployment/kube-state-metrics',
          '--namespace=' + $.values.common.namespace,
          '--logtostderr=true',
          '--poll-period-seconds=10',
          '--default-config={"kube-state-metrics":{"requests":{"cpu":{"base":"' + $.values.kubeStateMetrics.baseCPU + '","step":"' + $.values.kubeStateMetrics.stepCPU + '","nodesPerStep":1},"memory":{"base":"' + $.values.kubeStateMetrics.baseMemory + '","step":"' + $.values.kubeStateMetrics.stepMemory + '","nodesPerStep":1}},"limits":{"cpu":{"base":"' + $.values.kubeStateMetrics.baseCPU + '","step":"' + $.values.kubeStateMetrics.stepCPU + '","nodesPerStep":1},"memory":{"base":"' + $.values.kubeStateMetrics.baseMemory + '","step":"' + $.values.kubeStateMetrics.stepMemory + '","nodesPerStep":1}}}}',
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
          namespace: $.values.common.namespace,
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
