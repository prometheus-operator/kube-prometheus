#!/bin/bash

set -euo pipefail

# Get the freshly updated components versions.
# Should be only used after running ./scripts/generate-versions and before
# committing any changes.
get_updated_versions() {
  # Get only the newly updated versions from the versions file.
  echo "$(git diff -U0 -- "${VERSION_FILE}" | grep '^[+]' | grep -Ev '^(--- a/|\+\+\+ b/)' | tr -d '",:+' | awk -F'"' '{print $1}')"
}

# Returns github changelog url based on a given repository url and tag.
get_changelog_url() {
  echo "https://github.com/${1}/releases/tag/v${2}"
}

# Gets all the new changelogs from the updated components version.
get_changelog_urls() {
  while IFS= read -r updated_version; do
    read -r component version <<< "${updated_version}"
    case "${component}" in
      alertmanager)
        get_changelog_url "prometheus/alertmanager" "${version}"
        ;;
      blackboxExporter)
        get_changelog_url "prometheus/blackbox_exporter" "${version}"
        ;;
      grafana)
        get_changelog_url "grafana/grafana" "${version}"
        ;;
      kubeStateMetrics)
        get_changelog_url "kubernetes/kube-state-metrics" "${version}"
        ;;
      nodeExporter)
        get_changelog_url "prometheus/node_exporter" "${version}"
        ;;
      prometheus)
        get_changelog_url "prometheus/prometheus" "${version}"
        ;;
      prometheusAdapter)
        get_changelog_url "kubernetes-sigs/prometheus-adapter" "${version}"
        ;;
      prometheusOperator)
        get_changelog_url "prometheus-operator/prometheus-operator" "${version}"
        ;;
      kubeRbacProxy)
        get_changelog_url "brancz/kube-rbac-proxy" "${version}"
        ;;
      configmapReload)
        get_changelog_url "jimmidyson/configmap-reload" "${version}"
        ;;
      *)
        echo "Unknown component ${component} updated"
        exit 1
        ;;
    esac
  done <<< "$(get_updated_versions)"
}

# File is used to read current versions
VERSION_FILE="$(pwd)/jsonnet/kube-prometheus/versions.json"

get_changelog_urls
