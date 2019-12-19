[
  // Drop all kubelet metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'kubelet_(pod_worker_latency_microseconds|pod_start_latency_microseconds|cgroup_manager_latency_microseconds|pod_worker_start_latency_microseconds|pleg_relist_latency_microseconds|pleg_relist_interval_microseconds|runtime_operations|runtime_operations_latency_microseconds|runtime_operations_errors|eviction_stats_age_microseconds|device_plugin_registration_count|device_plugin_alloc_latency_microseconds|network_plugin_operations_latency_microseconds)',
    action: 'drop',
  },
  // Drop all scheduler metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'scheduler_(e2e_scheduling_latency_microseconds|scheduling_algorithm_predicate_evaluation|scheduling_algorithm_priority_evaluation|scheduling_algorithm_preemption_evaluation|scheduling_algorithm_latency_microseconds|binding_latency_microseconds|scheduling_latency_seconds)',
    action: 'drop',
  },
  // Drop all apiserver metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'apiserver_(request_count|request_latencies|request_latencies_summary|dropped_requests|storage_data_key_generation_latencies_microseconds|storage_transformation_failures_total|storage_transformation_latencies_microseconds|proxy_tunnel_sync_latency_secs)',
    action: 'drop',
  },
  // Drop all docker metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'docker_(operations|operations_latency_microseconds|operations_errors|operations_timeout)',
    action: 'drop',
  },
  // Drop all reflector metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'reflector_(items_per_list|items_per_watch|list_duration_seconds|lists_total|short_watches_total|watch_duration_seconds|watches_total)',
    action: 'drop',
  },
  // Drop all etcd metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'etcd_(helper_cache_hit_count|helper_cache_miss_count|helper_cache_entry_count|request_cache_get_latencies_summary|request_cache_add_latencies_summary|request_latencies_summary)',
    action: 'drop',
  },
  // Drop all transformation metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'transformation_(transformation_latencies_microseconds|failures_total)',
    action: 'drop',
  },
  // Drop all other metrics which are deprecated in kubernetes.
  {
    sourceLabels: ['__name__'],
    regex: 'kubeproxy_sync_proxy_rules_latency_microseconds|rest_client_request_latency_secons',
    action: 'drop',
  },
]
