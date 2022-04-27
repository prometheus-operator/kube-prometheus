# Troubleshooting

See the general [guidelines](community-support.md) for getting support from the community.

## Error retrieving kubelet metrics

Should the Prometheus `/targets` page show kubelet targets, but not able to successfully scrape the metrics, then most likely it is a problem with the authentication and authorization setup of the kubelets.

As described in the [README.md Prerequisites](../README.md#prerequisites) section, in order to retrieve metrics from the kubelet token authentication and authorization must be enabled. Some Kubernetes setup tools do not enable this by default.

- If you are using Google's GKE product, see [cAdvisor support](GKE-cadvisor-support.md).
- If you are using AWS EKS, see [AWS EKS CNI support](EKS-cni-support.md).
- If you are using Weave Net, see [Weave Net support](weave-net-support.md).

### Authentication problem

The Prometheus `/targets` page will show the kubelet job with the error `403 Unauthorized`, when token authentication is not enabled. Ensure, that the `--authentication-token-webhook=true` flag is enabled on all kubelet configurations.

### Authorization problem

The Prometheus `/targets` page will show the kubelet job with the error `401 Unauthorized`, when token authorization is not enabled. Ensure that the `--authorization-mode=Webhook` flag is enabled on all kubelet configurations.

## kube-state-metrics resource usage

In some environments, kube-state-metrics may need additional
resources. One driver for more resource needs, is a high number of
namespaces. There may be others.

kube-state-metrics resource allocation is managed by
[addon-resizer](https://github.com/kubernetes/autoscaler/tree/master/addon-resizer/nanny)
You can control it's parameters by setting variables in the
config. They default to:

```jsonnet
    kubeStateMetrics+:: {
      baseCPU: '100m',
      cpuPerNode: '2m',
      baseMemory: '150Mi',
      memoryPerNode: '30Mi',
    }
```

## Error retrieving kube-proxy metrics

By default, kubeadm will configure kube-proxy to listen on 127.0.0.1 for metrics. Because of this prometheus would not be able to scrape these metrics. This would have to be changed to 0.0.0.0 in one of the following two places:

1. Before cluster initialization, the config file passed to kubeadm init should have KubeProxyConfiguration manifest with the field metricsBindAddress set to 0.0.0.0:10249
2. If the k8s cluster is already up and running, we'll have to modify the configmap kube-proxy in the namespace kube-system and set the metricsBindAddress field. After this kube-proxy daemonset would have to be restarted with
   `kubectl -n kube-system rollout restart daemonset kube-proxy`
