#!/bin/bash

# create namespace and CRDs
kubectl create -f manifests/setup

# wait for CRD creation to complete
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done

# create monitoring components
kubectl create -f manifests/

