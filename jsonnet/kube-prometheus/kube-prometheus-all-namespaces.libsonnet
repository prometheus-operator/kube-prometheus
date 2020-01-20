local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
    prometheus+:: {
        clusterRole+: {
            rules+: 
            local role = k.rbac.v1.role;
            local policyRule = role.rulesType;
            local rule = policyRule.new() +
                            policyRule.withApiGroups(['']) +
                            policyRule.withResources([
                            'services',
                            'endpoints',
                            'pods',
                            ]) +
                            policyRule.withVerbs(['get', 'list', 'watch']);
            [rule]
      },
    }
}