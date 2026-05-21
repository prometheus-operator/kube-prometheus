{
  // Not required fields are hidden
  // Deprecated fields are commented out as we don't want to popularize them
  // Types mapping:
  //   Object (or pointer to Object) -> {}
  //   List (or pointer to List) -> []
  //   String (or pointer to String) -> ""
  //   Everything else -> null
  // 
  // This file can be converted to YAML with jsonnet 0.18.0
  additionalPeers:: [],
  affinity:: {},
  alertmanagerConfigNamespaceSelector:: {},
  alertmanagerConfigSelector:: {},
  baseImage:: "",  // Deprecated, remove
  clusterAdvertiseAddress:: "",
  clusterGossipInterval:: "",
  clusterPeerTimeout:: "",
  clusterPushpullInterval:: "",
  configMaps:: [],
  configSecret:: "",
  containers:: [],
  externalUrl:: "",
  forceEnableClusterMode:: null,
  image:: "",
  imagePullSecrets:: [],
  initContainers:: [],
  listenLocal:: null,
  logFormat:: "",
  logLevel:: "",
  minReadySeconds:: null,
  nodeSelector:: {},
  paused:: null,
  podMetadata:: {},
  portName:: "",
  priorityClassName:: "",
  replicas:: null,
  resources:: {},
  retention:: "",
  routePrefix:: "",
  secrets:: [],
  securityContext:: {},
  serviceAccountName:: "",
  sha:: "",  // Deprecated, remove
  storage:: {},
  tag:: "",  // Deprecated, remove
  tolerations:: [],
  topologySpreadConstraints:: [],
  version:: "",
  volumeMounts:: [],
  volumes:: [],
}