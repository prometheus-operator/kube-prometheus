local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local statefulSet = k.apps.v1.statefulSet;
local affinity = statefulSet.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;

{
  local antiaffinity(key, values, namespace) = {
    affinity: {
      podAntiAffinity: {
        preferredDuringSchedulingIgnoredDuringExecution: [
          affinity.new() +
          affinity.withWeight(100) +
          affinity.mixin.podAffinityTerm.withNamespaces(namespace) +
          affinity.mixin.podAffinityTerm.withTopologyKey('kubernetes.io/hostname') +
          affinity.mixin.podAffinityTerm.labelSelector.withMatchExpressions([
            matchExpression.new() +
            matchExpression.withKey(key) +
            matchExpression.withOperator('In') +
            matchExpression.withValues(values),
          ]),
        ],
      },
    },
  },

  alertmanager+:: {
    alertmanager+: {
      spec+:
        antiaffinity('alertmanager', [$._config.alertmanager.name], $._config.namespace),
    },
  },

  prometheus+: {
    local p = self,

    prometheus+: {
      spec+:
        antiaffinity('prometheus', [p.name], p.namespace),
    },
  },
}
