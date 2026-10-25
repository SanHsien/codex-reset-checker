from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_dependency_freshness as checker


def test_is_newer_version_compares_at_declared_depth() -> None:
    assert checker.is_newer_version("0.17.2", "0.16")
    assert not checker.is_newer_version("0.16.9", "0.16")
    assert not checker.is_newer_version("9.1.1", "9")
    assert checker.is_newer_version("10.0.0", "9")
    assert not checker.is_newer_version("unknown", "9")


def test_parse_requirements_reads_hold_marker() -> None:
    packages = checker.parse_requirements(
        "pytest>=9\nruff>=0.16  # freshness-hold: pinned for CI\n# comment\n-r other.txt\n",
        "requirements-dev.txt",
    )
    assert [p["name"] for p in packages] == ["pytest", "ruff"]
    assert packages[0]["minimum"] == "9"
    assert packages[0]["hold"] == ""
    assert packages[1]["hold"] == "pinned for CI"


def test_load_deferrals_requires_latest_and_reason(tmp_path: Path) -> None:
    path = tmp_path / "deferrals.json"
    path.write_text(
        json.dumps(
            {
                "deferrals": {
                    "Ruff": {"deferredLatest": "0.17", "reason": "reviewed"},
                    "pytest": {"deferredLatest": "10"},
                    "bad": "x",
                }
            }
        ),
        encoding="utf-8",
    )
    assert checker.load_deferrals(path) == {"ruff": ("0.17", "reviewed")}
    assert checker.load_deferrals(tmp_path / "missing.json") == {}


def test_deferral_expires_once_pypi_moves_past_it(monkeypatch) -> None:
    package = {
        "name": "ruff",
        "minimum": "0.16",
        "requirement": "ruff>=0.16",
        "source": "requirements-dev.txt",
        "hold": "",
    }
    deferrals = {"ruff": ("0.17", "reviewed")}

    monkeypatch.setattr(checker, "fetch_pypi_version", lambda name: "0.17.9")
    [row] = checker.collect_status([package], deferrals)
    assert row["outdated"] and row["deferred_reason"] == "reviewed"
    assert not checker.needs_review(row)

    monkeypatch.setattr(checker, "fetch_pypi_version", lambda name: "0.18.0")
    [row] = checker.collect_status([package], deferrals)
    assert row["deferred_reason"] == ""
    assert checker.needs_review(row)


def test_repo_deferrals_all_carry_a_reason() -> None:
    raw = json.loads(checker.DEFERRALS_PATH.read_text(encoding="utf-8"))
    entries = raw.get("deferrals", {})
    assert len(checker.load_deferrals()) == len(entries)
