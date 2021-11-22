# Adding a new platform specific configuration

Adding a new platform specific configuration requires to update the [customization example](../../../docs/customizations/platform-specific.md#running-kube-prometheus-on-specific-platforms) and the [platforms.libsonnet](platforms.libsonnet) file by adding the platform to the list of existing ones. This allow the new platform to be discoverable and easily configurable by the users.
