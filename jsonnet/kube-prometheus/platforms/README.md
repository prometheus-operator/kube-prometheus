# Adding a new platform specific configuration

Adding a new platform specific configuration requires to update the [customization example](https://github.com/prometheus-operator/kube-prometheus/blob/main/docs/customizations/platform-specific.md) and the [platforms.libsonnet](platforms.libsonnet) file by adding the platform to the list of existing ones. This allow the new platform to be discoverable and easily configurable by the users.
