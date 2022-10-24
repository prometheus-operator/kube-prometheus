---
weight: 302
toc: true
title: Deploy to kubeadm
menu:
    docs:
        parent: kube
lead: This guide will help you deploying kube-prometheus on Kubernetes kubeadm.
images: []
draft: false
description: This guide will help you deploying kube-prometheus on Kubernetes kubeadm.
---

The [kubeadm](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/) tool is linked by Kubernetes as the offical way to deploy and manage self-hosted clusters. kubeadm does a lot of heavy lifting by automatically configuring your Kubernetes cluster with some common options. This guide is intended to show you how to deploy Prometheus, Prometheus Operator and Kube Prometheus to get you started monitoring your cluster that was deployed with kubeadm.

This guide assumes you have a basic understanding of how to use the functionality the Prometheus Operator implements. If you haven't yet, we recommend reading through the [getting started guide](https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/getting-started.md) as well as the [alerting guide](https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/alerting.md).

## kubeadm Pre-requisites

This guide assumes you have some familiarity with `kubeadm` or at least have deployed a cluster using `kubeadm`. By default, `kubeadm` does not expose two of the services that we will be monitoring. Therefore, in order to get the most out of the `kube-prometheus` package, we need to make some quick tweaks to the Kubernetes cluster. Since we will be monitoring the `kube-controller-manager` and `kube-scheduler`, we must expose them to the cluster.

By default, `kubeadm` runs these pods on your master and bound to `127.0.0.1`. There are a couple of ways to change this. The recommended way to change these features is to use the [kubeadm config file](https://kubernetes.io/docs/reference/generated/kubeadm/#config-file). An example configuration file can be used:

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
controlPlaneEndpoint: "192.168.1.173:6443"
apiServer:
  extraArgs:
    authorization-mode: "Node,RBAC"
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
certificatesDir: "/etc/kubernetes/pki"
etcd:
  # one of local or external
  local:
    dataDir: "/var/lib/etcd"
kubernetesVersion: "v1.23.1"
networking:
  dnsDomain: "cluster.local"
  serviceSubnet: "10.96.0.0/12"
imageRepository: "registry.k8s.io"
```

Notice the `.scheduler.extraArgs` and `.controllerManager.extraArgs`. This exposes the `kube-controller-manager` and `kube-scheduler` services to the rest of the cluster. If you have kubernetes core components as pods in the kube-system namespace, ensure that the `kube-prometheus-exporter-kube-scheduler` and `kube-prometheus-exporter-kube-controller-manager` services' `spec.selector` values match those of pods.

In previous versions of Kubernetes, we had to make a change to the `kubelet` setting with regard to `cAdvisor` monitoring on the control-plane as well as all the nodes. But this is **no longer required due to [the change of Kubernetes](https://github.com/kubernetes/kubernetes/issues/56523)**.

In case you already have a Kubernetes deployed with kubeadm, change the address kube-controller-manager and kube-scheduler listens in addition to previous kubelet change:

```
sed -e "s/- --bind-address=127.0.0.1/- --bind-address=0.0.0.0/" -i /etc/kubernetes/manifests/kube-controller-manager.yaml
sed -e "s/- --bind-address=127.0.0.1/- --bind-address=0.0.0.0/" -i /etc/kubernetes/manifests/kube-scheduler.yaml
```

With these changes, your Kubernetes cluster is ready.

## Metric Sources

Monitoring a Kubernetes cluster with Prometheus is a natural choice as Kubernetes components themselves are instrumented with Prometheus metrics, therefore those components simply have to be discovered by Prometheus and most of the cluster is monitored.

Metrics that are rather about cluster state than a single component's metrics is exposed by the add-on component [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics).

Additionally, to have an overview of cluster nodes' resources the Prometheus [node_exporter](https://github.com/prometheus/node_exporter) is used. The node_exporter allows monitoring a node's resources: CPU, memory and disk utilization and more.

Once you complete this guide you will monitor the following:

* cluster state via kube-state-metrics
* nodes via the node_exporter
* kubelets
* apiserver
* kube-scheduler
* kube-controller-manager

## Getting Up and Running Fast with Kube-Prometheus

To help get started more quickly with monitoring Kubernetes clusters, [kube-prometheus](https://github.com/coreos/kube-prometheus) was created. It is a collection of manifests including dashboards and alerting rules that can easily be deployed. It utilizes the Prometheus Operator and all the manifests demonstrated in this guide.

This section represent a quick installation and is not intended to teach you about all the components. The easiest way to get started is to clone this repository and use the `kube-prometheus` section of the code.

```
git clone https://github.com/coreos/kube-prometheus
cd kube-prometheus/
```

First, create the namespace in which you want the monitoring tool suite to be running.

```
export NAMESPACE='monitoring'
kubectl create namespace "$NAMESPACE"
```

Now we will create the components for the Prometheus operator

```
kubectl --namespace="$NAMESPACE" apply -f manifests/prometheus-operator
```

This will create all the Prometheus Operator components. You might need to wait a short amount of time before the Custom Resource Definitions are available in the cluster. You can wait for them:

```
until kubectl --namespace="$NAMESPACE" get alertmanagers.monitoring.coreos.com > /dev/null 2>&1; do sleep 1; printf "."; done
```

Next, we will install the node exporter and then kube-state-metrics:

```
kubectl --namespace="$NAMESPACE" apply -f manifests/node-exporter
kubectl --namespace="$NAMESPACE" apply -f manifests/kube-state-metrics
```

Then, we can deploy the grafana credentials. By default, the username/password will be `admin/admin`, you should change these for your production clusters.

```
kubectl --namespace="$NAMESPACE" apply -f manifests/grafana/grafana-credentials.yaml
```

Then install grafana itself:

```
kubectl --namespace="$NAMESPACE" apply -f manifests/grafana
```

Next up is the `Prometheus` object itself. We will deploy the application, and then the roles/role-bindings.

```
find manifests/prometheus -type f ! -name prometheus-k8s-roles.yaml ! -name prometheus-k8s-role-bindings.yaml -exec kubectl --namespace "$NAMESPACE" apply -f {} \;
kubectl apply -f manifests/prometheus/prometheus-k8s-roles.yaml
kubectl apply -f manifests/prometheus/prometheus-k8s-role-bindings.yaml
```

Finally, install the [Alertmanager](https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/alerting.md)

```
kubectl --namespace="$NAMESPACE" apply -f manifests/alertmanager
```

Now you should have a working cluster. After all the pods are ready, you should be able to reach:

* Prometheus UI on node port `30900`
* Alertmanager UI on node port `30903`
* Grafana on node port `30902`

These can of course be changed via the Service definitions. It is recommended to look at the [Exposing Prometheus and Alert Manager](https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/exposing-prometheus-and-alertmanager.md) documentation for more detailed information on how to expose these services.
