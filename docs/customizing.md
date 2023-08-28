# Customizing Kube-Prometheus

This section:
* describes how to customize the kube-prometheus library via compiling the kube-prometheus manifests yourself (as an alternative to the [README.md quickstart section](../README.md#quickstart)).
* still doesn't require you to make a copy of this entire repository, but rather only a copy of a few select files.

## Installing

The content of this project consists of a set of [jsonnet](http://jsonnet.org/) files making up a library to be consumed.

Install this library in your own project with [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler#install) (the jsonnet package manager):

```shell
$ mkdir my-kube-prometheus; cd my-kube-prometheus
$ jb init  # Creates the initial/empty `jsonnetfile.json`
# Install the kube-prometheus dependency
$ jb install github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@main # Creates `vendor/` & `jsonnetfile.lock.json`, and fills in `jsonnetfile.json`

$ wget https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/example.jsonnet -O example.jsonnet
$ wget https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/build.sh -O build.sh
$ chmod +x build.sh
```

> `jb` can be installed with `go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest`

> An e.g. of how to install a given version of this library: `jb install github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@main`

In order to update the kube-prometheus dependency, simply use the jsonnet-bundler update functionality:

```shell
$ jb update
```

## Generating

e.g. of how to compile the manifests: `./build.sh example.jsonnet`

> before compiling, install `gojsontoyaml` tool with `go install github.com/brancz/gojsontoyaml@latest` and `jsonnet` with `go install github.com/google/go-jsonnet/cmd/jsonnet@latest`

Here's [example.jsonnet](../example.jsonnet):

> Note: some of the following components must be configured beforehand. See [configuration](#configuring) and [customization-examples](customizations).

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
  // (import 'kube-prometheus/addons/pyrra.libsonnet') +
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
// { 'setup/pyrra-slo-CustomResourceDefinition': kp.pyrra.crd } +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
// { ['pyrra-' + name]: kp.pyrra[name] for name in std.objectFields(kp.pyrra) if name != 'crd' } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
```

And here's the [build.sh](../build.sh) script (which uses `vendor/` to render all manifests in a json structure of `{filename: manifest-content}`):

```sh mdox-exec="cat ./build.sh"
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

> Note you need `jsonnet` (`go install github.com/google/go-jsonnet/cmd/jsonnet@latest`) and `gojsontoyaml` (`go install github.com/brancz/gojsontoyaml@latest`) installed to run `build.sh`. If you just want json output, not yaml, then you can skip the pipe and everything afterwards.

This script runs the jsonnet code, then reads each key of the generated json and uses that as the file name, and writes the value of that key to that file, and converts each json manifest to yaml.

## Configuring

Jsonnet has the concept of hidden fields. These are fields, that are not going to be rendered in a result. This is used to configure the kube-prometheus components in jsonnet. In the example jsonnet code of the above [Generating section](#generating), you can see an example of this, where the `namespace` is being configured to be `monitoring`. In order to not override the whole object, use the `+::` construct of jsonnet, to merge objects, this way you can override individual settings, but retain all other settings and defaults.

The available fields and their default values can be seen in [main.libsonnet](../jsonnet/kube-prometheus/main.libsonnet). Note that many of the fields get their default values from variables, and for example the version numbers are imported from [versions.json](../jsonnet/kube-prometheus/versions.json).

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

## Apply the kube-prometheus stack

The previous generation step has created a bunch of manifest files in the manifest/ folder.
Now simply use `kubectl` to install Prometheus and Grafana as per your configuration:

```shell
# Update the namespace and CRDs, and then wait for them to be available before creating the remaining resources
$ kubectl apply --server-side -f manifests/setup
$ kubectl apply -f manifests/
```

> Note that due to some CRD size we are using kubectl server-side apply feature which is generally available since
> kubernetes 1.22. If you are using previous kubernetes versions this feature may not be available and you would need to
> use `kubectl create` instead.

Alternatively, the resources in both folders can be applied with a single command
`kubectl apply --server-side -Rf manifests`, but it may be necessary to run the command multiple times for all components to
be created successfully.

Check the monitoring namespace (or the namespace you have specific in `namespace: `) and make sure the pods are running. Prometheus and Grafana should be up and running soon.

## Minikube Example

To use an easy to reproduce example, see [minikube.jsonnet](../examples/minikube.jsonnet), which uses the minikube setup as demonstrated in [Prerequisites](../README.md#prerequisites). Because we would like easy access to our Prometheus, Alertmanager and Grafana UIs, `minikube.jsonnet` exposes the services as NodePort type services.
