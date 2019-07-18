#!/usr/bin/env bash
# exit immediately when a command fails
set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail
# error on unset variables
set -u
# print each command before executing it
set -x

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v0.4.0/kind-linux-amd64
chmod +x kind

./kind create cluster
export KUBECONFIG="$(./kind get kubeconfig-path)"

./kubectl apply -f manifests/0prometheus-operator-0alertmanagerCustomResourceDefinition.yaml
./kubectl apply -f manifests/0prometheus-operator-0prometheusCustomResourceDefinition.yaml
./kubectl apply -f manifests/0prometheus-operator-0prometheusruleCustomResourceDefinition.yaml
./kubectl apply -f manifests/0prometheus-operator-0servicemonitorCustomResourceDefinition.yaml

# Wait for CRDs to be successfully registered
sleep 10

./kubectl apply -f manifests
make test-e2e
