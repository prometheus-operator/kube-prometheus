---
weight: 320
toc: true
title: Using Perses instead of Grafana
menu:
    docs:
        parent: kube
lead: Replace Grafana with Perses for Kubernetes cluster dashboards
images: []
draft: false
description: Replace Grafana with Perses for Kubernetes cluster dashboards using the Perses addon
---

> [!NOTE]
> Perses is currently integrated as an addon. Once dashboard parity with the Grafana dashboards shipped by kube-prometheus is fully validated, it will be promoted to a built-in toggle (similar to the `metrics-server` / `prometheus-adapter` switch).

[Perses](https://perses.dev) is a CNCF Sandbox observability visualization platform. The `perses` addon replaces Grafana with Perses and deploys the same Kubernetes observability dashboards via the [perses-operator](https://github.com/perses/perses-operator) and [community-mixins](https://github.com/perses/community-mixins).

## What the addon deploys

| Resource | Kind | Description |
|----------|------|-------------|
| perses-operator | Deployment, RBAC, ServiceAccount | Manages Perses CRs declaratively |
| 4 CRDs | CustomResourceDefinition | `Perses`, `PersesDashboard`, `PersesDatasource`, `PersesGlobalDatasource` |
| Perses instance | `Perses` CR | Runs the Perses server (port 8080) |
| Prometheus datasource | `PersesGlobalDatasource` CR | Proxies queries to `prometheus-k8s` Service |
| 18 dashboards | `PersesDashboard` CRs | API Server, Kubelet, Compute Resources, Networking, etc. |
| ServiceMonitor | `ServiceMonitor` | Scrapes operator metrics |
| PrometheusRule | `PrometheusRule` | Operator alerting rules |
| NetworkPolicy patch | `NetworkPolicy` | Allows Perses to query Prometheus |

## Switching from Grafana to Perses

Generate manifests with Perses instead of Grafana:

```shell
make manifests-perses
```

This uses [`examples/perses.jsonnet`](../../examples/perses.jsonnet), which imports the Perses addon and disables Grafana automatically. Apply the generated manifests:

```shell
# Apply CRDs and namespace first
kubectl apply --server-side -f manifests/setup
kubectl wait \
    --for condition=Established \
    --all CustomResourceDefinition \
    --namespace=monitoring

# Apply the remaining manifests
kubectl apply -f manifests/
```

### Access the Perses UI

```shell
kubectl --namespace monitoring port-forward svc/perses 8080
```

Open Perses at [http://localhost:8080](http://localhost:8080). All 18 Kubernetes dashboards are pre-loaded via `PersesDashboard` CRs and the Prometheus datasource is auto-configured.

### Using a custom jsonnet file

If you need to customize values beyond the defaults, create your own jsonnet file that imports the Perses addon. See [`examples/perses.jsonnet`](../../examples/perses.jsonnet) for reference:

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/perses.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },
    // Disable Grafana when using Perses.
    grafana: {},
  };
```

Then generate manifests with:

```shell
./build.sh my-perses.jsonnet
```

## Switching back to Grafana

To revert to Grafana, regenerate manifests using the default target and reapply:

```shell
# Rebuild with Grafana (default)
make manifests
kubectl apply --server-side -f manifests/setup
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
kubectl apply -f manifests/

# Remove Perses-specific resources no longer in manifests
kubectl -n monitoring delete --ignore-not-found=true \
  perses perses \
  persesglobaldatasources.perses.dev prometheus-datasource \
  persesdashboards.perses.dev --all \
  deployment perses-operator
```

## Customization

### Override versions

```jsonnet
{
  values+:: {
    common+: {
      versions+: {
        perses: '0.54.0',
        persesOperator: '0.5.0',
      },
    },
  },
}
```

### Override images (e.g. internal registry)

```jsonnet
{
  values+:: {
    common+: {
      images+: {
        perses: 'my-registry.example.com/perses:v0.54.0',
        persesOperator: 'my-registry.example.com/perses-operator:v0.5.0',
      },
    },
  },
}
```

### Change the Prometheus datasource URL

By default the datasource proxies queries through the Perses server to `http://prometheus-k8s.<namespace>.svc.cluster.local:9090`. If your Prometheus Service has a different name:

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/perses.libsonnet') +
  {
    values+:: {
      common+: { namespace: 'monitoring' },
    },
    perses+: {
      prometheusGlobalDatasource+: {
        spec+: {
          config+: {
            plugin+: {
              spec+: {
                proxy+: {
                  spec+: {
                    url: 'http://my-prometheus.monitoring.svc.cluster.local:9090',
                  },
                },
              },
            },
          },
        },
      },
    },
  };
```

### Enable conversion webhooks

By default, the operator's CRD conversion webhooks are disabled because they require [cert-manager](https://cert-manager.io/) to provision TLS certificates. If you need to serve both `v1alpha1` and `v1alpha2` API versions simultaneously (e.g., during a CRD version migration), you can enable them.

**Prerequisites:**

1. Install cert-manager:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

2. Wait for cert-manager to be ready:

```bash
kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=120s
```

See the [cert-manager installation docs](https://cert-manager.io/docs/installation/) for alternative install methods (Helm, operator, etc.).

**Enable webhooks in your Jsonnet:**

```jsonnet
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/perses.libsonnet') +
  {
    values+:: {
      common+: { namespace: 'monitoring' },
      perses+: { enableWebhooks: true },
    },
    grafana: {},
  };
```

## Dashboard coverage

The addon deploys the following dashboards from [perses/community-mixins](https://github.com/perses/community-mixins), which have functional parity with the Grafana dashboards shipped by kube-prometheus (kubernetes-mixin):

| Dashboard | Grafana equivalent |
|-----------|-------------------|
| API Server Overview | Kubernetes / API server |
| Controller Manager Overview | Kubernetes / Controller Manager |
| Kubelet Overview | Kubernetes / Kubelet |
| Cluster Resources Overview | Kubernetes / Compute Resources / Cluster |
| Node Resources Overview | Kubernetes / Compute Resources / Node |
| Namespace Resources Overview | Kubernetes / Compute Resources / Namespace |
| Pod Resources Overview | Kubernetes / Compute Resources / Pod |
| Workload Resources Overview | Kubernetes / Compute Resources / Workload |
| Multi-Cluster Resources Overview | Kubernetes / Compute Resources / Multi-Cluster |
| Cluster Networking Overview | Kubernetes / Networking / Cluster |
| Namespace Networking Overview | Kubernetes / Networking / Namespace |
| Pod Networking Overview | Kubernetes / Networking / Pod |
| Workload Networking Overview | Kubernetes / Networking / Workload |
| Workload NS Networking Overview | Kubernetes / Networking / Workload (NS) |
| Workload NS Resources Overview | Kubernetes / Compute Resources / Workload (NS) |
| Persistent Volume Overview | Kubernetes / Persistent Volumes |
| Proxy Overview | Kubernetes / Proxy |
| Scheduler Overview | Kubernetes / Scheduler |

## References

- [Perses project](https://perses.dev)
- [perses-operator](https://github.com/perses/perses-operator)
- [community-mixins](https://github.com/perses/community-mixins)
