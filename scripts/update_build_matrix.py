#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
update_build_matrix.py
───────────────────────────────────────────────────────────────────────────────
Synchronise “.ci/build-matrix.yml” with the latest tags published in the
up-stream `saltcorn/saltcorn` GitHub repository.

Why?
====
The container build-pipeline enumerates which Saltcorn × Node permutations to
build from a single YAML source-of-truth.  
This script automates the *Saltcorn* portion of that matrix so that new
releases (stable or pre-release) are always captured without human effort.

Behaviour Overview
──────────────────
1. Pull **all git tags** from `github.com/saltcorn/saltcorn`.
2. Parse tags into Semantic Version objects.
3. Apply repository policy:

   • Keep the **three newest stable** tags (ignoring anything listed in
     `ignored_versions`).

   • Keep the **single newest pre-release** (`alpha` < `beta` < `rc`) whose
     *core* version is *not* already selected as stable.

   • Always **include** every entry under `required_versions` – these do *not*
     count towards the 3 + 1 quota.

4. Update the YAML keys inside “.ci/build-matrix.yml”:

   saltcorn:
     versions:  # ← ordered ascending
     default:   # ← newest stable
     edge:      # ← newest pre-release, else same as default

5. All file writes are **atomic** (temp-file + `os.replace`).

CLI
───
• `--dry-run` prints the would-be changes and exits with status 2 if the
  matrix *would* change.

• `--file` allows operating on an arbitrary YAML (handy for unit tests).

Dependencies
────────────
Only the Python 3 standard library and **PyYAML** (already present in the
dev-container).

Author
──────
Troy Kelly · <troy@team.production.city> · 2025-04-30
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
import tempfile
import textwrap
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import (
    ClassVar,
    Dict,
    List,
    Optional,
    Sequence,
    Set,
    Tuple,
)

import yaml

# ──────────────────────────────────────────────────────────────────────────────
# Constants – tweak with caution
# ──────────────────────────────────────────────────────────────────────────────
GITHUB_API_URL: str = (
    "https://api.github.com/repos/{owner}/{repo}/tags?per_page=100&page={page}"
)
REPO_OWNER: str = "saltcorn"
REPO_NAME: str = "saltcorn"

DEFAULT_MATRIX_FILE: Path = Path(".ci/build-matrix.yml")
STABLE_RELEASES_TO_KEEP: int = 3

LOGGER = logging.getLogger("update_build_matrix")


# ──────────────────────────────────────────────────────────────────────────────
# Semantic Version helper
# ──────────────────────────────────────────────────────────────────────────────
@dataclass(frozen=True, order=False, slots=True)
class SemVer:
    """Comparable Semantic Version model.

    Only features required by the Saltcorn workflow are implemented.  Build
    metadata (`+123`) is ignored for simplicity.
    """

    major: int
    minor: int
    patch: int
    pre_type: Optional[str] = None  # alpha | beta | rc | None
    pre_num: int = 0
    original: str = ""  # original tag string without leading “v”

    # Class-level precedence table – NOT considered a dataclass field
    _PRECEDENCE: ClassVar[Dict[Optional[str], int]] = {
        "alpha": 0,
        "beta": 1,
        "rc": 2,
        None: 3,  # Stable
    }

    _SEMVER_RE = re.compile(
        r"""
        ^v?                                   # optional “v” prefix
        (?P<maj>\d+)\.(?P<min>\d+)\.(?P<pat>\d+)   # core x.y.z
        (?:-                                   # start pre-release
          (?P<type>alpha|beta|rc)              # identifier
          \.(?P<num>\d+)                       # numeric component
        )?$
        """,
        re.IGNORECASE | re.VERBOSE,
    )

    # --------------------------------------------------------------------- #
    # Factory
    # --------------------------------------------------------------------- #
    @classmethod
    def parse(cls, tag: str) -> Optional["SemVer"]:
        """Return a SemVer for *tag* or ``None`` if pattern does not match."""
        m = cls._SEMVER_RE.match(tag)
        if not m:
            return None
        return cls(
            major=int(m["maj"]),
            minor=int(m["min"]),
            patch=int(m["pat"]),
            pre_type=(m["type"] or None),
            pre_num=int(m["num"] or 0),
            original=tag.lstrip("v"),
        )

    # --------------------------------------------------------------------- #
    # Convenience
    # --------------------------------------------------------------------- #
    @property
    def core(self) -> str:
        """Return “x.y.z” (no pre-release)."""
        return f"{self.major}.{self.minor}.{self.patch}"

    @property
    def is_prerelease(self) -> bool:
        return self.pre_type is not None

    # --------------------------------------------------------------------- #
    # Ordering
    # --------------------------------------------------------------------- #
    def _cmp_tuple(self) -> Tuple[int, int, int, int, int]:
        """Tuple defining sort precedence (bigger == newer)."""
        return (
            self.major,
            self.minor,
            self.patch,
            self._PRECEDENCE[self.pre_type],
            self.pre_num,
        )

    def __lt__(self, other: "SemVer") -> bool:  # type: ignore[override]
        return self._cmp_tuple() < other._cmp_tuple()

    # --------------------------------------------------------------------- #
    # Stringification
    # --------------------------------------------------------------------- #
    def __str__(self) -> str:  # noqa: D401 – keep simple
        if self.pre_type:
            return f"{self.core}-{self.pre_type}.{self.pre_num}"
        return self.core


