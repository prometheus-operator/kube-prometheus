local kp = import '../jsonnet/kube-prometheus/main.libsonnet';

local clusterName = '{{ $labels.namespace }}/{{ $labels.service }}';
local instanceName = '{{ $labels.namespace }}/{{ $labels.pod}}';
local notificationDescription = 'The minimum notification failure rate to {{ $labels.integration }} sent from any instance in the ' + clusterName + ' cluster is {{ $value | humanizePercentage }}.';
local expected = {
  'AlertmanagerMembersInconsistent/critical': 'Alertmanager ' + instanceName + ' has only found {{ $value }} members of the ' + clusterName + ' cluster.',
  'AlertmanagerClusterFailedToSendAlerts/critical': notificationDescription,
  'AlertmanagerClusterFailedToSendAlerts/warning': notificationDescription,
  'AlertmanagerConfigInconsistent/critical': 'Alertmanager instances within the ' + clusterName + ' cluster have different configurations.',
  'AlertmanagerClusterDown/critical': '{{ $value | humanizePercentage }} of Alertmanager instances within the ' + clusterName + ' cluster have been up for less than half of the last 5m.',
  'AlertmanagerClusterCrashlooping/critical': '{{ $value | humanizePercentage }} of Alertmanager instances within the ' + clusterName + ' cluster have restarted at least 5 times in the last 10m.',
  'AlertmanagerClusterFailedPeers/warning': 'Alertmanager ' + instanceName + ' has {{ $value }} failed peers in the ' + clusterName + ' cluster.',
};
local rules(config) =
  local configured = kp {
    values+:: {
      common+: { namespace: 'monitoring' },
      alertmanager+: { mixin+: { _config+: config } },
    },
  };
  std.flattenArrays([group.rules for group in configured.alertmanager.prometheusRule.spec.groups]);
local key(rule) = rule.alert + '/' + rule.labels.severity;
local descriptions(rs) = {
  [key(rule)]: rule.annotations.description
  for rule in rs
  if std.objectHas(expected, key(rule))
};
local withoutClusterDescriptions(rs) = [
  if std.objectHas(expected, key(rule)) then
    rule { annotations+: { description: null } }
  else rule
  for rule in rs
];
local current = rules({});
local previous = rules({ alertmanagerClusterName: '{{$labels.job}}' });
local customName = '{{ $labels.service }}';
local custom = rules({ alertmanagerClusterName: customName });

assert descriptions(current) == expected : 'Cluster descriptions must use namespace and service';
assert withoutClusterDescriptions(current) == withoutClusterDescriptions(previous) : 'Only cluster descriptions may change';
assert descriptions(custom) == {
  [name]: std.strReplace(expected[name], clusterName, customName)
  for name in std.objectFields(expected)
} : 'The cluster name must remain configurable';
true
