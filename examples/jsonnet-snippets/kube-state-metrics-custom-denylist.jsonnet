(import 'github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus/addons/ksm-lite.libsonnet') {
   denylist: [
     '^kube_(?=namespace).*_created$',
     '^kube_.+_metadata_resource_version$',
     '^kube_replicaset_metadata_generation$',
     '^kube_replicaset_status_observed_generation$',
     '^kube_pod_restart_policy$',
     '^kube_pod_init_container_status_terminated$',
     '^kube_pod_init_container_status_running$',
     '^kube_pod_container_status_terminated$',
     '^kube_pod_container_status_running$',
     '^kube_pod_completion_time$',
     '^kube_pod_status_scheduled$',
   ],
}
