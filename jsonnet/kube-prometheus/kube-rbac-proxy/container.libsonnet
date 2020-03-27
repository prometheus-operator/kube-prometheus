local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local deployment = k.apps.v1.deployment;
local container = deployment.mixin.spec.template.spec.containersType;
local containerPort = container.portsType;

{
  _config+:: {
    namespace: 'default',

    versions+:: {
      kubeRbacProxy: 'v0.4.1',
    },

    imageRepos+:: {
      kubeRbacProxy: 'quay.io/coreos/kube-rbac-proxy',
    },
  },

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
    spec+: {
      containers+: [
        container.new(krp.config.kubeRbacProxy.name, krp.config.kubeRbacProxy.image) +
        container.mixin.securityContext.withRunAsUser(65534) +
        container.withArgs([
          '--logtostderr',
          '--secure-listen-address=' + krp.config.kubeRbacProxy.secureListenAddress,
          '--tls-cipher-suites=' + std.join(',', krp.config.kubeRbacProxy.tlsCipherSuites),
          '--upstream=' + krp.config.kubeRbacProxy.upstream,
        ]) +
        container.withPorts(containerPort.newNamed(krp.config.kubeRbacProxy.securePort, krp.config.kubeRbacProxy.securePortName)),
      ],
    },
  },

  specTemplateMixin:: {
    spec+: {
      template+: krp.specMixin
    },
  },

  deploymentMixin:: {
    deployment+: krp.specTemplateMixin
  },

  statefulSetMixin:: {
    statefulSet+: krp.specTemplateMixin
  },
}
