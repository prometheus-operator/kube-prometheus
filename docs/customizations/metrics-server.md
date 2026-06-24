### Using metrics-server instead of prometheus-adapter

By default, kube-prometheus deploys [prometheus-adapter](https://github.com/kubernetes-sigs/prometheus-adapter) to serve the Kubernetes resource metrics API (`metrics.k8s.io`). This is a full-featured solution that derives CPU and memory metrics from Prometheus queries, and can also serve custom and external metrics APIs.

However, for use cases where only the resource metrics API is needed (for example, when using [KEDA](https://keda.sh/) for custom metrics scaling), the lightweight upstream [metrics-server](https://github.com/kubernetes-sigs/metrics-server) may be preferable.

> [!IMPORTANT]
> prometheus-adapter is [being deprecated](https://github.com/kubernetes-sigs/prometheus-adapter/issues/701) by SIG Instrumentation. The project recommends migrating to KEDA for custom/external metrics use cases. Since metrics-server handles the resource metrics API natively without requiring Prometheus queries, it is the natural replacement for the resource metrics portion. We plan to make `metrics-server` the default `resourceMetricsAPI` in a future release of kube-prometheus.

#### Switching to metrics-server

Set the `resourceMetricsAPI` field in `values.common` to `'metrics-server'`:

```jsonnet mdox-exec="cat examples/jsonnet-snippets/metrics-server.jsonnet"
(import 'kube-prometheus/main.libsonnet') +
{
  values+:: {
    common+: {
      resourceMetricsAPI:: 'metrics-server',
    },
    metricsServer+: {
      kubeletInsecureTLS:: true,
    },
  },
}
```

This replaces the prometheus-adapter manifests with metrics-server manifests. Only one resource metrics API provider can be active at a time since they both register the `v1beta1.metrics.k8s.io` APIService.

#### When to set kubeletInsecureTLS

On clusters that do not use proper kubelet serving certificates (for example, kind, minikube, or clusters without a kubelet-serving CA), set `kubeletInsecureTLS:: true`. On production clusters with a properly configured kubelet PKI, this should be left at the default (`false`).

#### Emitting manifests

If you are writing your own top-level jsonnet (instead of using `example.jsonnet`), emit the resource metrics manifests using the helper library:

```jsonnet
(import 'kube-prometheus/lib/resource-metrics-api.libsonnet')(kp)
```

This automatically selects the correct component based on the `resourceMetricsAPI` flag.

#### Available configuration

The following hidden fields can be overridden in `values.metricsServer`:

| Field                        | Default                                      | Description                                   |
|------------------------------|----------------------------------------------|-----------------------------------------------|
| `replicas`                   | `2`                                          | Number of metrics-server replicas             |
| `resources`                  | `{requests: {cpu: '100m', memory: '200Mi'}}` | Resource requests/limits                      |
| `kubeletInsecureTLS`         | `false`                                      | Skip kubelet TLS verification                 |
| `metricResolution`           | `'15s'`                                      | How often metrics are scraped from kubelets   |
| `securePort`                 | `10250`                                      | Metrics-server HTTPS port                     |
| `extraArgs`                  | `[]`                                         | Additional command-line arguments             |
| `podAntiAffinity`            | `'hard'`                                     | Pod anti-affinity type (`'hard'` or `'soft'`) |
| `podAntiAffinityTopologyKey` | `'kubernetes.io/hostname'`                   | Topology key for anti-affinity                |
| `insecureSkipTLSVerify`      | `true`                                       | APIService TLS verification                   |
| `priorityClassName`          | `'system-cluster-critical'`                  | Pod priority class                            |

#### Full example

See [examples/metrics-server.jsonnet](../../examples/metrics-server.jsonnet) for a complete working example that deploys the full kube-prometheus stack with metrics-server instead of prometheus-adapter.
