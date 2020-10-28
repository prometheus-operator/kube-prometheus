local k = import 'github.com/ksonnet/ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local statefulSet = k.apps.v1.statefulSet;
local affinity = statefulSet.mixin.spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecutionType;
local matchExpression = affinity.mixin.podAffinityTerm.labelSelector.matchExpressionsType;

{
  _config+:: {
    prometheus+:: {
      namespace: $._config.namespace,
    },

    alertmanager+:: {
      namespace: $._config.namespace,
    },
  },

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
        antiaffinity('alertmanager', [$._config.alertmanager.name], $._config.alertmanager.namespace),
    },
  },

  prometheus+: {
    prometheus+: {
      spec+:
        antiaffinity('prometheus', [$._config.prometheus.name], $._config.prometheus.namespace),
    },
  },
}
