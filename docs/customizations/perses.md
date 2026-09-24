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
> Perses is currently integrated as an addon. Once the integration is mature, it may be promoted to a built-in toggle (similar to the `metrics-server` / `prometheus-adapter` switch).

[Perses](https://perses.dev) is a CNCF Sandbox observability visualization platform. The `perses` addon deploys Perses and Kubernetes observability dashboards from [community-mixins](https://github.com/perses/community-mixins) via the [perses-operator](https://github.com/perses/perses-operator). In jsonnet, Grafana is omitted by setting `grafana: {}` (see [`examples/perses.jsonnet`](../../examples/perses.jsonnet)). On an existing cluster, `kubectl apply` does not delete Grafana — remove it explicitly after you are ready (see [Remove Grafana](#remove-grafana-optional)).

## What the addon deploys

| Resource              | Kind                             | Description                                                                    |
|-----------------------|----------------------------------|--------------------------------------------------------------------------------|
| perses-operator       | Deployment, RBAC, ServiceAccount | Manages Perses CRs declaratively                                               |
| 4 CRDs                | CustomResourceDefinition         | `Perses`, `PersesDashboard`, `PersesDatasource`, `PersesGlobalDatasource`      |
| Perses instance       | `Perses` CR                      | Runs the Perses server (port 8080)                                             |
| Prometheus datasource | `PersesGlobalDatasource` CR      | Proxies queries to `prometheus-k8s` Service                                    |
| Dashboards            | `PersesDashboard` CRs            | Default community-mixins packages (see [Dashboard coverage](#dashboard-coverage)) |
| ServiceMonitor        | `ServiceMonitor`                 | Scrapes operator metrics                                                       |
| PrometheusRule        | `PrometheusRule`                 | Operator alerting rules                                                        |

The addon also patches the existing Prometheus `NetworkPolicy` so Perses pods can query Prometheus.

> [!NOTE]
> **Security:** Perses runs with authentication disabled by default, matching the bundled Grafana setup in kube-prometheus. Enable auth and secure cookies for production deployments.
>
> **Storage:** Dashboards and datasource configuration are stored in Kubernetes CRs. The Perses server uses ephemeral file storage for runtime state; pod restarts do not remove `PersesDashboard` or `PersesGlobalDatasource` objects.

## Generate and apply

Generate the full stack with Perses instead of Grafana:

```shell
make manifests-perses
```

> [!IMPORTANT]
> `make manifests-perses` regenerates the entire `manifests/` tree from [`examples/perses.jsonnet`](../../examples/perses.jsonnet) (not only Perses objects).

Apply the generated manifests:

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
kubectl --namespace monitoring port-forward svc/perses 8080:8080
```

Open Perses at [http://localhost:8080](http://localhost:8080). The operator creates a Service named after the `Perses` CR (`perses` by default). Dashboards and the Prometheus datasource are loaded from CRs.

### Using a custom jsonnet file

See [`examples/perses.jsonnet`](../../examples/perses.jsonnet). Generate with `./build.sh my-perses.jsonnet`.

## Remove Grafana (optional)

On an **existing** kube-prometheus cluster, `kubectl apply` does not remove resources that disappeared from the generated manifests, so Grafana keeps running alongside Perses. That is fine for evaluation — you can run both UIs in parallel while verifying coverage.

Once you are satisfied with Perses, delete Grafana by label:

```shell
kubectl -n monitoring delete --ignore-not-found=true \
  deployment,service,serviceaccount,servicemonitor,networkpolicy,prometheusrule,secret,configmap \
  -l app.kubernetes.io/name=grafana
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

Default images are `persesdev/perses:v<version>` and `persesdev/perses-operator:v<version>`.

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

### Dashboard query selectors

The Perses addon imports pre-generated dashboards from [community-mixins](https://github.com/perses/community-mixins), which use kubernetes-mixin default job labels. kube-prometheus overrides those selectors for Grafana via `kubernetesControlPlane`; the addon applies the same rewiring when importing dashboards:

| community-mixins       | kube-prometheus                                   |
|------------------------|---------------------------------------------------|
| `job="cadvisor"`       | `job="kubelet", metrics_path="/metrics/cadvisor"` |
| `job="kube-apiserver"` | `job="apiserver"`                                 |

The addon also sets `prometheus.externalLabels.cluster` to `kube-prometheus` so the `cluster` dashboard variable resolves (required by kubernetes-mixin dashboards). Override either if your scrape labels differ:

```jsonnet
{
  values+:: {
    prometheus+: {
      externalLabels+: {
        cluster: 'my-cluster',
      },
    },
    perses+: {
      cadvisorJobSelector: 'job="kubelet", metrics_path="/metrics/cadvisor"',
      kubeApiserverJobSelector: 'job="apiserver"',
    },
  },
}
```

### Change the Prometheus datasource URL

By default the datasource proxies queries through the Perses server to `http://prometheus-k8s.<namespace>.svc.cluster.local:9090` (see [`perses.libsonnet`](../../jsonnet/kube-prometheus/addons/perses.libsonnet)). Patch the generated component to use a different URL:

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

### Select dashboard packages

Override `dashboardComponents` to change which community-mixins packages are imported. Defaults are `kubernetes`, `prometheus`, `alertmanager`, and `node-exporter`.

Trim to a subset:

```jsonnet
{
  values+:: {
    perses+: {
      dashboardComponents: ['kubernetes', 'prometheus', 'alertmanager'],
    },
  },
}
```

Include optional packages (for example blackbox-exporter and Perses overview):

```jsonnet
{
  values+:: {
    perses+: {
      dashboardComponents: [
        'kubernetes',
        'prometheus',
        'alertmanager',
        'node-exporter',
        'blackbox-exporter',
        'perses',
      ],
    },
  },
}
```

Available component names match [community-mixins `dashboards.libsonnet`](https://github.com/perses/community-mixins/blob/main/jsonnet/dashboards.libsonnet).

## Dashboard coverage

> [!NOTE]
> The counts and component lists below reflect the state of [community-mixins](https://github.com/perses/community-mixins) vendored at the time of this release. Community-mixins is under active development and may add new dashboards or components at any time. Check the upstream repository for the latest coverage.

Dashboards are imported from community-mixins via its [`dashboards.libsonnet`](https://github.com/perses/community-mixins/blob/main/jsonnet/dashboards.libsonnet) helper (namespace, datasource, and labels), then rewired for kube-prometheus scrape labels.

### Default packages (23 `PersesDashboard` CRs)

| Component       | Perses dashboards                                         | kube-prometheus component |
|-----------------|-----------------------------------------------------------|---------------------------|
| `kubernetes`    | 18 Kubernetes / control-plane and workload dashboards     | `kubernetesControlPlane`  |
| `prometheus`    | `prometheus-overview`, `prometheus-remote-write`          | `prometheus`              |
| `alertmanager`  | `alertmanager-overview`                                   | `alertmanager`            |
| `node-exporter` | `node-exporter-nodes`, `node-exporter-cluster-use-method` | `nodeExporter`            |

### Optional packages

Enable these via `dashboardComponents` (see [Select dashboard packages](#select-dashboard-packages)). Thanos and etcd panels may be empty until those targets are scraped.

| Component           | Perses dashboards     | kube-prometheus component / addon               |
|---------------------|-----------------------|-------------------------------------------------|
| `blackbox-exporter` | `blackbox-overview`   | `blackboxExporter`                              |
| `perses`            | `perses-overview`     | Perses addon                                    |
| `thanos`            | 6 Thanos component dashboards | Prometheus Thanos sidecar (when enabled) |
| `etcd`              | `etcd-overview`       | `static-etcd` addon or external etcd monitoring |

These kube-prometheus components have **no Perses dashboard in community-mixins yet**: `kube-state-metrics`, `prometheus-operator`, `prometheus-adapter`, and `metrics-server`.

Authoritative configuration is in [`perses.libsonnet`](../../jsonnet/kube-prometheus/addons/perses.libsonnet). Run `make manifests-perses` after addon or mixin updates.

## Switching back to Grafana

To revert to Grafana, regenerate default manifests and reapply, then remove Perses resources that are no longer in the manifests:

```shell
make manifests
kubectl apply --server-side -f manifests/setup
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
kubectl apply -f manifests/

# Perses CRs (instance and dashboards are namespaced; global datasource is cluster-scoped)
kubectl -n monitoring delete --ignore-not-found=true perses/perses
kubectl delete --ignore-not-found=true \
  persesglobaldatasources.perses.dev/prometheus-datasource
kubectl -n monitoring delete --ignore-not-found=true \
  persesdashboards.perses.dev --all

# Operator resources (all carry app.kubernetes.io/part-of=perses-operator)
kubectl -n monitoring delete --ignore-not-found=true \
  deployment,service,serviceaccount,servicemonitor,networkpolicy,prometheusrule,role,rolebinding \
  -l app.kubernetes.io/part-of=perses-operator
kubectl delete --ignore-not-found=true clusterrole,clusterrolebinding \
  -l app.kubernetes.io/part-of=perses-operator
```

Optionally, remove the `perses.dev` CRDs if you no longer need them:

```shell
kubectl delete --ignore-not-found=true crd \
  perses.perses.dev \
  persesdashboards.perses.dev \
  persesdatasources.perses.dev \
  persesglobaldatasources.perses.dev
```

## Testing

`make test-e2e-perses` runs Go end-to-end tests against a cluster that already has the Perses stack deployed. It does **not** generate or apply manifests — follow [Generate and apply](#generate-and-apply) first, then:

```shell
export KUBECONFIG=~/.kube/config   # point at your test cluster
make test-e2e-perses
```

CI follows the same order: generate manifests, deploy to a kind cluster, then run `make test-e2e-perses` (see [`.github/workflows/ci.yaml`](../../.github/workflows/ci.yaml)).

## References

- [Perses project](https://perses.dev)
- [perses-operator](https://github.com/perses/perses-operator)
- [community-mixins](https://github.com/perses/community-mixins)
