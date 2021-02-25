#!/bin/bash

set -euo pipefail

get_latest_version() {
  echo >&2 "Checking release version for ${1}"
  curl --retry 5 --silent --fail -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/${1}/releases/latest" | jq '.tag_name' | tr -d '"v'
}

# token can be passed as `GITHUB_TOKEN` variable or passed as first argument
GITHUB_TOKEN=${GITHUB_TOKEN:-${1}}

if [ -z "$GITHUB_TOKEN" ]; then
	echo >&2 "GITHUB_TOKEN not set. Exiting"
	exit 1
fi

cat <<-EOF
{
  "alertmanager": "$(get_latest_version "prometheus/alertmanager")",
  "blackboxExporter": "$(get_latest_version "prometheus/blackbox_exporter")",
  "grafana": "$(get_latest_version "grafana/grafana")",
  "nodeExporter": "$(get_latest_version "prometheus/node_exporter")",
  "prometheus": "$(get_latest_version "prometheus/prometheus")",
  "prometheusAdapter": "$(get_latest_version "kubernetes-sigs/prometheus-adapter")",
  "prometheusOperator": "$(get_latest_version "prometheus-operator/prometheus-operator")"
}
EOF
