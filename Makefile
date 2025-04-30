#------------------------------------------------------------------------------
# Makefile – Convenience targets for Saltcorn container development
#
# This Makefile’s primary role is to provide a thin wrapper around the local
# build helper script so that team members have a single, discoverable entry
# point.
#
# Targets:
#   make build   – Enumerate and (eventually) build all image permutations.
#
# ──────────────────────────────────────────────────────────────────────────────
# Author:  Troy Kelly <troy@team.production.city>
# History: 2025-04-30 • Initial scaffold
#------------------------------------------------------------------------------

.PHONY: build

build:
	@./scripts/build-local.sh