---
weight: 304
toc: true
title: Blackbox Exporter
menu:
    docs:
        parent: kube
lead: This guide will help you deploying the blackbox-exporter with the Probe custom resource definition.
images: []
draft: false
description: This guide will help you deploying the blackbox-exporter with the Probe custom resource definition.
date: "2021-03-08T08:49:31+00:00"
---

# Setting up a blackbox exporter

The `prometheus-operator` defines a `Probe` resource type that can be used to describe blackbox checks. To execute these, a separate component called [`blackbox_exporter`](https://github.com/prometheus/blackbox_exporter) has to be deployed, which can be scraped to retrieve the results of these checks. You can use `kube-prometheus` to set up such a blackbox exporter within your Kubernetes cluster.

## Adding blackbox exporter manifests to an existing `kube-prometheus` configuration

1. Override blackbox-related configuration parameters as needed.
2. Add the following to the list of renderers to render the blackbox exporter manifests:

```
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) }
```

## Configuration parameters influencing the blackbox exporter

* `_config.namespace`: the namespace where the various generated resources (`ConfigMap`, `Deployment`, `Service`, `ServiceAccount` and `ServiceMonitor`) will reside. This does not affect where you can place `Probe` objects; that is determined by the configuration of the `Prometheus` resource. This option is shared with other `kube-prometheus` components; defaults to `default`.
* `_config.imageRepos.blackboxExporter`: the name of the blackbox exporter image to deploy. Defaults to `quay.io/prometheus/blackbox-exporter`.
* `_config.versions.blackboxExporter`: the tag of the blackbox exporter image to deploy. Defaults to the version `kube-prometheus` was tested with.
* `_config.imageRepos.configmapReloader`: the name of the ConfigMap reloader image to deploy. Defaults to `jimmidyson/configmap-reload`.
* `_config.versions.configmapReloader`: the tag of the ConfigMap reloader image to deploy. Defaults to the version `kube-prometheus` was tested with.
* `_config.resources.blackbox-exporter.requests`: the requested resources; this is used for each container. Defaults to `10m` CPU and `20Mi` RAM. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ for details.
* `_config.resources.blackbox-exporter.limits`: the resource limits; this is used for each container. Defaults to `20m` CPU and `40Mi` RAM. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ for details.
* `_config.blackboxExporter.port`: the exposed HTTPS port of the exporter. This is what Prometheus can scrape for metrics related to the blackbox exporter itself. Defaults to `9115`.
* `_config.blackboxExporter.internalPort`: the internal plaintext port of the exporter. Prometheus scrapes configured via `Probe` objects cannot access the HTTPS port right now, so you have to specify this port in the `url` field. Defaults to `19115`.
* `_config.blackboxExporter.replicas`: the number of exporter replicas to be deployed. Defaults to `1`.
* `_config.blackboxExporter.matchLabels`: map of the labels to be used to select resources belonging to the instance deployed. Defaults to `{ 'app.kubernetes.io/name': 'blackbox-exporter' }`
* `_config.blackboxExporter.assignLabels`: map of the labels applied to components of the instance deployed. Defaults to all the labels included in the `matchLabels` option, and additionally `app.kubernetes.io/version` is set to the version of the blackbox exporter.
* `_config.blackboxExporter.modules`: the modules available in the blackbox exporter installation, i.e. the types of checks it can perform. The default value includes most of the modules defined in the default blackbox exporter configuration: `http_2xx`, `http_post_2xx`, `tcp_connect`, `pop3s_banner`, `ssh_banner`, and `irc_banner`. `icmp` is omitted so the exporter can be run with minimum privileges, but you can add it back if needed - see the example below. See https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md for the configuration format, except you have to use JSON instead of YAML here.
* `_config.blackboxExporter.privileged`: whether the `blackbox-exporter` container should be running as non-root (`false`) or root with heavily-restricted capability set (`true`). Defaults to `true` if you have any ICMP modules defined (which need the extra permissions) and `false` otherwise.

## Complete example

```jsonnet
local kp =
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
  {
    _config+:: {
      namespace: 'monitoring',
      blackboxExporter+:: {
        modules+:: {
          icmp: {
            prober: 'icmp',
          },
        },
      },
    },
  };

{ ['setup/0namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor is separated so that it can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

After installing the generated manifests, you can create `Probe` resources, for example:

```yaml
kind: Probe
apiVersion: monitoring.coreos.com/v1
metadata:
  name: example-com-website
  namespace: monitoring
spec:
  interval: 60s
  module: http_2xx
  prober:
    url: blackbox-exporter.monitoring.svc.cluster.local:19115
  targets:
    staticConfig:
      static:
      - http://example.com
      - https://example.com
```
