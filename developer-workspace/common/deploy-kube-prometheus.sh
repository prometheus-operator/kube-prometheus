#!/bin/bash

kubectl apply --server-side -f manifests/setup

# Safety wait for CRDs to be working
sleep 30

kubectl apply -f manifests/
sleep 30
# Safety wait for resources to be created

kubectl rollout status -n monitoring daemonset node-exporter
kubectl rollout status -n monitoring statefulset alertmanager-main
kubectl rollout status -n monitoring statefulset prometheus-k8s
kubectl rollout status -n monitoring deployment grafana
kubectl rollout status -n monitoring deployment kube-state-metrics

kubectl port-forward -n monitoring svc/grafana 3000 > /dev/null 2>&1 &
kubectl port-forward -n monitoring svc/alertmanager-main 9093 > /dev/null 2>&1 &
kubectl port-forward -n monitoring svc/prometheus-k8s 9090 > /dev/null 2>&1 &