# ──────────────────────────────────────────────────────────────────────────────
# GitHub REST helpers
# ──────────────────────────────────────────────────────────────────────────────
def fetch_all_tags(token: Optional[str] = None) -> List[str]:
    """Fetch **all** tag names from the upstream repository.

    Args:
        token: Optional GitHub personal-access token to increase rate-limit.

    Returns:
        List of raw tag strings, e.g. `["v1.2.0", "v1.2.0-beta.1", …]`.
    """
    tags: List[str] = []
    page: int = 1
    headers: Dict[str, str] = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    while True:
        url = GITHUB_API_URL.format(owner=REPO_OWNER, repo=REPO_NAME, page=page)
        LOGGER.debug("GET %s", url)
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                chunk: Sequence[Dict[str, str]] = json.load(resp)
        except urllib.error.HTTPError as exc:
            LOGGER.error("GitHub API error: %s", exc)
            sys.exit(1)

        if not chunk:
            break

        tags += [item["name"] for item in chunk]
        page += 1

    LOGGER.info("Fetched %d tags from GitHub", len(tags))
    return tags


# ──────────────────────────────────────────────────────────────────────────────
# Version selection helpers
# ──────────────────────────────────────────────────────────────────────────────
def classify_versions(
    tag_names: Sequence[str], ignored: Set[str]
) -> Tuple[List[SemVer], List[SemVer]]:
    """Categorise raw git tags.

    Args:
        tag_names:   Every tag string from GitHub.
        ignored:     Core versions (x.y.z) to *exclude* if they are stable.

    Returns:
        (stable_versions, prerelease_versions) – unsorted.
    """
    stable: List[SemVer] = []
    prerelease: List[SemVer] = []

    for raw in tag_names:
        ver = SemVer.parse(raw)
        if ver is None:
            LOGGER.debug("Skipping non-SemVer tag %s", raw)
            continue

        if not ver.is_prerelease and ver.core in ignored:
            LOGGER.debug("Ignoring stable tag %s (explicitly ignored)", ver)
            continue

        (prerelease if ver.is_prerelease else stable).append(ver)

    return stable, prerelease


def select_matrix_versions(
    stable: Sequence[SemVer], prereleases: Sequence[SemVer]
) -> Tuple[List[SemVer], Optional[SemVer]]:
    """Apply build-matrix policy and return selections."""
    newest_stable = sorted(stable, reverse=True)[:STABLE_RELEASES_TO_KEEP]

    stable_cores = {v.core for v in newest_stable}
    edge_candidates = [p for p in prereleases if p.core not in stable_cores]
    edge = sorted(edge_candidates, reverse=True)[0] if edge_candidates else None

    return newest_stable, edge


