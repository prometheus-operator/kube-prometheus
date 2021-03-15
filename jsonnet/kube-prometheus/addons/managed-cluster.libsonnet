// On managed Kubernetes clusters some of the control plane components are not exposed to customers.
// Disable scrape jobs, service monitors, and alert groups for these components by overwriting 'main.libsonnet' defaults

{
  local k = super.kubernetesControlPlane,

  kubernetesControlPlane+: {
    [q]: null
    for q in std.objectFields(k)
    if std.setMember(q, ['serviceMonitorKubeControllerManager', 'serviceMonitorKubeScheduler'])
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
