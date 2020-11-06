{
  _config+:: {
    tolerations+:: [
      {
        key: 'key1',
        operator: 'Equal',
        value: 'value1',
        effect: 'NoSchedule',
      },
      {
        key: 'key2',
        operator: 'Exists',
      },
    ],
  },

  prometheus+: {
    prometheus+: {
      spec+: {
        tolerations: [t for t in $._config.tolerations],
      },
    },
  },
}
