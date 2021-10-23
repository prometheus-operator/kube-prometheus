# Migration guide from release-0.7 and earlier

## Why?

Thanks to our community we identified a lot of short-commings of previous design, varying from issues with global state to UX problems. Hoping to fix at least part of those issues we decided to do a complete refactor of the codebase.

## Overview

### Breaking Changes

- global `_config` object is removed and the new `values` object is a partial replacement
- `imageRepos` field was removed and the project no longer tries to compose image strings. Use `$.values.common.images` to override default images.
- prometheus alerting and recording rules are split into multiple `PrometheusRule` objects
- kubernetes control plane ServiceMonitors and Services are now part of the new `kubernetesControlPlane` top-level object instead of `prometheus` object
- `jsonnet/kube-prometheus/kube-prometheus.libsonnet` file was renamed to `jsonnet/kube-prometheus/main.libsonnet` and slimmed down to bare minimum
- `jsonnet/kube-prometheus/kube-prometheus*-.libsonnet` files were move either to `jsonnet/kube-prometheus/addons/` or `jsonnet/kube-prometheus/platforms/` depending on the feature they provided
- all component libraries are now function- and not object-based
- monitoring-mixins are included inside each component and not globally. `prometheusRules`, `prometheusAlerts`, and `grafanaDashboards` are accessible only per component via `mixin` object (ex. `$.alertmanager.mixin.prometheusAlerts`)
- default repository branch changed from `master` to `main`
- labels on resources have changes, `kubectl apply` will not work correctly due to those field being immutable. Deleting the resource first before applying is a workaround if you are using the kubectl CLI. (This only applies to `Deployments` and `DaemonSets`.)

### New Features

- concept of `addons`, `components`, and `platforms` was introduced
- all main `components` are now represented internally by a function with default values and required parameters (see #Component-configuration for more information)
- `$.values` holds main configuration parameters and should be used to set basic stack configuration.
- common parameters across all `components` are stored now in `$.values.common`
- removed dependency on deprecated ksonnet library

## Details

### Components, Addons, Platforms

Those concepts were already present in the repository but it wasn't clear which file is holding what. After refactoring we categorized jsonnet code into 3 buckets and put them into separate directories:
- `components` - main building blocks for kube-prometheus, written as functions responsible for creating multiple objects representing kubernetes manifests. For example all objects for node_exporter deployment are bundled in `components/node_exporter.libsonnet` library
- `addons` - everything that can enhance kube-prometheus deployment. Those are small snippets of code adding a small feature, for example adding anti-affinity to pods via [`addons/anti-affinity.libsonnet`](https://github.com/prometheus-operator/kube-prometheus/blob/main/jsonnet/kube-prometheus/addons/anti-affinity.libsonnet). Addons are meant to be used in object-oriented way like `local kp = (import 'kube-prometheus/main.libsonnet') + (import 'kube-prometheus/addons/all-namespaces.libsonnet')`
- `platforms` - currently those are `addons` specialized to allow deploying kube-prometheus project on a specific platform.

### Component configuration

Refactoring main components to use functions allowed us to define APIs for said components. Each function has a default set of parameters that can be overridden or that are required to be set by a user. Those default parameters are represented in each component by `defaults` map at the top of each library file, for example in [`node_exporter.libsonnet`](https://github.com/prometheus-operator/kube-prometheus/blob/1d2a0e275af97948667777739a18b24464480dc8/jsonnet/kube-prometheus/components/node-exporter.libsonnet#L3-L34).

This API is meant to ease the use of kube-prometheus as parameters can be passed from a JSON file and don't need to be in jsonnet format. However, if you need to modify particular parts of the stack, jsonnet allows you to do this and we are also not restricting such access in any way. An example of such modifications can be seen in any of our `addons`, like the [`addons/anti-affinity.libsonnet`](https://github.com/prometheus-operator/kube-prometheus/blob/main/jsonnet/kube-prometheus/addons/anti-affinity.libsonnet) one.

### Mixin integration

Previously kube-prometheus project joined all mixins on a global level. However with a wider adoption of monitoring mixins this turned out to be a problem, especially apparent when two mixins started to use the same configuration field for different purposes. To fix this we moved all mixins into their own respective components:
- alertmanager mixin -> `alertmanager.libsonnet`
- kubernetes mixin -> `k8s-control-plane.libsonnet`
- kube-state-metrics mixin -> `kube-state-metrics.libsonnet`
- node_exporter mixin -> `node_exporter.libsonnet`
- prometheus and thanos sidecar mixins -> `prometheus.libsonnet`
- prometheus-operator mixin -> `prometheus-operator.libsonnet`
- kube-prometheus alerts and rules -> `components/mixin/custom.libsonnet`

> etcd mixin is a special case as we add it inside an `addon` in `addons/static-etcd.libsonnet`

This results in creating multiple `PrometheusRule` objects instead of having one giant object as before. It also means each mixin is configured separately and accessing mixin objects is done via `$.<component>.mixin`.

## Examples

All examples from `examples/` directory were adapted to the new codebase. [Please take a look at them for guideance](https://github.com/prometheus-operator/kube-prometheus/tree/main/examples)

## Legacy migration

An example of conversion of a legacy release-0.3 my.jsonnet file to release-0.8 can be found in [migration-example](migration-example)

## Advanced usage examples

For more advanced usage examples you can take a look at those two, open to public, implementations:
- [thaum-xyz/ankhmorpork](https://github.com/thaum-xyz/ankhmorpork/blob/master/apps/monitoring/jsonnet) - extending kube-prometheus to adapt to a required environment
- [openshift/cluster-monitoring-operator](https://github.com/openshift/cluster-monitoring-operator/pull/1044) - using kube-prometheus components as standalone libraries to build a custom solution

## Final note

Refactoring was a huge undertaking and possibly this document didn't describe in enough detail how to help you with migration to the new stack. If that is the case, please reach out to us by using [GitHub discussions](https://github.com/prometheus-operator/kube-prometheus/discussions) feature or directly on [#prometheus-operator kubernetes slack channel](http://slack.k8s.io/).
