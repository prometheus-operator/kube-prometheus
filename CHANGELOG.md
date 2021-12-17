## release-0.10 / 2021-12-17

* [CHANGE] Adjust node filesystem space filling up warning threshold to 20% [#1357](https://github.com/prometheus-operator/kube-prometheus/pull/1357)
* [CHANGE] Always generate grafana-config secret [#1373](https://github.com/prometheus-operator/kube-prometheus/pull/1373)
* [CHANGE] Make filesystem ignored mount points configurable for node-exporter [#1376](https://github.com/prometheus-operator/kube-prometheus/pull/1376)
* [CHANGE] Drop some high cardinality cAdvisor metrics [#1406](https://github.com/prometheus-operator/kube-prometheus/pull/1406), [#1396](https://github.com/prometheus-operator/kube-prometheus/pull/1396)
* [CHANGE] Use `--collector.filesystem.mount-points-exclude` instead of deprecated `--collector.filesystem.ignored-mount-points` argument for `node-exporter` [#1407](https://github.com/prometheus-operator/kube-prometheus/pull/1407)
* [CHANGE] Drop some of prometheus-adapter metrics that are inherited from the apiserver code but aren't useful in the context of prometheus-adapter [#1409](https://github.com/prometheus-operator/kube-prometheus/pull/1409)
* [CHANGE] Remove "app" label selector deprecated by Prometheus-operator [#1420](https://github.com/prometheus-operator/kube-prometheus/pull/1420)
* [CHANGE] Use recommended instance label for Prometheus/Alertmanager resources [#1520](https://github.com/prometheus-operator/kube-prometheus/pull/1520)
* [CHANGE] Drop deprecated apiserver_longrunning_gauge and apiserver_registered_watchers metrics [#1553](https://github.com/prometheus-operator/kube-prometheus/pull/1553)
* [CHANGE] Drop deprecated coredns_cache_misses_total [#1553](https://github.com/prometheus-operator/kube-prometheus/pull/1553)
* [ENHANCEMENT] Add support for LDAP authentication in Grafana [#1455](https://github.com/prometheus-operator/kube-prometheus/pull/1445)
* [ENHANCEMENT] Include rewritten kubernetes-grafana for easier usage of new library features [#1450](https://github.com/prometheus-operator/kube-prometheus/pull/1450)
* [ENHANCEMENT] Specify default container in node-exporter pod [#1462](https://github.com/prometheus-operator/kube-prometheus/pull/1462)
* [ENHANCEMENT] Make metadata consistent across objects in the same component [#1471](https://github.com/prometheus-operator/kube-prometheus/pull/1471)
* [ENHANCEMENT] Establish convention for default field types [#1475](https://github.com/prometheus-operator/kube-prometheus/pull/1475)
* [ENHANCEMENT] Exclude k3s containerd mountpoints [#1497](https://github.com/prometheus-operator/kube-prometheus/pull/1497)
* [ENHANCEMENT] Alertmanager now uses the new `matcher` syntax in the routing tree and inhibition rules [#1508](https://github.com/prometheus-operator/kube-prometheus/pull/1508)
* [ENHANCEMENT] Deprecate `thanosSelector` and expose `mixin._config.thanos` config variable for thanos sidecar [#1543](https://github.com/prometheus-operator/kube-prometheus/pull/1543)
* [FEATURE] Support scraping config-reloader sidecar for Prometheus and AlertManager StatefulSets [#1344](https://github.com/prometheus-operator/kube-prometheus/pull/1344)
* [FEATURE] Expose prometheus alerting configuration in $.values.prometheus configuration [#1476](https://github.com/prometheus-operator/kube-prometheus/pull/1476)
* [BUGFIX] Remove deprecated policy/v1beta1 Kubernetes API [#1433](https://github.com/prometheus-operator/kube-prometheus/pull/1433)
* [BUGFIX] Fix prometheus URL in prometheus-adapter [#1463](https://github.com/prometheus-operator/kube-prometheus/pull/1463)
* [BUGFIX] Always use proper values scope for namespace in addons [#1518](https://github.com/prometheus-operator/kube-prometheus/pull/1518)
* [BUGFIX] Fix default empty groups for k8s PrometheusRule [#1534](https://github.com/prometheus-operator/kube-prometheus/pull/1534)

## release-0.9 / 2021-08-19

* [CHANGE] Test against Kubernetes 1.21 and 1,22. #1161 #1337
* [CHANGE] Drop cAdvisor metrics without (pod, namespace) label pairs. #1250
* [CHANGE] Excluded deprecated `etcd_object_counts` metric. #1337
* [FEATURE] Add PodDisruptionBudget to prometheus-adapter. #1136
* [FEATURE] Add support for feature flags in Prometheus. #1129
* [FEATURE] Add env parameter for grafana component. #1171
* [FEATURE] Add gitpod deployment of kube-prometheus on k3s. #1211
* [FEATURE] Add resource requests and limits to prometheus-adapter container. #1282
* [FEATURE] Add PodMonitor for kube-proxy. #1230
* [FEATURE] Turn AWS VPC CNI into a control plane add-on. #1307
* [ENHANCEMENT] Export anti-affinity addon. #1114
* [ENHANCEMENT] Allow changing configmap-reloader, grafana, and kube-rbac-proxy images in $.values.common.images. #1123 #1124 #1125
* [ENHANCEMENT] Add automated version upgrader. #1166
* [ENHANCEMENT] Improve all-namespace addon. #1131
* [ENHANCEMENT] Add example of running without grafana deployment. #1201
* [ENHANCEMENT] Import managed-cluster addon for the EKS platform. #1205
* [ENHANCEMENT] Automatically update jsonnet dependencies. #1220
* [ENHANCEMENT] Adapt kube-prometheus to changes to ovn veth interfaces names. #1224
* [ENHANCEMENT] Add example release-0.3 to release-0.8 migration to docs. #1235
* [ENHANCEMENT] Consolidate intervals used in prometheus-adapter CPU queries. #1231
* [ENHANCEMENT] Create dashboardDefinitions if rawDashboards or folderDashboards are specified. #1255
* [ENHANCEMENT] Relabel instance with node name for CNI DaemonSet on EKS. #1259
* [ENHANCEMENT] Update doc on Prometheus rule updates since release 0.8. #1253
* [ENHANCEMENT] Point runbooks to https://runbooks.prometheus-operator.dev. #1267
* [ENHANCEMENT] Allow setting of kubeRbacProxyMainResources in kube-state-metrics. #1257
* [ENHANCEMENT] Automate release branch updates. #1293 #1303
* [ENHANCEMENT] Create Thanos Sidecar rules separately from Prometheus ones. #1308
* [ENHANCEMENT] Allow using newer jsonnet-bundler dependency resolution when using windows addon. #1310
* [ENHANCEMENT] Prometheus ruleSelector defaults to all rules.
* [BUGFIX] Fix kube-state-metrics metric denylist regex pattern. #1146
* [BUGFIX] Fix missing resource config in blackbox exporter. #1148
* [BUGFIX] Fix adding private repository. #1169
* [BUGFIX] Fix kops selectors for scheduler, controllerManager and kube-dns. #1164
* [BUGFIX] Fix scheduler and controller selectors for Kubespray. #1142
* [BUGFIX] Fix label selector for coredns ServiceMonitor. #1200
* [BUGFIX] Fix name for blackbox-exporter PodSecurityPolicy. #1213
* [BUGFIX] Fix ingress path rules for networking.k8s.io/v1. #1212
* [BUGFIX] Disable insecure cypher suites for prometheus-adapter. #1216
* [BUGFIX] Fix CNI metrics relabelings on EKS. #1277
* [BUGFIX] Fix node-exporter ignore list for OVN. #1283
* [BUGFIX] Revert back to awscni_total_ip_addresses-based alert on EKS. #1292
* [BUGFIX] Allow passing `thanos: {}` to prometheus configuration. #1325
