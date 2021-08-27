{
  excludedRuleGroups: [
    'alertmanager.rules',
  ],
  excludedRules: [
    {
      name: 'prometheus-operator',
      rules: [
        { alert: 'PrometheusOperatorListErrors' },
      ],
    },
  ],
  patchedRules: [
    {
      name: 'prometheus-operator',
      rules: [
        {
          alert: 'PrometheusOperatorWatchErrors',
          labels: {
            severity: 'info',
          },
        },
      ],
    },
  ],
}
