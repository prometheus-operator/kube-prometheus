### Running kube-prometheus on specific platforms

A common example is that not all Kubernetes clusters are created exactly the same way, meaning the configuration to monitor them may be slightly different. For the following clusters there are mixins available to easily configure them:

* aws
* bootkube
* eks
* gke
* kops
* kops_coredns
* kubeadm
* kubespray

These mixins are selectable via the `platform` field of kubePrometheus:

```jsonnet mdox-exec="cat examples/jsonnet-snippets/platform.jsonnet"
(import 'kube-prometheus/main.libsonnet') +
{
  values+:: {
    common+: {
      platform: 'example-platform',
    },
  },
}
```
