### Internal Registry

Some Kubernetes installations source all their images from an internal registry. kube-prometheus supports this use case and helps the user synchronize every image it uses to the internal registry and generate manifests pointing at the internal registry.

To produce the `docker pull/tag/push` commands that will synchronize upstream images to `internal-registry.com/organization` (after having run the `jb` command to populate the vendor directory):

```shell
$ jsonnet -J vendor -S --tla-str repository=internal-registry.com/organization examples/sync-to-internal-registry.jsonnet
$ docker pull k8s.gcr.io/addon-resizer:1.8.4
$ docker tag k8s.gcr.io/addon-resizer:1.8.4 internal-registry.com/organization/addon-resizer:1.8.4
$ docker push internal-registry.com/organization/addon-resizer:1.8.4
$ docker pull quay.io/prometheus/alertmanager:v0.16.2
$ docker tag quay.io/prometheus/alertmanager:v0.16.2 internal-registry.com/organization/alertmanager:v0.16.2
$ docker push internal-registry.com/organization/alertmanager:v0.16.2
...
```

The output of this command can be piped to a shell to be executed by appending `| sh`.

Then to generate manifests with `internal-registry.com/organization`, use the `withImageRepository` mixin:

```jsonnet mdox-exec="cat examples/internal-registry.jsonnet"
local mixin = import 'kube-prometheus/addons/config-mixins.libsonnet';
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
} + mixin.withImageRepository('internal-registry.com/organization');

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```
