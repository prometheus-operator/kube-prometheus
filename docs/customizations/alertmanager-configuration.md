### Alertmanager configuration

The Alertmanager configuration is located in the `values.alertmanager.config` configuration field. In order to set a custom Alertmanager configuration simply set this field.

```jsonnet mdox-exec="cat examples/alertmanager-config.jsonnet"
((import 'kube-prometheus/main.libsonnet') + {
   values+:: {
     alertmanager+: {
       config: |||
         global:
           resolve_timeout: 10m
         route:
           group_by: ['job']
           group_wait: 30s
           group_interval: 5m
           repeat_interval: 12h
           receiver: 'null'
           routes:
           - match:
               alertname: Watchdog
             receiver: 'null'
         receivers:
         - name: 'null'
       |||,
     },
   },
 }).alertmanager.secret
```

In the above example the configuration has been inlined, but can just as well be an external file imported in jsonnet via the `importstr` function.

```jsonnet mdox-exec="cat examples/alertmanager-config-external.jsonnet"
((import 'kube-prometheus/main.libsonnet') + {
   values+:: {
     alertmanager+: {
       config: importstr 'alertmanager-config.yaml',
     },
   },
 }).alertmanager.secret
```
