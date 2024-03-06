// user facing roles for monitors, probe, and rules
// ref: https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles
{
  prometheusOperator+: {
    local po = self,
    clusterRoleView: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: po._metadata {
        name: 'monitoring-view',
        namespace:: null,
        labels+: {
          'rbac.authorization.k8s.io/aggregate-to-view': 'true',
        },
      },
      rules: [
        {
          apiGroups: [
            'monitoring.coreos.com',
          ],
          resources: [
            'podmonitors',
            'probes',
            'prometheusrules',
            'servicemonitors',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
      ],
    },
    clusterRoleEdit: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: po._metadata {
        name: 'monitoring-edit',
        namespace:: null,
        labels+: {
          'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
        },
      },
      rules: [
        {
          apiGroups: [
            'monitoring.coreos.com',
          ],
          resources: [
            'podmonitors',
            'probes',
            'prometheusrules',
            'servicemonitors',
          ],
          verbs: [
            'create',
            'delete',
            'deletecollection',
            'patch',
            'update',
          ],
        },
      ],
    },
  },
}
