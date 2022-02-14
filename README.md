# kube-prometheus

[![Build Status](https://github.com/prometheus-operator/kube-prometheus/workflows/ci/badge.svg)](https://github.com/prometheus-operator/kube-prometheus/actions)
[![Slack](https://img.shields.io/badge/join%20slack-%23prometheus--operator-brightgreen.svg)](http://slack.k8s.io/)
[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/prometheus-operator/kube-prometheus)

> Note that everything is experimental and may change significantly at any time.

This repository collects Kubernetes manifests, [Grafana](http://grafana.com/) dashboards, and [Prometheus rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/) combined with documentation and scripts to provide easy to operate end-to-end Kubernetes cluster monitoring with [Prometheus](https://prometheus.io/) using the Prometheus Operator.

The content of this project is written in [jsonnet](http://jsonnet.org/). This project could both be described as a package as well as a library.

Components included in this package:

* The [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
* Highly available [Prometheus](https://prometheus.io/)
* Highly available [Alertmanager](https://github.com/prometheus/alertmanager)
* [Prometheus node-exporter](https://github.com/prometheus/node_exporter)
* [Prometheus Adapter for Kubernetes Metrics APIs](https://github.com/DirectXMan12/k8s-prometheus-adapter)
* [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
* [Grafana](https://grafana.com/)

This stack is meant for cluster monitoring, so it is pre-configured to collect metrics from all Kubernetes components. In addition to that it delivers a default set of dashboards and alerting rules. Many of the useful dashboards and alerts come from the [kubernetes-mixin project](https://github.com/kubernetes-monitoring/kubernetes-mixin), similar to this project it provides composable jsonnet as a library for users to customize to their needs.

## Warning

If you are migrating from `release-0.7` branch or earlier please read [what changed and how to migrate in our guide](https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/migration-guide.md).

## Table of contents

- [kube-prometheus](#kube-prometheus)
  - [Warning](#warning)
  - [Table of contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
    - [minikube](#minikube)
  - [Compatibility](#compatibility)
    - [Kubernetes compatibility matrix](#kubernetes-compatibility-matrix)
  - [Quickstart](#quickstart)
    - [Access the dashboards](#access-the-dashboards)
  - [Customizing Kube-Prometheus](#customizing-kube-prometheus)
    - [Installing](#installing)
    - [Compiling](#compiling)
    - [Apply the kube-prometheus stack](#apply-the-kube-prometheus-stack)
    - [Containerized Installing and Compiling](#containerized-installing-and-compiling)
  - [Update from upstream project](#update-from-upstream-project)
    - [Update jb](#update-jb)
    - [Update kube-prometheus](#update-kube-prometheus)
    - [Compile the manifests and apply](#compile-the-manifests-and-apply)
  - [Configuration](#configuration)
  - [Customization Examples](#customization-examples)
  - [Minikube Example](#minikube-example)
  - [Continuous Delivery](#continuous-delivery)
  - [Security](docs/security.md)
  - [Troubleshooting](#troubleshooting)
    - [Error retrieving kubelet metrics](#error-retrieving-kubelet-metrics)
      - [Authentication problem](#authentication-problem)
      - [Authorization problem](#authorization-problem)
    - [kube-state-metrics resource usage](#kube-state-metrics-resource-usage)
    - [Error retrieving kube-proxy metrics](#error-retrieving-kube-proxy-metrics)
  - [Contributing](CONTRIBUTING.md)
  - [License](#license)

## Prerequisites

You will need a Kubernetes cluster, that's it! By default it is assumed, that the kubelet uses token authentication and authorization, as otherwise Prometheus needs a client certificate, which gives it full access to the kubelet, rather than just the metrics. Token authentication and authorization allows more fine grained and easier access control.

This means the kubelet configuration must contain these flags:

* `--authentication-token-webhook=true` This flag enables, that a `ServiceAccount` token can be used to authenticate against the kubelet(s). This can also be enabled by setting the kubelet configuration value `authentication.webhook.enabled` to `true`.
* `--authorization-mode=Webhook` This flag enables, that the kubelet will perform an RBAC request with the API to determine, whether the requesting entity (Prometheus in this case) is allowed to access a resource, in specific for this project the `/metrics` endpoint. This can also be enabled by setting the kubelet configuration value `authorization.mode` to `Webhook`.

This stack provides [resource metrics](https://github.com/kubernetes/metrics#resource-metrics-api) by deploying the [Prometheus Adapter](https://github.com/DirectXMan12/k8s-prometheus-adapter/).
This adapter is an Extension API Server and Kubernetes needs to be have this feature enabled, otherwise the adapter has no effect, but is still deployed.

### minikube

To try out this stack, start [minikube](https://github.com/kubernetes/minikube) with the following command:

```shell
$ minikube delete && minikube start --kubernetes-version=v1.20.0 --memory=6g --bootstrapper=kubeadm --extra-config=kubelet.authentication-token-webhook=true --extra-config=kubelet.authorization-mode=Webhook --extra-config=scheduler.bind-address=0.0.0.0 --extra-config=controller-manager.bind-address=0.0.0.0
```

The kube-prometheus stack includes a resource metrics API server, so the metrics-server addon is not necessary. Ensure the metrics-server addon is disabled on minikube:

```shell
$ minikube addons disable metrics-server
```

## Compatibility

### Kubernetes compatibility matrix

The following versions are supported and work as we test against these versions in their respective branches. But note that other versions might work!

| kube-prometheus stack                                                                      | Kubernetes 1.19 | Kubernetes 1.20 | Kubernetes 1.21 | Kubernetes 1.22 | Kubernetes 1.23 |
|--------------------------------------------------------------------------------------------|-----------------|-----------------|-----------------|-----------------|-----------------|
| [`release-0.7`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.7)   | ✔               | ✔               | ✗               | ✗               | ✗               |
| [`release-0.8`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.8)   | ✗               | ✔               | ✔               | ✗               | ✗               |
| [`release-0.9`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.9)   | ✗               | ✗               | ✔               | ✔               | ✗               |
| [`release-0.10`](https://github.com/prometheus-operator/kube-prometheus/tree/release-0.10) | ✗               | ✗               | ✗               | ✔               | ✔               |
| [`main`](https://github.com/prometheus-operator/kube-prometheus/tree/main)                 | ✗               | ✗               | ✗               | ✔               | ✔               |

## Quickstart

> Note: For versions before Kubernetes v1.21.z refer to the [Kubernetes compatibility matrix](#kubernetes-compatibility-matrix) in order to choose a compatible branch.

This project is intended to be used as a library (i.e. the intent is not for you to create your own modified copy of this repository).

Though for a quickstart a compiled version of the Kubernetes [manifests](manifests) generated with this library (specifically with `example.jsonnet`) is checked into this repository in order to try the content out quickly. To try out the stack un-customized run:
* Create the monitoring stack using the config in the `manifests` directory:

```shell
# Create the namespace and CRDs, and then wait for them to be available before creating the remaining resources
kubectl apply --server-side -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl apply -f manifests/
```

We create the namespace and CustomResourceDefinitions first to avoid race conditions when deploying the monitoring components.
Alternatively, the resources in both folders can be applied with a single command
`kubectl apply --server-side -f manifests/setup -f manifests`, but it may be necessary to run the command multiple times for all components to
be created successfully.

* And to teardown the stack:

```shell
kubectl delete --ignore-not-found=true -f manifests/ -f manifests/setup
```

### Access the dashboards

Prometheus, Grafana, and Alertmanager dashboards can be accessed quickly using `kubectl port-forward` after running the quickstart via the commands below. Kubernetes 1.10 or later is required.

> Note: There are instructions on how to route to these pods behind an ingress controller in the [Exposing Prometheus/Alermanager/Grafana via Ingress](docs/customizations/exposing-prometheus-alertmanager-grafana-ingress.md) section.

Prometheus

```shell
$ kubectl --namespace monitoring port-forward svc/prometheus-k8s 9090
```

Then access via [http://localhost:9090](http://localhost:9090)

Grafana

```shell
$ kubectl --namespace monitoring port-forward svc/grafana 3000
```

Then access via [http://localhost:3000](http://localhost:3000) and use the default grafana user:password of `admin:admin`.

Alert Manager

```shell
$ kubectl --namespace monitoring port-forward svc/alertmanager-main 9093
```

Then access via [http://localhost:9093](http://localhost:9093)

## Customizing Kube-Prometheus

This section:
* describes how to customize the kube-prometheus library via compiling the kube-prometheus manifests yourself (as an alternative to the [Quickstart section](#quickstart)).
* still doesn't require you to make a copy of this entire repository, but rather only a copy of a few select files.

### Installing

The content of this project consists of a set of [jsonnet](http://jsonnet.org/) files making up a library to be consumed.

Install this library in your own project with [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler#install) (the jsonnet package manager):

```shell
$ mkdir my-kube-prometheus; cd my-kube-prometheus
$ jb init  # Creates the initial/empty `jsonnetfile.json`
# Install the kube-prometheus dependency
$ jb install github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@main # Creates `vendor/` & `jsonnetfile.lock.json`, and fills in `jsonnetfile.json`

$ wget https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/example.jsonnet -O example.jsonnet
$ wget https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/build.sh -O build.sh
```

> `jb` can be installed with `go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest`

> An e.g. of how to install a given version of this library: `jb install github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@main`

In order to update the kube-prometheus dependency, simply use the jsonnet-bundler update functionality:

```shell
$ jb update
```

### Compiling

e.g. of how to compile the manifests: `./build.sh example.jsonnet`

> before compiling, install `gojsontoyaml` tool with `go install github.com/brancz/gojsontoyaml@latest` and `jsonnet` with `go install github.com/google/go-jsonnet/cmd/jsonnet@latest`

Here's [example.jsonnet](example.jsonnet):

> Note: some of the following components must be configured beforehand. See [configuration](#configuration) and [customization-examples](#customization-examples).

```jsonnet mdox-exec="cat example.jsonnet"
local kp =
  (import 'kube-prometheus/main.libsonnet') +
  // Uncomment the following imports to enable its patches
  // (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/managed-cluster.libsonnet') +
  // (import 'kube-prometheus/addons/node-ports.libsonnet') +
  // (import 'kube-prometheus/addons/static-etcd.libsonnet') +
  // (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
  // (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },
  };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
```

And here's the [build.sh](build.sh) script (which uses `vendor/` to render all manifests in a json structure of `{filename: manifest-content}`):

```sh mdox-exec="cat build.sh"
#!/usr/bin/env bash

# This script uses arg $1 (name of *.jsonnet file to use) to generate the manifests/*.yaml files.

set -e
set -x
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

# Make sure to use project tooling
PATH="$(pwd)/tmp/bin:${PATH}"

# Make sure to start with a clean 'manifests' dir
rm -rf manifests
mkdir -p manifests/setup

# Calling gojsontoyaml is optional, but we would like to generate yaml, not json
jsonnet -J vendor -m manifests "${1-example.jsonnet}" | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}

# Make sure to remove json files
find manifests -type f ! -name '*.yaml' -delete
rm -f kustomization

```

> Note you need `jsonnet` (`go get github.com/google/go-jsonnet/cmd/jsonnet`) and `gojsontoyaml` (`go get github.com/brancz/gojsontoyaml`) installed to run `build.sh`. If you just want json output, not yaml, then you can skip the pipe and everything afterwards.

This script runs the jsonnet code, then reads each key of the generated json and uses that as the file name, and writes the value of that key to that file, and converts each json manifest to yaml.

### Apply the kube-prometheus stack

The previous steps (compilation) has created a bunch of manifest files in the manifest/ folder.
Now simply use `kubectl` to install Prometheus and Grafana as per your configuration:

```shell
# Update the namespace and CRDs, and then wait for them to be available before creating the remaining resources
$ kubectl apply --server-side -f manifests/setup
$ kubectl apply -f manifests/
```

> Note that due to some CRD size we are using kubeclt server-side apply feature which is generally available since
> kubernetes 1.22. If you are using previous kubernetes versions this feature may not be available and you would need to
> use `kubectl create` instead.

Alternatively, the resources in both folders can be applied with a single command
`kubectl apply --server-side -Rf manifests`, but it may be necessary to run the command multiple times for all components to
be created successfully.

Check the monitoring namespace (or the namespace you have specific in `namespace: `) and make sure the pods are running. Prometheus and Grafana should be up and running soon.

### Containerized Installing and Compiling

If you don't care to have `jb` nor `jsonnet` nor `gojsontoyaml` installed, then use `quay.io/coreos/jsonnet-ci` container image. Do the following from this `kube-prometheus` directory:

```shell
$ docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) quay.io/coreos/jsonnet-ci jb update
$ docker run --rm -v $(pwd):$(pwd) --workdir $(pwd) quay.io/coreos/jsonnet-ci ./build.sh example.jsonnet
```

## Update from upstream project

You may wish to fetch changes made on this project so they are available to you.

### Update jb

`jb` may have been updated so it's a good idea to get the latest version of this binary:

```shell
$ go get -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
```

### Update kube-prometheus

The command below will sync with upstream project:

```shell
$ jb update
```

### Compile the manifests and apply

Once updated, just follow the instructions under "Compiling" and "Apply the kube-prometheus stack" to apply the changes to your cluster.

## Configuration

Jsonnet has the concept of hidden fields. These are fields, that are not going to be rendered in a result. This is used to configure the kube-prometheus components in jsonnet. In the example jsonnet code of the above [Customizing Kube-Prometheus section](#customizing-kube-prometheus), you can see an example of this, where the `namespace` is being configured to be `monitoring`. In order to not override the whole object, use the `+::` construct of jsonnet, to merge objects, this way you can override individual settings, but retain all other settings and defaults.

The available fields and their default values can be seen in [main.libsonnet](jsonnet/kube-prometheus/main.libsonnet). Note that many of the fields get their default values from variables, and for example the version numbers are imported from [versions.json](jsonnet/kube-prometheus/versions.json).

Configuration is mainly done in the `values` map. You can see this being used in the `example.jsonnet` to set the namespace to `monitoring`. This is done in the `common` field, which all other components take their default value from. See for example how Alertmanager is configured in `main.libsonnet`:

```
    alertmanager: {
      name: 'main',
      // Use the namespace specified under values.common by default.
      namespace: $.values.common.namespace,
      version: $.values.common.versions.alertmanager,
      image: $.values.common.images.alertmanager,
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
```

The grafana definition is located in a different project (https://github.com/brancz/kubernetes-grafana ), but needed configuration can be customized from the same top level `values` field. For example to allow anonymous access to grafana, add the following `values` section:

```
      grafana+:: {
        config: { // http://docs.grafana.org/installation/configuration/
          sections: {
            "auth.anonymous": {enabled: true},
          },
        },
      },
```

## Customization Examples

Jsonnet is a turing complete language, any logic can be reflected in it. It also has powerful merge functionalities, allowing sophisticated customizations of any kind simply by merging it into the object the library provides.

To get started, we provide several customization examples in the [docs/customizations/](docs/customizations) section.

## Minikube Example

To use an easy to reproduce example, see [minikube.jsonnet](examples/minikube.jsonnet), which uses the minikube setup as demonstrated in [Prerequisites](#prerequisites). Because we would like easy access to our Prometheus, Alertmanager and Grafana UIs, `minikube.jsonnet` exposes the services as NodePort type services.

## Continuous Delivery

Working examples of use with continuous delivery tools are found in examples/continuous-delivery.

## Troubleshooting

See the general [guidelines](docs/community-support.md) for getting support from the community.

### Error retrieving kubelet metrics

Should the Prometheus `/targets` page show kubelet targets, but not able to successfully scrape the metrics, then most likely it is a problem with the authentication and authorization setup of the kubelets.

As described in the [Prerequisites](#prerequisites) section, in order to retrieve metrics from the kubelet token authentication and authorization must be enabled. Some Kubernetes setup tools do not enable this by default.

- If you are using Google's GKE product, see [cAdvisor support](docs/GKE-cadvisor-support.md).
- If you are using AWS EKS, see [AWS EKS CNI support](docs/EKS-cni-support.md).
- If you are using Weave Net, see [Weave Net support](docs/weave-net-support.md).

#### Authentication problem

The Prometheus `/targets` page will show the kubelet job with the error `403 Unauthorized`, when token authentication is not enabled. Ensure, that the `--authentication-token-webhook=true` flag is enabled on all kubelet configurations.

#### Authorization problem

The Prometheus `/targets` page will show the kubelet job with the error `401 Unauthorized`, when token authorization is not enabled. Ensure that the `--authorization-mode=Webhook` flag is enabled on all kubelet configurations.

### kube-state-metrics resource usage

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

### Error retrieving kube-proxy metrics

By default, kubeadm will configure kube-proxy to listen on 127.0.0.1 for metrics. Because of this prometheus would not be able to scrape these metrics. This would have to be changed to 0.0.0.0 in one of the following two places:

1. Before cluster initialization, the config file passed to kubeadm init should have KubeProxyConfiguration manifest with the field metricsBindAddress set to 0.0.0.0:10249
2. If the k8s cluster is already up and running, we'll have to modify the configmap kube-proxy in the namespace kube-system and set the metricsBindAddress field. After this kube-proxy daemonset would have to be restarted with
   `kubectl -n kube-system rollout restart daemonset kube-proxy`

## License

Apache License 2.0, see [LICENSE](https://github.com/prometheus-operator/kube-prometheus/blob/main/LICENSE).
