local defaults = {
  /* name of rule groups to exclude */
  excludedRuleGroups: [],
  /* Rule match is based on field "alert" or "record" for excludedRules and patchedRules.
   * When multiple match is found, we can use a "index" field to distingush each rule,
   * which represents their order of appearance. For example, if we have two rules:
   * [
   *  {
   *    name: 'alertmanager.rules',
   *    rules: [
   *      {
   *        alert: 'A',
   *        field: 'A0 rule',
   *        labels: {
   *          severity: 'warning',
   *        },
   *      },
   *      {
   *        alert: 'A',
   *        field: 'A1 rule',
   *        labels: {
   *          severity: 'warning',
   *        },
   *      },
   *    ],
   *  },
   * ]
   * We can use index 1 to choose "A1 rule" for patching, as shown in the example below:
   * [
   *   {
   *     name: 'alertmanager.rules',
   *     rules: [
   *       {
   *         alert: 'A',
   *         index: 1,
   *         patch: 'A1',
   *         labels: {
   *           severity: 'warning',
   *         },
   *       },
   *     ],
   *   },
   * ]
   */
  excludedRules: [],
  patchedRules: [],
};


local deleteIndex(rule) = {
  [k]: rule[k]
  for k in std.objectFields(rule)
  if k != 'index'
};


local patchOrExcludeRule(rule, ruleSet, operation) =
  if std.length(ruleSet) == 0 then
    [deleteIndex(rule)]
  /* 2 rules match when the name of the patch is a prefix of the name of the rule to patch. */
  else if ((('alert' in rule && 'alert' in ruleSet[0]) && std.startsWith(rule.alert, ruleSet[0].alert)) ||
           (('record' in rule && 'record' in ruleSet[0]) && std.startsWith(rule.record, ruleSet[0].record))) &&
          (!('index' in ruleSet[0]) || (('index' in ruleSet[0]) && (ruleSet[0].index == rule.index))) then
    if operation == 'patch' then
      local patch = {
        [k]: ruleSet[0][k]
        for k in std.objectFields(ruleSet[0])
        if k != 'alert' && k != 'record' && k != 'index'
      };
      [deleteIndex(std.mergePatch(rule, patch))]
    else  // equivalnt to operation == 'exclude'
      []

  else
    [] + patchOrExcludeRule(rule, ruleSet[1:], operation);


local sameRuleName(rule1, rule2) =
  if ('alert' in rule1 && 'alert' in rule2) then
    rule1.alert == rule2.alert
  else if ('record' in rule1 && 'record' in rule2) then
    rule1.record == rule2.record
  else
    false;

local indexRules(lastRule, ruleSet) =
  if std.length(ruleSet) == 0 then
    []
  else if (lastRule != null) && sameRuleName(lastRule, ruleSet[0]) then
    local updatedRule = std.mergePatch(ruleSet[0], { index: lastRule.index + 1 });
    [updatedRule] + indexRules(updatedRule, ruleSet[1:])
  else
    local updatedRule = std.mergePatch(ruleSet[0], { index: 0 });
    [updatedRule] + indexRules(updatedRule, ruleSet[1:]);

local ruleName(rule) =
  if ('alert' in rule) then
    rule.alert
  else if ('record' in rule) then
    rule.record
  else
    assert false : 'rule should have either "alert" or "record" field' + std.toString(rule);
    '';

local patchOrExcludeRuleGroup(group, groupSet, operation) =
  if std.length(groupSet) == 0 then
    [group.rules]
  else if (group.name == groupSet[0].name) then
    local indexedRules = indexRules(null, std.sort(
      group.rules, keyF=ruleName
    ));
    [patchOrExcludeRule(rule, groupSet[0].rules, operation) for rule in indexedRules]
  else
    [] + patchOrExcludeRuleGroup(group, groupSet[1:], operation);

function(params) {
  local ruleModifications = defaults + params,
  assert std.isArray(ruleModifications.excludedRuleGroups) : 'rule-patcher: excludedRuleGroups should be an array',
  assert std.isArray(ruleModifications.excludedRules) : 'rule-patcher: excludedRules should be an array',
  assert std.isArray(ruleModifications.patchedRules) : 'rule-patcher: patchedRules should be an array',

  local excludeRule(o) = o {
    [if (o.kind == 'PrometheusRule') then 'spec']+: {
      groups: std.filterMap(
        function(group) !std.member(ruleModifications.excludedRuleGroups, group.name),
        function(group)
          group {
            rules: std.flattenArrays(
              patchOrExcludeRuleGroup(group, ruleModifications.excludedRules, 'exclude')
            ),
          },
        super.groups,
      ),
    },
  },

  local patchRule(o) = o {
    [if (o.kind == 'PrometheusRule') then 'spec']+: {
      groups: std.map(
        function(group)
          group {
            rules: std.flattenArrays(
              patchOrExcludeRuleGroup(group, ruleModifications.patchedRules, 'patch')
            ),
          },
        super.groups,
      ),
    },
  },

  // shorthand for rule patching, rule excluding
  sanitizePrometheusRules(o): {
    [k]: patchRule(excludeRule(o[k]))
    for k in std.objectFields(o)
  },
}
