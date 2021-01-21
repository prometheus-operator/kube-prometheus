((import 'kube-prometheus/main.libsonnet') + {
   nodeExporter+: {
     daemonset+: {
       metadata+: {
         namespace: 'my-custom-namespace',
       },
     },
   },
 }).nodeExporter.daemonset
