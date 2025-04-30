#!/usr/bin/env bash
#------------------------------------------------------------------------------
# calc-tags.sh – Determine every tag that *this* Saltcorn/Node permutation
#                should publish.
#
# Usage:
#   ./scripts/calc-tags.sh <NODE_TAG> <SC_VERSION> <DEFAULT_NODE> \
#                          <DEFAULT_SC> <EDGE_SC>
#
# Prints a newline-separated list to STDOUT.
#------------------------------------------------------------------------------

set -euo pipefail

#───────────────────────────────────────────────────────────────────────────────
# Parameter validation – bail out early if anything is missing.
#───────────────────────────────────────────────────────────────────────────────
if [[ "$#" -ne 5 ]]; then
  echo "Usage: $(basename "$0") <NODE_TAG> <SC_VERSION> <DEFAULT_NODE> <DEFAULT_SC> <EDGE_SC>" >&2
  echo "Example: $(basename "$0") 23-slim 1.1.4 23-slim 1.1.4 1.2.0-beta.0" >&2
  exit 1
fi

NODE_TAG="${1}"
SC_VERSION="${2}"
DEFAULT_NODE="${3}"
DEFAULT_SC="${4}"
EDGE_SC="${5}"

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-${GITHUB_REPOSITORY_OWNER:-local}/saltcorn}"

#───────────────────────────────────────────────────────────────────────────────
# Tag derivation logic (unchanged).
#───────────────────────────────────────────────────────────────────────────────
declare -a TAGS
TAGS+=("${REGISTRY}/${IMAGE_NAME}:${SC_VERSION}-${NODE_TAG}")

if [[ "${NODE_TAG}" == "${DEFAULT_NODE}" ]]; then
  TAGS+=("${REGISTRY}/${IMAGE_NAME}:${SC_VERSION}")

  if [[ "${SC_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    TAGS+=("${REGISTRY}/${IMAGE_NAME}:${major}.${minor}")
    TAGS+=("${REGISTRY}/${IMAGE_NAME}:${major}")
  fi

  [[ "${SC_VERSION}" == "${DEFAULT_SC}" ]] && \
    TAGS+=("${REGISTRY}/${IMAGE_NAME}:latest")

  [[ "${SC_VERSION}" == "${EDGE_SC}" ]] && \
    TAGS+=("${REGISTRY}/${IMAGE_NAME}:edge")
fi

printf '%s\n' "${TAGS[@]}"