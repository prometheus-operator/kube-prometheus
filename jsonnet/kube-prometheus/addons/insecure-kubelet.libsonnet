{
  prometheus+: {
    scrapeConfigKubelet+: {
      spec+: {
        scheme: 'http',
      },
    },
    scrapeConfigKubeletCadvisor+: {
      spec+: {
        scheme: 'http',
      },
    },
  },
}
