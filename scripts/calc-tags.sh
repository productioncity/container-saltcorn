#!/usr/bin/env bash
#------------------------------------------------------------------------------
# calc-tags.sh – Derive every OCI tag for a Saltcorn × Node permutation.
#
# Rules
# ──────────────────────────────────────────────────────────────────────────────
# 1. Always emit the fully-qualified       :<SC>-<NODE>        tag.
# 2. If NODE = DEFAULT_NODE:
#      • Always emit the full semver       :<SC>               tag.
#      • If SC   = DEFAULT_SC   → add      :<MAJOR.MINOR> and :<MAJOR>,
#        plus                                    :latest
#      • If SC   = EDGE_SC      → add      :edge
#
# Usage
#   ./scripts/calc-tags.sh <NODE_TAG> <SC_VERSION> <DEFAULT_NODE> \
#                          <DEFAULT_SC> <EDGE_SC>
#
# Prints one tag per line (duplicates are silently removed).
#
# ──────────────────────────────────────────────────────────────────────────────
# Author:  Troy Kelly <troy@team.production.city>
# History:
#   2025-04-30 • Initial scaffold
#   2025-04-30 • Fix missing semver/alias tags, remove ‘local’-outside-func bug
#------------------------------------------------------------------------------

set -euo pipefail

if [[ "$#" -ne 5 ]]; then
  echo "Usage: $(basename "$0") <NODE_TAG> <SC_VERSION> <DEFAULT_NODE> <DEFAULT_SC> <EDGE_SC>" >&2
  exit 1
fi

readonly NODE_TAG="$1"
readonly SC_VERSION="$2"
readonly DEFAULT_NODE="$3"
readonly DEFAULT_SC="$4"
readonly EDGE_SC="$5"

readonly REGISTRY="${REGISTRY:-ghcr.io}"
readonly IMAGE_NAME="${IMAGE_NAME:-${GITHUB_REPOSITORY_OWNER:-local}/saltcorn}"

#------------------------------------------------------------------------------
# Helper: append_unique <tag>
#------------------------------------------------------------------------------
declare -a TAGS
append_unique() {
  local candidate="$1"
  for existing in "${TAGS[@]:-}"; do
    [[ "$existing" == "$candidate" ]] && return
  done
  TAGS+=("$candidate")
}

#------------------------------------------------------------------------------
# 1. Always present – fully-qualified Node/Saltcorn tag
#------------------------------------------------------------------------------
append_unique "${REGISTRY}/${IMAGE_NAME}:${SC_VERSION}-${NODE_TAG}"

#------------------------------------------------------------------------------
# 2. Extras when using the default Node image
#------------------------------------------------------------------------------
if [[ "$NODE_TAG" == "$DEFAULT_NODE" ]]; then
  # 2a. Full semver alias (e.g. 1.0.0)
  append_unique "${REGISTRY}/${IMAGE_NAME}:${SC_VERSION}"

  # 2b. Extra aliases ONLY for the repository-wide default Saltcorn release
  if [[ "$SC_VERSION" == "$DEFAULT_SC" ]]; then
    if [[ "$SC_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      major="${BASH_REMATCH[1]}"
      minor="${BASH_REMATCH[2]}"
      append_unique "${REGISTRY}/${IMAGE_NAME}:${major}.${minor}"
      append_unique "${REGISTRY}/${IMAGE_NAME}:${major}"
    fi
    append_unique "${REGISTRY}/${IMAGE_NAME}:latest"
  fi

  # 2c. Edge alias
  if [[ "$SC_VERSION" == "$EDGE_SC" ]]; then
    append_unique "${REGISTRY}/${IMAGE_NAME}:edge"
  fi
fi

#------------------------------------------------------------------------------
# 3. Emit
#------------------------------------------------------------------------------
printf '%s\n' "${TAGS[@]}"