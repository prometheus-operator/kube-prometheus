((import 'kube-prometheus/main.libsonnet') + {
   values+:: {
     alertmanager+: {
       config: importstr 'alertmanager-config.yaml',
     },
   },
 }).alertmanager.secret