# ──────────────────────────────────────────────────────────────────────────────
# YAML manipulation
# ──────────────────────────────────────────────────────────────────────────────
def _sorted_unique(versions: Sequence[str]) -> List[str]:
    """Ascending sort (SemVer aware) with de-duplication."""
    mapping = {v: SemVer.parse(v) for v in versions}
    # All values came from SemVer.parse → mypy safe
    sorted_pairs = sorted(mapping.items(), key=lambda kv: kv[1])  # type: ignore[arg-type]
    return [k for k, _ in sorted_pairs]


def update_build_matrix(matrix_file: Path, *, dry_run: bool = False) -> bool:
    """Main orchestrator.

    Args:
        matrix_file: Path to YAML file to modify.
        dry_run:     If True no file is written (returns True if *would* change).

    Returns:
        True  if file changed (or would change in dry-run).  
        False if matrix already up-to-date.
    """
    token = os.getenv("GITHUB_TOKEN")
    all_tags = fetch_all_tags(token)

    with matrix_file.open("r", encoding="utf-8") as fh:
        yaml_root: Dict[str, Dict[str, object]] = yaml.safe_load(fh)

    salt: Dict[str, object] = yaml_root["saltcorn"]
    ignored: Set[str] = set(salt.get("ignored_versions", []))
    required: Set[str] = set(salt.get("required_versions", []))

    stable, prerelease = classify_versions(all_tags, ignored)
    sel_stable, edge = select_matrix_versions(stable, prerelease)
    default = sel_stable[0] if sel_stable else None

    # Build new versions list
    versions: List[str] = [str(v) for v in sel_stable]
    if edge:
        versions.append(str(edge))
    versions += [v for v in required if v not in versions]
    versions = _sorted_unique(versions)

    changed = False

    def _set(key: str, value: object) -> None:
        nonlocal changed
        if salt.get(key) != value:
            LOGGER.info("Updating saltcorn.%s → %s", key, value)
            salt[key] = value
            changed = True

    _set("versions", versions)
    if default:
        _set("default", str(default))
    _set("edge", str(edge) if edge else str(default))

    if not changed:
        LOGGER.info("Matrix already up-to-date")
        return False

    if dry_run:
        LOGGER.info("--dry-run specified; no file written")
        print(
            textwrap.dedent(
                f"""
                --- Proposed saltcorn section (excerpt) ----------------------
                {yaml.dump({'saltcorn': salt}, sort_keys=False).rstrip()}
                ----------------------------------------------------------------
                """
            )
        )
        return True

    LOGGER.info("Writing changes atomically → %s", matrix_file)
    fd, tmp = tempfile.mkstemp(suffix=".yml", dir=str(matrix_file.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            yaml.dump(yaml_root, out, sort_keys=False)
        os.replace(tmp, matrix_file)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

    return True


# ──────────────────────────────────────────────────────────────────────────────
# CLI glue
# ──────────────────────────────────────────────────────────────────────────────
def _build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="update_build_matrix",
        description="Synchronise .ci/build-matrix.yml with upstream Saltcorn tags.",
    )
    p.add_argument(
        "-f",
        "--file",
        type=Path,
        default=DEFAULT_MATRIX_FILE,
        help="Path to matrix YAML (default: %(default)s)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not write – print diff and exit 2 if changes needed.",
    )
    p.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity.",
    )
    return p


def main() -> None:
    args = _build_arg_parser().parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(levelname)-8s • %(message)s",
    )

    if not args.file.exists():
        LOGGER.error("Matrix file not found: %s", args.file)
        sys.exit(1)

    would_change = update_build_matrix(args.file, dry_run=args.dry_run)
    if args.dry_run and would_change:
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()