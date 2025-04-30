#!/usr/bin/env bash
#------------------------------------------------------------------------------
# test-workflow-local.sh – Exercise the entire GitHub Actions workflow
#                           locally with “act”, *without* publishing.
#
# The script fires the workflow as if it were triggered by a pull-request
# event.  Because the workflow’s build job only pushes when
#   github.event_name != 'pull_request'
# no layers will ever be published to GHCR.
#
# Usage:
#   ./scripts/test-workflow-local.sh            # run all jobs
#   ./scripts/test-workflow-local.sh -j build   # run only the "build" job
#
# Requirements:
#   • nektos/act (either at ./bin/act or on $PATH)
#   • Docker with Buildx enabled (present inside the dev-container)
#
# ──────────────────────────────────────────────────────────────────────────────
# Author:  Troy Kelly <troy@team.production.city>
# History:
#   2025-04-30 • Initial version (LLM-generated)
#------------------------------------------------------------------------------

set -euo pipefail

#----------------------------------------------------------------------------
# 1. Constants & read-only configuration
#----------------------------------------------------------------------------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="${SCRIPT_DIR}/.."
readonly DEFAULT_RUNNER_IMAGE="catthehacker/ubuntu:act-latest"
readonly DEFAULT_EVENT="pull_request"
readonly DUMMY_TOKEN="llm_dummy_token"

#----------------------------------------------------------------------------
# 2. Helper: print usage information
#----------------------------------------------------------------------------
usage() {
  cat <<EOF
Saltcorn – Local Workflow Tester
================================
Runs the full GitHub Actions workflow locally with "act" but in PR mode so
no images are ever pushed to GHCR.

Options:
  -j <job>   Only run the specified job (e.g. "build" or "matrix").
  -h         Show this help and exit.

Examples:
  # Execute every job in the workflow (matrix + build):
    $(basename "$0")

  # Just execute the build matrix (much faster):
    $(basename "$0") -j build
EOF
}

#----------------------------------------------------------------------------
# 3. Command-line argument parsing
#----------------------------------------------------------------------------
JOB_FILTER=""
while getopts ":j:h" opt; do
  case "${opt}" in
    j) JOB_FILTER="${OPTARG}" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

#----------------------------------------------------------------------------
# 4. Resolve act binary
#----------------------------------------------------------------------------
if [[ -x "${REPO_ROOT}/bin/act" ]]; then
  ACT_BIN="${REPO_ROOT}/bin/act"
elif command -v act >/dev/null 2>&1; then
  ACT_BIN="$(command -v act)"
else
  echo "❌  'act' is not installed (expected ./bin/act or global binary)." >&2
  exit 1
fi

#----------------------------------------------------------------------------
# 5. Assemble act arguments
#----------------------------------------------------------------------------
declare -a ACT_ARGS
ACT_ARGS+=("${DEFAULT_EVENT}")                            # simulate PR
[[ -n "${JOB_FILTER}" ]] && ACT_ARGS+=(--job "${JOB_FILTER}")
ACT_ARGS+=("-P" "ubuntu-latest=${DEFAULT_RUNNER_IMAGE}")  # proper runner
ACT_ARGS+=(--secret "GITHUB_TOKEN=${DUMMY_TOKEN}")        # dummy secret

#----------------------------------------------------------------------------
# 6. Run act
#----------------------------------------------------------------------------
echo "🔍  Executing workflow locally with the following invocation:"
echo "     ${ACT_BIN} ${ACT_ARGS[*]}"
echo

# Change into the repository root so 'act' finds the workflow files.
pushd "${REPO_ROOT}" >/dev/null
"${ACT_BIN}" "${ACT_ARGS[@]}"
popd >/dev/null

echo
echo "✅  Local workflow run complete."
echo "    • Event simulated : ${DEFAULT_EVENT}"
echo "    • Job filter      : ${JOB_FILTER:-<all jobs>}"
echo "    • Runner image    : ${DEFAULT_RUNNER_IMAGE}"
echo
echo "No images were pushed – publish steps are automatically skipped in PR mode."