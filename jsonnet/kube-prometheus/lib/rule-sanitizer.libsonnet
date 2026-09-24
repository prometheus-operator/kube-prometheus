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

local findRuleName(rule, ruleSet) =
  local _findSameRuleName(rule, ruleSet, index) =
    if std.length(ruleSet) == index then
      []
    else if (('alert' in rule && 'alert' in ruleSet[index] && rule.alert == ruleSet[index].alert) ||
             ('record' in rule && 'record' in ruleSet[index] && rule.record == ruleSet[index].record)) then
      [index] + _findSameRuleName(rule, ruleSet, index + 1)
    else
      [] + _findSameRuleName(rule, ruleSet, index + 1);
  _findSameRuleName(rule, ruleSet, 0);

local indexRules(ruleSet) =
  local _indexRules(ruleSet, index) =
    if std.length(ruleSet) == index then
      []
    else
      // First we find the number of occurences of the rule in the ruleSet and
      // get an array containing the indexes of all the occurences.
      // Then, based on the current index of the rule in the ruleSet we are able
      // to deduce the index of the rule in the list of rules with the same name.
      local ruleIndex = std.find(index, findRuleName(ruleSet[index], ruleSet))[0];
      local updatedRule = std.mergePatch(ruleSet[index], { index: ruleIndex });
      [updatedRule] + _indexRules(ruleSet, index + 1);
  _indexRules(ruleSet, 0);

local patchOrExcludeRuleGroup(group, groupSet, operation) =
  if std.length(groupSet) == 0 then
    [group.rules]
  else if (group.name == groupSet[0].name) then
    local indexedRules = indexRules(group.rules);
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
