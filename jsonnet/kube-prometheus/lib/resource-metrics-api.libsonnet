// Emits manifests for the configured resource metrics API implementation.
function(kp)
  if kp.values.common.resourceMetricsAPI == 'prometheus-adapter' then {
    ['prometheus-adapter-' + name]: kp.prometheusAdapter[name]
    for name in std.objectFields(kp.prometheusAdapter)
  } else if kp.values.common.resourceMetricsAPI == 'metrics-server' then {
    ['metrics-server-' + name]: kp.metricsServer[name]
    for name in std.objectFields(kp.metricsServer)
  } else
    error 'unsupported values.common.resourceMetricsAPI %q, must be "prometheus-adapter" or "metrics-server"' % kp.values.common.resourceMetricsAPI
