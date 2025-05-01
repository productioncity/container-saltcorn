"""
End-to-end pytest suite for `scripts/update_build_matrix.py`.

Network I/O is monkey-patched so tests run completely offline.
"""
from __future__ import annotations

from pathlib import Path
from typing import List, Sequence
from unittest import mock

import pytest
import yaml

from scripts.update_build_matrix import (
    SemVer,
    classify_versions,
    select_matrix_versions,
    update_build_matrix,
)

HERE = Path(__file__).parent
SAMPLE_YAML = HERE / "sample_matrix.yml"


# --------------------------------------------------------------------------- #
# Fixtures / helpers
# --------------------------------------------------------------------------- #
@pytest.fixture()
def matrix_copy(tmp_path: Path) -> Path:
    """Return a scratch-copy of the sample YAML for mutation tests."""
    dst = tmp_path / "matrix.yml"
    dst.write_text(SAMPLE_YAML.read_text(encoding="utf-8"), "utf-8")
    return dst


def mock_tags(tags: Sequence[str]):
    """Helper to patch `fetch_all_tags` in the target module."""
    return mock.patch(
        "scripts.update_build_matrix.fetch_all_tags", return_value=list(tags)
    )


# --------------------------------------------------------------------------- #
# Unit tests – SemVer mechanics
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize(
    "tag,expected",
    [
        ("1.2.3", (1, 2, 3, None, 0)),
        ("v1.2.3-beta.4", (1, 2, 3, "beta", 4)),
        ("1.2.3-rc.0", (1, 2, 3, "rc", 0)),
        ("1.2.3-alpha.9", (1, 2, 3, "alpha", 9)),
    ],
)
def test_semver_parse(tag: str, expected: tuple):
    ver = SemVer.parse(tag)
    assert ver
    assert (ver.major, ver.minor, ver.patch, ver.pre_type, ver.pre_num) == expected


def test_semver_sort_order():
    tags = ["1.2.0", "1.2.0-rc.0", "1.2.0-beta.1", "1.3.0-alpha.0"]
    vers = [SemVer.parse(t) for t in tags]  # type: ignore[list-item]
    vers = [v for v in vers if v]
    assert str(sorted(vers, reverse=True)[0]) == "1.2.0"


# --------------------------------------------------------------------------- #
# Selection logic
# --------------------------------------------------------------------------- #
def test_classify_respects_ignored():
    tags = ["1.1.1", "1.1.1-rc.1", "1.1.2", "1.2.0-beta.1"]
    stable, pre = classify_versions(tags, ignored={"1.1.2"})
    assert {str(v) for v in stable} == {"1.1.1"}
    assert {str(v) for v in pre} == {"1.1.1-rc.1", "1.2.0-beta.1"}


def test_policy_selection():
    stable = [SemVer.parse(s) for s in ["1.0.0", "1.1.3", "1.1.4", "1.1.5"]]  # type: ignore[list-item]
    pre = [SemVer.parse("1.2.0-rc.0")]  # type: ignore[list-item]
    stable = [v for v in stable if v]
    pre = [v for v in pre if v]
    s, e = select_matrix_versions(stable, pre)
    assert [str(v) for v in s] == ["1.1.5", "1.1.4", "1.1.3"]
    assert str(e) == "1.2.0-rc.0"


# --------------------------------------------------------------------------- #
# End-to-end file rewrite
# --------------------------------------------------------------------------- #
def test_required_versions_preserved(matrix_copy: Path):
    simulated = [
        "v1.0.0",
        "v1.1.0",
        "v1.1.3",
        "v1.1.4",
        "v1.1.5",
        "v1.2.0-rc.0",
    ]
    with mock_tags(simulated):
        changed = update_build_matrix(matrix_copy)
        assert changed

    updated = yaml.safe_load(matrix_copy.read_text(encoding="utf-8"))
    versions: List[str] = updated["saltcorn"]["versions"]
    assert "1.0.0" in versions  # required
    assert {"1.1.5", "1.1.4", "1.1.3", "1.2.0-rc.0"}.issubset(versions)


def test_no_duplicate_required(matrix_copy: Path):
    with mock_tags(["v1.0.0", "v1.1.4"]):
        update_build_matrix(matrix_copy)
    data = yaml.safe_load(matrix_copy.read_text(encoding="utf-8"))
    assert data["saltcorn"]["versions"].count("1.0.0") == 1


def test_dry_run_exit_code(matrix_copy: Path):
    with mock_tags(["v1.1.9"]):
        changed = update_build_matrix(matrix_copy, dry_run=True)
        assert changed
    # ensure file unchanged
    assert matrix_copy.read_text(encoding="utf-8") == SAMPLE_YAML.read_text(encoding="utf-8")