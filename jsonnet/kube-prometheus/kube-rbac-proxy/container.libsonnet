{
  local krp = self,
  config+:: {
    kubeRbacProxy: {
      image: error 'must provide image',
      name: error 'must provide name',
      securePortName: error 'must provide securePortName',
      securePort: error 'must provide securePort',
      secureListenAddress: error 'must provide secureListenAddress',
      upstream: error 'must provide upstream',
      tlsCipherSuites: error 'must provide tlsCipherSuites',
    },
  },

  specMixin:: {
    local sm = self,
    config+:: {
      kubeRbacProxy: {
        image: error 'must provide image',
        name: error 'must provide name',
        securePortName: error 'must provide securePortName',
        securePort: error 'must provide securePort',
        secureListenAddress: error 'must provide secureListenAddress',
        upstream: error 'must provide upstream',
        tlsCipherSuites: error 'must provide tlsCipherSuites',
      },
    },
    spec+: {
      template+: {
        spec+: {
          containers+: [{
            name: krp.config.kubeRbacProxy.name,
            image: krp.config.kubeRbacProxy.image,
            args: [
              '--logtostderr',
              '--secure-listen-address=' + krp.config.kubeRbacProxy.secureListenAddress,
              '--tls-cipher-suites=' + std.join(',', krp.config.kubeRbacProxy.tlsCipherSuites),
              '--upstream=' + krp.config.kubeRbacProxy.upstream,
            ],
            ports: [
              { name: krp.config.kubeRbacProxy.securePortName, containerPort: krp.config.kubeRbacProxy.securePort },
            ],
            securityContext: {
              runAsUser: 65532,
              runAsGroup: 65532,
              runAsNonRoot: true,
            },
          }],
        },
      },
    },
  },

  deploymentMixin:: {
    local dm = self,
    config+:: {
      kubeRbacProxy: {
        image: error 'must provide image',
        name: error 'must provide name',
        securePortName: error 'must provide securePortName',
        securePort: error 'must provide securePort',
        secureListenAddress: error 'must provide secureListenAddress',
        upstream: error 'must provide upstream',
        tlsCipherSuites: error 'must provide tlsCipherSuites',
      },
    },
    deployment+: krp.specMixin {
      config+:: {
        kubeRbacProxy+: dm.config.kubeRbacProxy,
      },
    },
  },

  statefulSetMixin:: {
    local sm = self,
    config+:: {
      kubeRbacProxy: {
        image: error 'must provide image',
        name: error 'must provide name',
        securePortName: error 'must provide securePortName',
        securePort: error 'must provide securePort',
        secureListenAddress: error 'must provide secureListenAddress',
        upstream: error 'must provide upstream',
        tlsCipherSuites: error 'must provide tlsCipherSuites',
      },
    },
    statefulSet+: krp.specMixin {
      config+:: {
        kubeRbacProxy+: sm.config.kubeRbacProxy,
      },
    },
  },
}
