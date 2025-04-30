#!/usr/bin/env bash
#------------------------------------------------------------------------------
# dump-tags.sh – Preview all tags yielded by the current build matrix.
#
# Iterates every Node × Saltcorn permutation in `.ci/build-matrix.yml`,
# invokes `calc-tags.sh`, and prints a readable list.
#
# Usage
#   ./scripts/dump-tags.sh            # default matrix file
#   ./scripts/dump-tags.sh path.yml   # custom matrix file
#
# ──────────────────────────────────────────────────────────────────────────────
# Author:  Troy Kelly <troy@team.production.city>
# History:
#   2025-04-30 • Initial version
#   2025-04-30 • Tolerate updated calc-tags.sh output
#------------------------------------------------------------------------------

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="${SCRIPT_DIR}/.."
readonly MATRIX_FILE="${1:-${REPO_ROOT}/.ci/build-matrix.yml}"
readonly CALC_SCRIPT="${SCRIPT_DIR}/calc-tags.sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "❌  yq is required but not installed." >&2
  exit 1
fi
[[ -f "$MATRIX_FILE" ]] || { echo "❌  Matrix file not found: $MATRIX_FILE" >&2; exit 1; }

mapfile -t NODE_VERSIONS < <(yq '.node.versions[]'     < "$MATRIX_FILE")
mapfile -t SC_VERSIONS   < <(yq '.saltcorn.versions[]' < "$MATRIX_FILE")

DEFAULT_NODE="$(yq '.node.default'     < "$MATRIX_FILE")"
DEFAULT_SC="$(yq '.saltcorn.default'   < "$MATRIX_FILE")"
EDGE_SC="$(yq '.saltcorn.edge'         < "$MATRIX_FILE")"

for node in "${NODE_VERSIONS[@]}"; do
  for sc in "${SC_VERSIONS[@]}"; do
    echo "Node: ${node}, Saltcorn: ${sc}"
    "${CALC_SCRIPT}" "${node}" "${sc}" "${DEFAULT_NODE}" "${DEFAULT_SC}" "${EDGE_SC}" \
      | sed 's/^/  • /'
    echo
  done
done