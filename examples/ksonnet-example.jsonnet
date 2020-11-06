((import 'kube-prometheus/kube-prometheus.libsonnet') + {
   nodeExporter+: {
     daemonset+: {
       metadata+: {
         namespace: 'my-custom-namespace',
       },
     },
   },
 }).nodeExporter.daemonset
