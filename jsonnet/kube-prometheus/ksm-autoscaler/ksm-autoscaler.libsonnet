local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  _config+:: {
    versions+:: {
      clusterVerticalAutoscaler: "v0.8.1"
    },

    imageRepos+:: {
      clusterVerticalAutoscaler: 'gcr.io/google_containers/cpvpa-amd64'
    },

    kubeStateMetrics+:: {
      stepCPU: '1m',
      stepMemory: '2Mi',
    },
  },
  ksmAutoscaler+:: {
    clusterRole:
      local clusterRole = k.rbac.v1.clusterRole;
      local rulesType = clusterRole.rulesType;

      local rules = [
        rulesType.new() +
        rulesType.withApiGroups(['']) +
        rulesType.withResources([
          'nodes',
        ]) +
        rulesType.withVerbs(['list', 'watch']),
      ];

      clusterRole.new() +
      clusterRole.mixin.metadata.withName('ksm-autoscaler') +
      clusterRole.withRules(rules),

    clusterRoleBinding:
      local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

      clusterRoleBinding.new() +
      clusterRoleBinding.mixin.metadata.withName('ksm-autoscaler') +
      clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      clusterRoleBinding.mixin.roleRef.withName('ksm-autoscaler') +
      clusterRoleBinding.mixin.roleRef.mixinInstance({ kind: 'ClusterRole' }) +
      clusterRoleBinding.withSubjects([{ kind: 'ServiceAccount', name: 'ksm-autoscaler', namespace: $._config.namespace }]),

    roleBinding:
      local roleBinding = k.rbac.v1.roleBinding;
  
      roleBinding.new() +
      roleBinding.mixin.metadata.withName('ksm-autoscaler') +
      roleBinding.mixin.metadata.withNamespace($._config.namespace) +
      roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      roleBinding.mixin.roleRef.withName('ksm-autoscaler') +
      roleBinding.mixin.roleRef.mixinInstance({ kind: 'Role' }) +
      roleBinding.withSubjects([{ kind: 'ServiceAccount', name: 'ksm-autoscaler' }]),

    role:
      local role = k.rbac.v1.role;
      local rulesType = role.rulesType;
  
      local extensionsRule = rulesType.new() +
                             rulesType.withApiGroups(['extensions']) +
                             rulesType.withResources([
                               'deployments',
                             ]) +
                             rulesType.withVerbs(['patch']) +
                             rulesType.withResourceNames(['kube-state-metrics']);
  
      local appsRule = rulesType.new() +
                       rulesType.withApiGroups(['apps']) +
                       rulesType.withResources([
                         'deployments',
                       ]) +
                       rulesType.withVerbs(['patch']) +
                       rulesType.withResourceNames(['kube-state-metrics']);
  
      local rules = [extensionsRule, appsRule];
  
      role.new() +
      role.mixin.metadata.withName('ksm-autoscaler') +
      role.mixin.metadata.withNamespace($._config.namespace) +
      role.withRules(rules),
  
    serviceAccount:
      local serviceAccount = k.core.v1.serviceAccount;
  
      serviceAccount.new('ksm-autoscaler') +
      serviceAccount.mixin.metadata.withNamespace($._config.namespace),
    deployment:
      local deployment = k.apps.v1.deployment;
      local container = deployment.mixin.spec.template.spec.containersType;
      local podSelector = deployment.mixin.spec.template.spec.selectorType;
      local podLabels = { app: 'ksm-autoscaler' };
  
      local kubeStateMetricsAutoscaler =
        container.new('ksm-autoscaler', $._config.imageRepos.clusterVerticalAutoscaler + ':' + $._config.versions.clusterVerticalAutoscaler) +
        container.withArgs([
          '/cpvpa',
          '--target=deployment/kube-state-metrics',
          '--namespace=' + $._config.namespace,
          '--logtostderr=true',
          '--poll-period-seconds=10',
          '--default-config={"kube-state-metrics":{"requests":{"cpu":{"base":"' + $._config.kubeStateMetrics.baseCPU + '","step":"' + $._config.kubeStateMetrics.stepCPU + '","nodesPerStep":1},"memory":{"base":"' + $._config.kubeStateMetrics.baseMemory + '","step":"' + $._config.kubeStateMetrics.stepMemory + '","nodesPerStep":1}},"limits":{"cpu":{"base":"' + $._config.kubeStateMetrics.baseCPU + '","step":"' + $._config.kubeStateMetrics.stepCPU + '","nodesPerStep":1},"memory":{"base":"' + $._config.kubeStateMetrics.baseMemory + '","step":"' + $._config.kubeStateMetrics.stepMemory + '","nodesPerStep":1}}}}'
        ]) +
        container.mixin.resources.withRequests({cpu: '20m', memory: '10Mi'}); 
  
      local c = [kubeStateMetricsAutoscaler];
  
      deployment.new('ksm-autoscaler', 1, c, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.template.spec.withNodeSelector({ 'kubernetes.io/os': 'linux' }) +
      deployment.mixin.spec.template.spec.securityContext.withRunAsNonRoot(true) +
      deployment.mixin.spec.template.spec.securityContext.withRunAsUser(65534) +
      deployment.mixin.spec.template.spec.withServiceAccountName('ksm-autoscaler'),
  },
}
