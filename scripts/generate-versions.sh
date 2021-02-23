#!/bin/bash

get_latest_version() {
  curl --retry 5 --silent -H "Authorization: token $token" "https://api.github.com/repos/${1}/releases/latest" | jq '.tag_name' | tr -d '"v'
}

# token can be passed as `GITHUB_TOKEN` or `token` variable
token=${token:-${GITHUB_TOKEN}}

if [ -z "$token" ]; then
	echo "GITHUB_TOKEN not set. Exiting"
	exit 1
fi

cat <<-EOF
{
  "alertmanager": "$(get_latest_version "prometheus/alertmanager")"
  "blackboxExporter": "$(get_latest_version "prometheus/blackbox_exporter")",
  "grafana": "$(get_latest_version "grafana/grafana")",
  "nodeExporter": "$(get_latest_version "prometheus/node_exporter")",
  "prometheus": "$(get_latest_version "prometheus/prometheus")",
  "prometheusAdapter": "$(get_latest_version "kubernetes-sigs/prometheus-adapter")",
  "prometheusOperator": "$(get_latest_version "prometheus-operator/prometheus-operator")"
}
EOF
