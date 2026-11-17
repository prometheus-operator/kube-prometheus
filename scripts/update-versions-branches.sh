#!/usr/bin/env bash
# Update the branch matrix in .github/workflows/versions.yaml after a release.
# Adds the new release branch and removes the oldest one, keeping only the
# last two release branches plus main.
#
# Usage: bash scripts/update-versions-branches.sh release-0.19
set -euo pipefail

NEW_BRANCH="${1:-}"
WORKFLOW=".github/workflows/versions.yaml"

if [[ -z "${NEW_BRANCH}" ]]; then
  echo "usage: $0 <new-release-branch>" >&2
  echo "example: $0 release-0.19" >&2
  exit 1
fi

if [[ ! "${NEW_BRANCH}" =~ ^release-[0-9]+\.[0-9]+$ ]]; then
  echo "error: branch '${NEW_BRANCH}' does not match pattern release-X.Y" >&2
  exit 1
fi

if [[ ! -f "${WORKFLOW}" ]]; then
  echo "error: ${WORKFLOW} not found" >&2
  exit 1
fi

if ! command -v yq &> /dev/null; then
  echo "error: yq is required but not installed" >&2
  exit 1
fi

# Read release branches from the YAML matrix array (excludes "main").
mapfile -t current_branches < <(
  yq '.jobs.versions.strategy.matrix.branch[]' "${WORKFLOW}" \
    | grep -E '^release-' \
    | sort -t. -k1,1 -k2,2n
)

if [[ ${#current_branches[@]} -lt 2 ]]; then
  echo "error: expected at least 2 release branches in matrix, found ${#current_branches[@]}" >&2
  exit 1
fi

oldest="${current_branches[0]}"

# Check if the new branch is already present.
for b in "${current_branches[@]}"; do
  if [[ "${b}" == "${NEW_BRANCH}" ]]; then
    echo "error: ${NEW_BRANCH} already exists in the matrix" >&2
    exit 1
  fi
done

echo "remove: ${oldest}"
echo "add:    ${NEW_BRANCH}"

# Use sed for editing to preserve comments and quoting style.
# Remove the oldest branch line.
sed -i.bak "/${oldest}/d" "${WORKFLOW}"
# Add the new branch before "main".
sed -i.bak "s|          - \"main\"|          - \"${NEW_BRANCH}\"\n          - \"main\"|" "${WORKFLOW}"
rm -f "${WORKFLOW}.bak"

echo "Updated ${WORKFLOW}:"
yq '.jobs.versions.strategy.matrix.branch' "${WORKFLOW}"
