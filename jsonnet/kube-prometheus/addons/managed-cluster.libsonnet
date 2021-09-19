// On managed Kubernetes clusters some of the control plane components are not exposed to customers.
// Disable scrape jobs, service monitors, and alert groups for these components by overwriting 'main.libsonnet' defaults

{
  kubernetesControlPlane+: {
    serviceMonitorKubeControllerManager:: null,
    serviceMonitorKubeScheduler:: null,
  } + {
    prometheusRule+: {
      spec+: {
        local g = super.groups,
        groups: [
          h
          for h in g
          if !std.setMember(h.name, ['kubernetes-system-controller-manager', 'kubernetes-system-scheduler'])
        ],
      },
    },
  },
}
