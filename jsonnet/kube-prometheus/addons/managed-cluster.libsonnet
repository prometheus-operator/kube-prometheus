// On managed Kubernetes clusters some of the control plane components are not exposed to customers.
// Disable scrape jobs, service monitors, and alert groups for these components by overwriting 'main.libsonnet' defaults

{
  values+:: {
    // This snippet walks the original object (super.jobs, set as temp var j) and creates a replacement jobs object
    //     excluding any members of the set specified (eg: controller and scheduler).
    local j = super.jobs,
    jobs: {
      [k]: j[k]
      for k in std.objectFields(j)
      if !std.setMember(k, ['KubeControllerManager', 'KubeScheduler'])
    },

    // Skip alerting rules too
    prometheus+: {
      rules+:: {
        local g = super.groups,
        groups: [
          h
          for h in g
          if !std.setMember(h.name, ['kubernetes-system-controller-manager', 'kubernetes-system-scheduler'])
        ],
      },
    },
  },

  // Same as above but for ServiceMonitor's
  local p = super.prometheus,
  prometheus: {
    [q]: p[q]
    for q in std.objectFields(p)
    if !std.setMember(q, ['serviceMonitorKubeControllerManager', 'serviceMonitorKubeScheduler'])
  },
}
