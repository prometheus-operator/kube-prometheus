# Migration from Endpoints to EndpointSlice

`kube-prometheus` 0.17+ automatically configures Prometheus to use EndpointSlice instead of Endpoints for Kubernetes service discovery (Endpoints have been deprecated in Kubernetes 1.33).

While the migration should be seamless for "regular" pods, it requires a few manual steps for components running as host services (e.g. node_exporter and kubelet):
1. The node_exporter and kubelet ServiceMonitors rely on the Prometheus operator's kubelet controller which manages the `kube-system/kubelet` Service.
2. With `kube-prometheus` 0.17, the Prometheus operator starts with both `--kubelet-endpoints=true` and `--kubelet-endpointslice=true` to ensure that a) the operator synchronizes the EndpointSlice object(s) backing the `kube-system/kubelet` Service and b) Kubernetes stops mirroring the `kube-system/kubelet` Endpoints object to EndpointSlice object(s) (otherwise the operator and kube-controller-manager would fight for the same resources).
3. After verifying that all targets are correctly discovered, it is ok to modify the operator's deployment and use `--kubelet-endpoints=false` instead. This will become the default in a future version of `kube-prometheus`.
4. The `kube-system/kubelet` Endpoints object should be removed manually.

To verify the status of the Endpoints and EndpointSlice objects, run:

```shell
kubectl get -n kube-system endpoints kubelet
kubectl get -n kube-system endpointslice -l endpointslice.kubernetes.io/managed-by=prometheus-operator
```
