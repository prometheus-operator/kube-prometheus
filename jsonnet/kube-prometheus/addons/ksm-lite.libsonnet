local addArgs(args, name, containers) = std.map(
  function(c) if c.name == name then
    c {
      args+: args,
    }
  else c,
  containers,
);

{
  kubeStateMetrics+: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: addArgs(
              [|||
                --metric-denylist=
                ^kube_.+_created$,
                ^kube_.+_metadata_resource_version$,
                ^kube_replicaset_metadata_generation$,
                ^kube_replicaset_status_observed_generation$,
                ^kube_pod_restart_policy$,
                ^kube_pod_init_container_status_terminated$,
                ^kube_pod_init_container_status_running$,
                ^kube_pod_container_status_terminated$,
                ^kube_pod_container_status_running$,
                ^kube_pod_completion_time$,
                ^kube_pod_status_scheduled$
              |||],
              'kube-state-metrics',
              super.containers
            ),
          },
        },
      },
    },
  },
}
