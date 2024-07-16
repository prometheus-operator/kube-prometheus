---
weight: 300
toc: true
title: Access Dashboards
menu:
    docs:
        parent: kube
images: []
draft: false
---

Prometheus, Grafana, and Alertmanager dashboards can be accessed quickly using `kubectl port-forward` after running the quickstart via the commands below.

> Kubernetes 1.10 or later is required.

You can also learn how to [expose Prometheus/Alertmanager/Grafana via Ingress ->]({{<ref "kube-prometheus/kube/exposing-prometheus-alertmanager-grafana-ingress">}})

## Prometheus

```shell
$ kubectl --namespace monitoring port-forward svc/prometheus-k8s 9090
```

Open Prometheus on [http://localhost:9090](http://localhost:9090) in your browser.

Check out the [alerts](http://localhost:9090/alerts) and [rules](http://localhost:9090/rules) pages with the pre-configured rules and alerts!
This Prometheus is supposed to monitor your Kubernetes cluster and make sure to alert you if there’s a problem with it.

For your own applications we recommend running one or more other instances.

## Grafana

```shell
$ kubectl --namespace monitoring port-forward svc/grafana 3000
```

Open Grafana on [localhost:3000](https://localhost:3000) in your browser.
You can login with the username `admin` and password `admin`.

## Alertmanager

```shell
$ kubectl --namespace monitoring port-forward svc/alertmanager-main 9093
```

Open Alertmanager on [localhost:9093](http://localhost:9093) in your browser.
