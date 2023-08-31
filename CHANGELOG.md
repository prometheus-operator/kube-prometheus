## release-0.13 / 2023-08-31

* [CHANGE] Added a AKS platform to `platforms.libsonnet` [#1997](https://github.com/prometheus-operator/kube-prometheus/pull/1997)
* [CHANGE] Disable btrfs collector by default [#2074](https://github.com/prometheus-operator/kube-prometheus/pull/2074)
* [CHANGE] Enable Multi Cluster alerts by default [#2099](https://github.com/prometheus-operator/kube-prometheus/pull/2099)
* [FEATURE] Create dedicated Service to expose CoreDNS metric [#2107](https://github.com/prometheus-operator/kube-prometheus/pull/2107)
* [FEATURE] Add Windows support using Hostprocess instead of static_configs [#2048](https://github.com/prometheus-operator/kube-prometheus/pull/2048)
* [BUGFIX] Fix a compilation error when building the custom-metrics addon [#1996](https://github.com/prometheus-operator/kube-prometheus/pull/1996)
* [BUGFIX] Add `prometheus-adapter` in Prometheus's NetworkPolicy [#1982](https://github.com/prometheus-operator/kube-prometheus/pull/1982)
* [BUGFIX] Fix namespace specified in manifest non-namespaced resources [#2158](https://github.com/prometheus-operator/kube-prometheus/pull/2158)
* [BUGFIX] Override ServiceAccount, Role and ClusterRole names in RoleBinding and ClusterRoleBinding [#2135](https://github.com/prometheus-operator/kube-prometheus/pull/2135)
* [BUGFIX] Remove deprecated `--logtostderr` argument of prometheus-adapter [#2185](https://github.com/prometheus-operator/kube-prometheus/pull/2185)
* [BUGFIX] Fix alertmanager external config example [#1891](https://github.com/prometheus-operator/kube-prometheus/pull/1891)
* [ENHANCEMENT] Add startupProbe to prometheus-adapter [#2029](https://github.com/prometheus-operator/kube-prometheus/pull/2029)
* [ENHANCEMENT] Added configurable default values for kube-rbac-proxy in prometheus-operator, node-exporter and blackbox-exporter [#1987](https://github.com/prometheus-operator/kube-prometheus/pull/1987)
* [ENHANCEMENT] Modify control plane ServiceMonitors to be compatible with Argo [#2041](https://github.com/prometheus-operator/kube-prometheus/pull/2041)
* [ENHANCEMENT] Add md5 hash of the ConfigMap in Prometheus Adapter Deployment Annotations to force its recreation [#2195](https://github.com/prometheus-operator/kube-prometheus/pull/2195)

## release-0.12 / 2023-01-19

* [CHANGE] Updates Prometheus Adapater version to 0.10.0 [#1865](https://github.com/prometheus-operator/kube-prometheus/pull/1865)
* [FEATURE] Added a AKS platform [#1869](https://github.com/prometheus-operator/kube-prometheus/pull/1869)
* [BUGFIX] Update Pyrra to 0.4.2 [#1800](https://github.com/prometheus-operator/kube-prometheus/pull/1800)
* [BUGFIX] Jsonnet: enable automountServiceAccountToken for prometheus service account [#1808](https://github.com/prometheus-operator/kube-prometheus/pull/1808)
* [BUGFIX] Fix diskDeviceSelector regex for aks and eks [#1810](https://github.com/prometheus-operator/kube-prometheus/pull/1810)
* [BUGFIX] Set path.udev.data Argument of Node Exporter [#1913](https://github.com/prometheus-operator/kube-prometheus/pull/1913)
* [BUGFIX] Include RAID device md.* in disk seletor [#1945](https://github.com/prometheus-operator/kube-prometheus/pull/1945)
* [ENHANCEMENT] Prometheus-adapter: add prefix option to config for container metrics [#1844](https://github.com/prometheus-operator/kube-prometheus/pull/1844)
* [ENHANCEMENT] Switch kube-state-metrics registry to registry.k8s.io [#1914](https://github.com/prometheus-operator/kube-prometheus/pull/1914)
* [ENHANCEMENT] Node Exporter: add parameter for ignored network devices [#1887](https://github.com/prometheus-operator/kube-prometheus/pull/1887)

## release-0.11 / 2022-06-15

* [CHANGE] Disable injecting unnecessary variables allowing access to k8s API [#1591](https://github.com/prometheus-operator/kube-prometheus/pull/1591)
* [FEATURE] Add grafana-mixin [#1458](https://github.com/prometheus-operator/kube-prometheus/pull/1458)
* [FEATURE] Add example usage of prometheus-agent [#1472](https://github.com/prometheus-operator/kube-prometheus/pull/1472)
* [FEATURE] Add Pyrra as (optional) component [#1667](https://github.com/prometheus-operator/kube-prometheus/pull/1667)
* [ENHANCEMENT] Adds NetworkPolicies to all components of Kube-prometheus [#1650](https://github.com/prometheus-operator/kube-prometheus/pull/1650)
* [ENHANCEMENT] Scan generated manifests with kubescape in CI [#1584](https://github.com/prometheus-operator/kube-prometheus/pull/1584)
* [ENHANCEMENT] Explicitly declare allowPrivilegeEscalation to false in all components [#1593](https://github.com/prometheus-operator/kube-prometheus/pull/1593)
* [ENHANCEMENT] Forbid write access to root filesystem [#1600](https://github.com/prometheus-operator/kube-prometheus/pull/1600)
* [ENHANCEMENT] Drop Linux capabilities, , just keeping CAP_SYS_TIME for node-exporter [#1610](https://github.com/prometheus-operator/kube-prometheus/pull/1610)
* [ENHANCEMENT] Remove hostPort from node-export daemonset [#1612](https://github.com/prometheus-operator/kube-prometheus/pull/1612)
* [ENHANCEMENT] Add priorityClassName as system-cluster-critical for node_exporter [#1649](https://github.com/prometheus-operator/kube-prometheus/pull/1649)
* [ENHANCEMENT] Added custom overrides for kube-rbac-proxy-self [#1637](https://github.com/prometheus-operator/kube-prometheus/pull/1637)
* [ENHANCEMENT] Adds readinessProbe and livenessProbe to prometheus-adapter jsonnet [#1696](https://github.com/prometheus-operator/kube-prometheus/pull/1696)
* [BUGFIX] Update kubeadm integration of kube-prometheus [#1569](https://github.com/prometheus-operator/kube-prometheus/pull/1569)
* [BUGFIX] Add projected volumes permission to addon/podsecuritypolicie [#1572](https://github.com/prometheus-operator/kube-prometheus/pull/1572)
* [BUGFIX] Hide namespace for prometheus clusterRole and clusterRolebinding [#1566](https://github.com/prometheus-operator/kube-prometheus/pull/1566)
* [BUGFIX] Fix accidentally broken thanosSelector after #1543 [#1556](https://github.com/prometheus-operator/kube-prometheus/pull/1556)
* [BUGFIX] Jsonnet: filter out kube-proxy alerts when kube-proxy is disabled [#1609](https://github.com/prometheus-operator/kube-prometheus/pull/1609)
* [BUGFIX] Sanitize regex denylist in ksm-lite addon [#1613](https://github.com/prometheus-operator/kube-prometheus/pull/1613)
* [BUGFIX] Sanitize all regex denylist in ksm-lite addon [#1614](https://github.com/prometheus-operator/kube-prometheus/pull/1614)
* [BUGFIX] Add extra-volume mount for plugins downloads [#1624](https://github.com/prometheus-operator/kube-prometheus/pull/1624)
* [BUGFIX] Added allowedCapabilities to node-exporter psp [#1642](https://github.com/prometheus-operator/kube-prometheus/pull/1642)
* [BUGFIX] Fix cluster:node_cpu:ratio query [#1628](https://github.com/prometheus-operator/kube-prometheus/pull/1628)
* [BUGFIX] Removed CAP_ from node-exporter daemonset [#1647](https://github.com/prometheus-operator/kube-prometheus/pull/1647)
* [BUGFIX] Update PodMonitor for kube-proxy [#1630](https://github.com/prometheus-operator/kube-prometheus/pull/1630)
* [BUGFIX] Adds port name to prometheus-adapter [#1701](https://github.com/prometheus-operator/kube-prometheus/pull/1701)
* [BUGFIX] Fix grafana network access [#1721](https://github.com/prometheus-operator/kube-prometheus/pull/1721)
* [BUGFIX] Fix networkpolicies-disabled addon [#1724](https://github.com/prometheus-operator/kube-prometheus/pull/1724)
* [BUGFIX] Adjust NodeFilesystemSpaceFillingUp thresholds according default kubelet GC behavior [#1729](https://github.com/prometheus-operator/kube-prometheus/pull/1729)
* [BUGFIX] Fix problems when enabling eks platform patch [#1675](https://github.com/prometheus-operator/kube-prometheus/pull/1675)
* [BUGFIX] Access requests to sidecar from thanos-query [#1730](https://github.com/prometheus-operator/kube-prometheus/pull/1730)
* [BUGFIX] Fix prometheus namespace connection for addons/pyrra [#1734](https://github.com/prometheus-operator/kube-prometheus/pull/1734)

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
* [ENHANCEMENT] Added configurable default values for sidecar container kube-rbac-proxy-self in deployment kube-statate-metrics. [#1637](https://github.com/prometheus-operator/kube-prometheus/pull/1637)
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
