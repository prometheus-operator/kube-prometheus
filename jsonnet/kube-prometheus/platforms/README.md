# Adding a new platform specific configuration

Adding a new platform specific configuration requires to update the
[platforms.jsonnet](./platform.jsonnet) file by adding the platform to the list
of existing ones.

This allow configuring the new platform in the following way:

```jsonnet
(import 'kube-prometheus/main.libsonnet') +
  {
    values+:: {
      kubePrometheus+: {
        platform: 'example-platform',
      }
    }
  }
```
