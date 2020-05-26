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
curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v0.6.1/kind-linux-amd64
chmod +x kind

run_e2e_tests() {
    cluster_version=$1

    ./kind create cluster --image=kindest/node:$cluster_version
    export KUBECONFIG="$(./kind get kubeconfig-path)"

    # create namespace, permissions, and CRDs
    ./kubectl create -f manifests/setup

    # wait for CRD creation to complete
    until ./kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done

    # create monitoring components
    ./kubectl create -f manifests/

    make test-e2e
    ./kind delete cluster
}
cluster_compatible_versions=("v1.18.0")

for cluster_version in "${cluster_compatible_versions[@]}"
do
    run_e2e_tests $cluster_version
done
