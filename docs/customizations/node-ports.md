### NodePorts

Another mixin that may be useful for exploring the stack is to expose the UIs of Prometheus, Alertmanager and Grafana on NodePorts:

```jsonnet mdox-exec="cat examples/jsonnet-snippets/node-ports.jsonnet"
(import 'kube-prometheus/main.libsonnet') +
(import 'kube-prometheus/addons/node-ports.libsonnet')
```
