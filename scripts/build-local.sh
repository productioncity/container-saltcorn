#!/usr/bin/env bash
#------------------------------------------------------------------------------
# build-local.sh – Local build helper for Saltcorn container images
#
# The script mimics (in a simplified form) the logic that the GitHub Actions
# pipeline uses to enumerate build permutations from the central
# `.ci/build-matrix.yml` definition.  It is intended for local testing only
# and deliberately avoids pushing images to any registry.
#
# Usage:
#   ./scripts/build-local.sh
#
# Prerequisites:
#   - bash ≥ 4
#   - yq   – https://github.com/mikefarah/yq
#   - docker or podman (alias `docker`)
#
# ──────────────────────────────────────────────────────────────────────────────
# Author:  Troy Kelly <troy@team.production.city>
# History: 2025-04-30 • Initial scaffold
#------------------------------------------------------------------------------

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="${SCRIPT_DIR}/.."

readonly CONFIG_FILE="${ROOT_DIR}/.ci/build-matrix.yml"

if ! command -v yq >/dev/null 2>&1; then
  echo "❌ 'yq' is required but not installed. Aborting." >&2
  exit 1
fi

# Read build matrix into bash arrays
mapfile -t NODE_VERSIONS < <(yq '.node.versions[]' < "${CONFIG_FILE}")
mapfile -t SALTCORN_VERSIONS < <(yq '.saltcorn.versions[]' < "${CONFIG_FILE}")

echo "🔍 Building Saltcorn images locally using:"
echo "    Node base images     : ${NODE_VERSIONS[*]}"
echo "    Saltcorn application : ${SALTCORN_VERSIONS[*]}"
echo

for node_tag in "${NODE_VERSIONS[@]}"; do
  for sc_version in "${SALTCORN_VERSIONS[@]}"; do
    echo "👉 Would build image for Node '${node_tag}' / Saltcorn '${sc_version}' (scaffold)"
    # TODO(implementation): docker build logic will be added here in a later session.
  done
done

echo
echo "✅ Scaffold run complete – no images have been built."