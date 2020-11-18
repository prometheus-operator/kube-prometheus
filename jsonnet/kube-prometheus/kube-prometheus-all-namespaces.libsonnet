{
  prometheus+:: {
    clusterRole+: {
      rules+: [{
        apiGroups: [''],
        resources: ['services', 'endpoints', 'pods'],
        verbs: ['get', 'list', 'watch'],
      }],
    },
  },
}
