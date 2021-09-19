{
  prometheus+: {
    prometheus+: {
      spec+: {
        tolerations: [
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
    },
  },
}
