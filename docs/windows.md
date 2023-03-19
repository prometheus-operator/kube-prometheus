# Windows

The [Windows addon](../examples/windows.jsonnet) adds the dashboards and rules from [kubernetes-monitoring/kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin#dashboards-for-windows-nodes).

Currently, Docker based Windows does not support running with [windows_exporter](https://github.com/prometheus-community/windows_exporter) in a pod so this add on uses [additional scrape configuration](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/additional-scrape-config.md) to set up a static config to scrape the node ports where windows_exporter is configured.

The addon requires you to specify the node ips and ports where it can find the windows_exporter. See the [full example](../examples/windows.jsonnet) for setup.

```
local kp = (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/windows.libsonnet') +
  {
    values+:: {
      windowsScrapeConfig+:: {
          static_configs: {
              targets: ["10.240.0.65:5000", "10.240.0.63:5000"],
          },
      },
    },
  };
```

[Containerd](https://github.com/prometheus-community/windows_exporter/blob/master/kubernetes/kubernetes.md) version can run as pod.



```
local kp = (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/windows-hostprocess.libsonnet') +
  {
    values+:: {
      windowsExporter+:: {
        image: "ghcr.io/prometheus-community/windows-exporter",
        version: "0.21.0",
      },
    },
  };

{ ['windows-exporter-' + name]: kp.windowsExporter[name] for name in std.objectFields(kp.windowsExporter) }
```

See the [full example](../examples/windows-hostprocess.jsonnet) for setup.