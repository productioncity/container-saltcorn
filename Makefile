#------------------------------------------------------------------------------
# Makefile - Local developer toolbox for the Saltcorn Container project
#
# Synopsis
# --------
# This Makefile centralises every *safe* day-to-day task that a contributor may
# wish to execute locally.  Each target is merely a thin wrapper around the
# existing helper scripts found in `scripts/` or standard tooling such as
# `pytest`; no new logic is embedded here.
#
# Quick reference
# ───────────────
#   make / make help        Print this summary
#   make build              Enumerate (and eventually build) every image
#   make tags               Show every Docker/OCI tag produced by the matrix
#   make test               Run the full unit-test suite via PyTest
#   make matrix-dry-run     Preview an automated matrix refresh
#   make matrix             Regenerate `.ci/build-matrix.yml` in-place
#   make workflow           Re-run the GitHub Actions pipeline locally (act)
#
# Behavioural contract
# --------------------
# • *Read-only by default* - All targets avoid writing to the working tree or
#   remote registries unless explicitly documented otherwise.  The **matrix**
#   target is the only one that mutates repository state.
#
# • *Self-contained* -  No global utilities are assumed beyond:
#     - POSIX-compatible shell
#     - Python ≥ 3.12  (plus `pytest` for the *test* target)
#     - Docker (with Buildx) for container-related targets
#
# • *Clear output* -  Each invoked helper already prints verbose logs; this
#   Makefile therefore keeps commands silent (`@`) to reduce noise.
#
# ──────────────────────────────────────────────────────────────────────────────
# Author : Troy Kelly <troy@team.production.city>
# History:
#   2025-04-30 • Initial scaffold
#   2025-05-01 • Expanded with comprehensive dev targets & documentation
#------------------------------------------------------------------------------

# The first target becomes the default; point it at the help text.
.DEFAULT_GOAL := help

# Standard phony group
.PHONY: help build tags test matrix-dry-run matrix workflow workflow-build

#------------------------------------------------------------------------------
# help - human-friendly target list
#------------------------------------------------------------------------------
help:
	@echo ""
	@echo "Saltcorn - Local Developer Commands"
	@echo "===================================="
	@echo "Available targets:"
	@echo "  build            Enumerate (and eventually build) all image permutations"
	@echo "  tags             Print every OCI tag derived from the build matrix"
	@echo "  test             Run the pytest suite"
	@echo "  matrix-dry-run   Preview changes to .ci/build-matrix.yml (no write)"
	@echo "  matrix           Regenerate .ci/build-matrix.yml in-place"
	@echo "  workflow         Re-play the full GitHub Actions workflow locally with 'act'"
	@echo "  workflow-build   As above but only the \"build\" job (faster smoke-test)"
	@echo ""

#------------------------------------------------------------------------------
# build - enumerate/build local images
#------------------------------------------------------------------------------
build:
	@./scripts/build-local.sh

#------------------------------------------------------------------------------
# tags - preview every tag that *would* be produced by the matrix
#------------------------------------------------------------------------------
tags:
	@./scripts/dump-tags.sh

#------------------------------------------------------------------------------
# test - run the entire pytest suite
#------------------------------------------------------------------------------
test:
	@python -m pytest -q

#------------------------------------------------------------------------------
# matrix-dry-run - non-destructive preview of matrix regeneration
#------------------------------------------------------------------------------
matrix-dry-run:
	@python scripts/update_build_matrix.py --dry-run --file .ci/build-matrix.yml

#------------------------------------------------------------------------------
# matrix - regenerate the build-matrix file (writes to working tree)
#------------------------------------------------------------------------------
matrix:
	@python scripts/update_build_matrix.py --file .ci/build-matrix.yml

#------------------------------------------------------------------------------
# workflow - execute the GitHub Actions pipeline locally with 'act'
#------------------------------------------------------------------------------
workflow:
	@./scripts/test-workflow-local.sh

#------------------------------------------------------------------------------
# workflow-build - run only the “build” job via 'act' (quicker iteration)
#------------------------------------------------------------------------------
workflow-build:
	@./scripts/test-workflow-local.sh -j build