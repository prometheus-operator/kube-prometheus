{
  prometheus+:: {
    clusterRole+: {
      rules+: [
        {
          apiGroups: [''],
          resources: ['services', 'endpoints', 'pods'],
          verbs: ['get', 'list', 'watch'],
        },
        {
          apiGroups: ['networking.k8s.io'],
          resources: ['ingresses'],
          verbs: ['get', 'list', 'watch'],
        },
      ],
    },
    // There is no need for specific namespaces RBAC as this addon grants
    // all required permissions for every namespace
    roleBindingSpecificNamespaces:: null,
    roleSpecificNamespaces:: null,
  },
}
