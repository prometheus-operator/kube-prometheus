#!/usr/bin/env bash
# Reset jsonnetfile.json dependency versions to their default floating branches
# so main stays in sync with upstream mixin changes after a release.
set -euo pipefail

JSONNETFILE="${1:-jsonnet/kube-prometheus/jsonnetfile.json}"

if [[ ! -f "${JSONNETFILE}" ]]; then
  echo "error: ${JSONNETFILE} not found" >&2
  exit 1
fi

# Default branch per dependency remote (host/path without scheme or .git).
# Keep this map in sync when adding new jsonnet dependencies.
BRANCH_MAP="$(cat <<'EOF'
{
  "github.com/brancz/kubernetes-grafana": "master",
  "github.com/grafana/grafana": "main",
  "github.com/etcd-io/etcd": "main",
  "github.com/prometheus-operator/prometheus-operator": "main",
  "github.com/kubernetes-monitoring/kubernetes-mixin": "master",
  "github.com/kubernetes/kube-state-metrics": "main",
  "github.com/prometheus/node_exporter": "master",
  "github.com/prometheus/prometheus": "main",
  "github.com/prometheus/alertmanager": "main",
  "github.com/pyrra-dev/pyrra": "main",
  "github.com/perses/perses-operator": "main",
  "github.com/perses/community-mixins": "main",
  "github.com/thanos-io/thanos": "main"
}
EOF
)"

normalize_remote() {
  local remote="$1"
  remote="${remote#https://}"
  remote="${remote#http://}"
  remote="${remote#git@}"
  remote="${remote%.git}"
  remote="${remote%/}"
  echo "${remote}"
}

# Fail early if any dependency is missing from the map.
while IFS= read -r remote; do
  key="$(normalize_remote "${remote}")"
  branch="$(echo "${BRANCH_MAP}" | jq -r --arg k "${key}" '.[$k] // empty')"
  current="$(jq -r --arg r "${remote}" '.dependencies[] | select(.source.git.remote == $r) | .version' "${JSONNETFILE}" | head -n1)"
  if [[ -z "${branch}" ]]; then
    echo "error: no default branch mapped for ${remote}" >&2
    echo "Add an entry to BRANCH_MAP in scripts/unpin-jsonnet-deps.sh" >&2
    exit 1
  fi
  if [[ "${current}" != "${branch}" ]]; then
    echo "unpin ${key}: ${current} -> ${branch}"
  else
    echo "keep  ${key}: ${branch}"
  fi
done < <(jq -r '.dependencies[].source.git.remote' "${JSONNETFILE}")

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

jq --argjson map "${BRANCH_MAP}" '
  .dependencies |= map(
    (.source.git.remote
      | sub("^https?://"; "")
      | sub("^git@"; "")
      | sub("\\.git$"; "")
      | sub("/$"; "")
    ) as $key
    | if $map[$key] == null then
        error("no default branch mapped for " + .source.git.remote)
      else
        .version = $map[$key]
      end
  )
' "${JSONNETFILE}" > "${tmp}"

mv "${tmp}" "${JSONNETFILE}"
trap - EXIT

echo "Updated ${JSONNETFILE}"
