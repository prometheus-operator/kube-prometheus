local defaults = {
  local defaults = self,
  namespace: error 'must provide namespace',

  name: error 'must provide name',
  namespaces: ['default', 'kube-system', defaults.namespace],
  commonLabels:: {
    'app.kubernetes.io/name': 'prometheus',
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'prometheus',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  } + { prometheus: defaults.name },
};


function(params) {
  local p = self,
  config:: defaults + params,

  namespaced: {
    role:
      local newSpecificRole(namespace) = {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'Role',
        metadata: {
          name: 'prometheus-' + p.config.name,
          namespace: namespace,
          labels: p.config.commonLabels,
        },
        rules: [
          {
            apiGroups: [''],
            resources: ['services', 'endpoints', 'pods'],
            verbs: ['get', 'list', 'watch'],
          },
          {
            apiGroups: ['extensions'],
            resources: ['ingresses'],
            verbs: ['get', 'list', 'watch'],
          },
        ],
      };
      {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'RoleList',
        items: [newSpecificRole(x) for x in p.config.namespaces],
      },

    roleBinding:
      local newSpecificRoleBinding(namespace) = {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'RoleBinding',
        metadata: {
          name: 'prometheus-' + p.config.name,
          namespace: namespace,
          labels: p.config.commonLabels,
        },
        roleRef: {
          apiGroup: 'rbac.authorization.k8s.io',
          kind: 'Role',
          name: 'prometheus-' + p.config.name,
        },
        subjects: [{
          kind: 'ServiceAccount',
          name: 'prometheus-' + p.config.name,
          namespace: p.config.namespace,
        }],
      };
      {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'RoleBindingList',
        items: [newSpecificRoleBinding(x) for x in p.config.namespaces],
      },
  },

  cluster: {
    clusterRole: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'prometheus-' + p.config.name,
        labels: p.config.commonLabels,
      },
      rules: [
        {
          apiGroups: [''],
          resources: ['nodes/metrics'],
          verbs: ['get'],
        },
        {
          nonResourceURLs: ['/metrics'],
          verbs: ['get'],
        },
      ],
    },

    clusterRoleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'prometheus-' + p.config.name,
        labels: p.config.commonLabels,
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'prometheus-' + p.config.name,
      },
      subjects: [{
        kind: 'ServiceAccount',
        name: 'prometheus-' + p.config.name,
        namespace: p.config.namespace,
      }],
    },
  },
}
