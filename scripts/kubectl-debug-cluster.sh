#!/usr/bin/env bash
# Print cluster state for debugging bootstrap or e2e failures.
#
# Usage:
#   ./scripts/kubectl-debug-cluster.sh           # monitoring namespace
#   ./scripts/kubectl-debug-cluster.sh monitoring
#   ./scripts/kubectl-debug-cluster.sh all       # all namespaces
set -uo pipefail

scope="${1:-monitoring}"

dump_not_ready() {
  local ns="$1"
  local name="$2"
  echo "=== describe pod/${ns}/${name} ==="
  kubectl describe pod -n "${ns}" "${name}" || true
  echo "=== logs pod/${ns}/${name} ==="
  kubectl logs -n "${ns}" "${name}" --all-containers --tail=100 || true
}

inspect_pod() {
  local ns="$1"
  local name="$2"
  local ready="$3"
  local status="$4"

  [[ "${status}" == "Completed" || "${status}" == "Succeeded" ]] && return
  [[ "${ready%%/*}" == "${ready##*/}" ]] && return
  dump_not_ready "${ns}" "${name}"
}

if [[ "${scope}" == "all" ]]; then
  kubectl get pods -A -o wide
  kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50
  kubectl get pods -A --no-headers | while read -r ns name ready status _; do
    inspect_pod "${ns}" "${name}" "${ready}" "${status}"
  done
else
  kubectl get pods -n "${scope}" -o wide
  kubectl get events -n "${scope}" --sort-by='.lastTimestamp' | tail -n 50
  kubectl get pods -n "${scope}" --no-headers | while read -r name ready status _; do
    inspect_pod "${scope}" "${name}" "${ready}" "${status}"
  done
fi
