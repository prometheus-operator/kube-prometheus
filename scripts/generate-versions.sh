#!/bin/bash

set -euo pipefail

# Get component version from GitHub API
get_latest_version() {
  echo >&2 "Checking release version for ${1}"
  curl --retry 5 --silent --fail -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/${1}/releases/latest" | jq '.tag_name' | tr -d '"v'
}

# Get component version from version file
get_current_version() {
  echo >&2 "Reading currently used version of ${1}"
  v=$(jq -r ".${1}" "$VERSION_FILE")
  if [ "${v}" == "" ]; then
    echo >&2 "Couldn't read version of ${1} from $VERSION_FILE"
    exit 1
  fi
  echo "$v"
}

# Get version from online source and filter out unstable releases. In case of unstable release use what is set in version file
get_version() {
  component="${1}"
  v="$(get_latest_version "${component}")"

  component="$(convert_to_camel_case "$(echo "${component}" | sed 's/^.*\///')")"
  cv="$(get_current_version "${component}")"

  # Advanced AI heurestics to filter out common patterns suggesting new version is not stable /s
  if [[ "$v" == "" ]] || [[ "$v" == *"alpha"* ]] || [[ "$v" == *"beta"* ]] || [[ "$v" == *"rc"* ]] || [[ "$v" == *"helm"* ]]; then
     echo "$cv"
     return
  fi

  # Use higher version from new version and current version
  v=$(printf '%s\n' "$v" "$cv" | sort -r | head -n1)
  
  echo "$v"
}

convert_to_camel_case() {
  echo "${1}" | sed -E 's/[ _-]([a-z])/\U\1/gi;s/^([A-Z])/\l\1/'
}

# File is used to read current versions
VERSION_FILE="$(pwd)/jsonnet/kube-prometheus/versions.json"

# token can be passed as `GITHUB_TOKEN` variable or passed as first argument
GITHUB_TOKEN=${GITHUB_TOKEN:-${1}}

if [ -z "$GITHUB_TOKEN" ]; then
	echo >&2 "GITHUB_TOKEN not set. Exiting"
	exit 1
fi

cat <<-EOF
{
  "alertmanager": "$(get_version "prometheus/alertmanager")",
  "blackboxExporter": "$(get_version "prometheus/blackbox_exporter")",
  "grafana": "$(get_version "grafana/grafana")",
  "kubeStateMetrics": "$(get_version "kubernetes/kube-state-metrics")",
  "nodeExporter": "$(get_version "prometheus/node_exporter")",
  "prometheus": "$(get_version "prometheus/prometheus")",
  "prometheusAdapter": "$(get_version "kubernetes-sigs/prometheus-adapter")",
  "prometheusOperator": "$(get_version "prometheus-operator/prometheus-operator")",
  "kubeRbacProxy": "$(get_version "brancz/kube-rbac-proxy")",
  "configmapReload": "$(get_version "jimmidyson/configmap-reload")",
  "pyrra": "$(get_version "pyrra-dev/pyrra")"
}
EOF
