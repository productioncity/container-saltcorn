#!/usr/bin/env bash
#------------------------------------------------------------------------------
# dump-tags.sh – Human-friendly preview of ALL OCI tags the build matrix yields.
#
# The script iterates over every Node × Saltcorn permutation defined in
# `.ci/build-matrix.yml`, invokes `scripts/calc-tags.sh`, and prints the
# results in an indented list.
#
# Example output:
#
#   Node: 23-slim, Saltcorn: 1.1.4
#     • ghcr.io/productioncity/saltcorn:1.1.4-23-slim
#     • ghcr.io/productioncity/saltcorn:1.1.4
#     • ghcr.io/productioncity/saltcorn:1.1
#     • ghcr.io/productioncity/saltcorn:1
#     • ghcr.io/productioncity/saltcorn:latest
#
# Usage:
#   ./scripts/dump-tags.sh            # Uses default build-matrix location
#   ./scripts/dump-tags.sh <file.yml> # Custom matrix file
#
# Requirements:
#   - bash ≥ 4
#   - yq   – https://github.com/mikefarah/yq
#
# ──────────────────────────────────────────────────────────────────────────────
# Author:  Troy Kelly <troy@team.production.city>
# History:
#   2025-04-30 • Initial version
#------------------------------------------------------------------------------

set -euo pipefail

#------------------------------------------------------------------------------
# 1. Resolve paths & validate prerequisites
#------------------------------------------------------------------------------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="${SCRIPT_DIR}/.."
readonly MATRIX_FILE="${1:-${REPO_ROOT}/.ci/build-matrix.yml}"
readonly CALC_SCRIPT="${SCRIPT_DIR}/calc-tags.sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "❌  yq is required but not installed. Aborting." >&2
  exit 1
fi

if [[ ! -f "${MATRIX_FILE}" ]]; then
  echo "❌  Matrix file not found: ${MATRIX_FILE}" >&2
  exit 1
fi

#------------------------------------------------------------------------------
# 2. Load matrix data
#------------------------------------------------------------------------------
mapfile -t NODE_VERSIONS < <(yq '.node.versions[]'     < "${MATRIX_FILE}")
mapfile -t SC_VERSIONS   < <(yq '.saltcorn.versions[]' < "${MATRIX_FILE}")

readonly DEFAULT_NODE="$(yq '.node.default'     < "${MATRIX_FILE}")"
readonly DEFAULT_SC="$(yq '.saltcorn.default'   < "${MATRIX_FILE}")"
readonly EDGE_SC="$(yq '.saltcorn.edge'         < "${MATRIX_FILE}")"

#------------------------------------------------------------------------------
# 3. Iterate permutations & display tags
#------------------------------------------------------------------------------
for node in "${NODE_VERSIONS[@]}"; do
  for sc in "${SC_VERSIONS[@]}"; do
    echo "Node: ${node}, Saltcorn: ${sc}"
    while IFS= read -r tag; do
      echo "  • ${tag}"
    done < <("${CALC_SCRIPT}" "${node}" "${sc}" "${DEFAULT_NODE}" "${DEFAULT_SC}" "${EDGE_SC}")
    echo
  done
done