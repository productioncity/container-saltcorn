#!/usr/bin/env bash
#------------------------------------------------------------------------------
# calc-tags.sh – Derive all OCI tags for a Saltcorn × Node permutation.
#
# This version:
#   • ALWAYS emits a full semver tag (no Node suffix) whenever the build is
#     based on the *default* Node image.
#   • GUARANTEES that the canonical `latest` tag is produced when – and only
#     when – the build matches BOTH the default Saltcorn *and* default Node.
#
# Usage:
#   ./scripts/calc-tags.sh <NODE_TAG> <SC_VERSION> <DEFAULT_NODE> \
#                          <DEFAULT_SC> <EDGE_SC>
#
# Prints one tag per line on STDOUT.  Order is deterministic but duplicates
# (should they arise) are removed automatically.
#
# ──────────────────────────────────────────────────────────────────────────────
# Author:  Troy Kelly <troy@team.production.city>
# History:
#   2025-04-30 • Initial scaffold
#   2025-04-30 • Fix missing `latest` tag + always emit semver tag on default
#------------------------------------------------------------------------------

set -euo pipefail

#------------------------------------------------------------------------------
# 1. Input validation
#------------------------------------------------------------------------------
if [[ "$#" -ne 5 ]]; then
  echo "Usage: $(basename "$0") <NODE_TAG> <SC_VERSION> <DEFAULT_NODE> <DEFAULT_SC> <EDGE_SC>" >&2
  echo "Example: $(basename "$0") 23-slim 1.1.4 23-slim 1.1.4 1.2.0-beta.0" >&2
  exit 1
fi

readonly NODE_TAG="${1}"
readonly SC_VERSION="${2}"
readonly DEFAULT_NODE="${3}"
readonly DEFAULT_SC="${4}"
readonly EDGE_SC="${5}"

readonly REGISTRY="${REGISTRY:-ghcr.io}"
readonly IMAGE_NAME="${IMAGE_NAME:-${GITHUB_REPOSITORY_OWNER:-local}/saltcorn}"

#------------------------------------------------------------------------------
# 2. Helper – append to the global TAGS array only if the value is new.
#------------------------------------------------------------------------------
declare -a TAGS
append_unique() {
  local tag="$1"
  for existing in "${TAGS[@]:-}"; do
    [[ "${existing}" == "${tag}" ]] && return
  done
  TAGS+=("${tag}")
}

#------------------------------------------------------------------------------
# 3. Base tag – always include the fully-qualified Node/Saltcorn tag.
#------------------------------------------------------------------------------
append_unique "${REGISTRY}/${IMAGE_NAME}:${SC_VERSION}-${NODE_TAG}"

#------------------------------------------------------------------------------
# 4. Default-Node specific tags (no Node suffix)
#------------------------------------------------------------------------------
if [[ "${NODE_TAG}" == "${DEFAULT_NODE}" ]]; then
  # 4a. Full semver (e.g. 1.0.0).  This was missing for non-default SC versions.
  append_unique "${REGISTRY}/${IMAGE_NAME}:${SC_VERSION}"

  # 4b. Major.minor and Major aliases for *true* semver releases.
  if [[ "${SC_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    append_unique "${REGISTRY}/${IMAGE_NAME}:${major}.${minor}"
    append_unique "${REGISTRY}/${IMAGE_NAME}:${major}"
  fi

  # 4c. latest / edge aliases.
  [[ "${SC_VERSION}" == "${DEFAULT_SC}" ]] && \
    append_unique "${REGISTRY}/${IMAGE_NAME}:latest"

  [[ "${SC_VERSION}" == "${EDGE_SC}" ]] && \
    append_unique "${REGISTRY}/${IMAGE_NAME}:edge"
fi

#------------------------------------------------------------------------------
# 5. Emit results – one tag per line.
#------------------------------------------------------------------------------
printf '%s\n' "${TAGS[@]}"