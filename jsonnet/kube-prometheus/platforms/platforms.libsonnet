local platforms = {
  aws: import './aws.libsonnet',
  bootkube: import './bootkube.libsonnet',
  gke: import './gke.libsonnet',
  eks: import './eks.libsonnet',
  kops: import './kops.libsonnet',
  kops_coredns: (import './kops.libsonnet') + (import './kops-coredns.libsonnet'),
  kubeadm: import './kubeadm.libsonnet',
  kubespray: import './kubespray.libsonnet',
};

{
  // platformPatch returns the platform specific patch associated to the given
  // platform.
  platformPatch(p): if p != null && std.objectHas(platforms, p) then platforms[p] else {},
}
