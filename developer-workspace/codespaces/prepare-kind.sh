#!/bin/bash

which kind
if [[ $? != 0 ]]; then
    echo 'kind not available in $PATH, installing latest kind'
    # Install latest kind
    curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest \
    | grep "browser_download_url.*kind-linux-amd64" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | wget -qi -
    mv kind-linux-amd64 developer-workspace/codespaces/kind && chmod +x developer-workspace/codespaces/kind
    export PATH=$PATH:$PWD/developer-workspace/codespaces
fi

cluster_created=$($PWD/developer-workspace/codespaces/kind get clusters 2>&1)
if [[ "$cluster_created" == "No kind clusters found." ]]; then 
    $PWD/developer-workspace/codespaces/kind create cluster --config $PWD/.github/workflows/kind/config.yml
else
    echo "Cluster '$cluster_created' already present" 
fi

helm repo add --force-update cilium https://helm.cilium.io/ 
helm install cilium cilium/cilium --version 1.9.13 \
  --namespace kube-system \
  --set nodeinit.enabled=true \
  --set kubeProxyReplacement=partial \
  --set hostServices.enabled=false \
  --set externalIPs.enabled=true \
  --set nodePort.enabled=true \
  --set hostPort.enabled=true \
  --set bpf.masquerade=false \
  --set image.pullPolicy=IfNotPresent \
  --set ipam.mode=kubernetes \
  --set operator.replicas=1