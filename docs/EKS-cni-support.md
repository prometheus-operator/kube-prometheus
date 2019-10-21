# CNI monitoring special configuration updates for EKS

AWS EKS uses [CNI](https://github.com/aws/amazon-vpc-cni-k8s) networking plugin for pod networking in Kubernetes using Elastic Network Interfaces on AWS

One fatal issue that can occur is that you run out of IP addresses in your eks cluster. (Generally happens due to error configs where pods keep scheduling).

You can monitor the `awscni` using kube-promethus with : 
```
local kp = (import 'kube-prometheus/kube-prometheus.libsonnet') +
    (import 'kube-prometheus/kube-prometheus-aws-eks-cni.libsonnet') +
	{
        _config+:: {
		# ... config here
		}
    };
```

After you have the required yaml file please run

```
kubectl apply -f manifests/prometheus-serviceMonitorAwsEksCNI.yaml
```
