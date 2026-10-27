from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_upstream_updates as checker


def test_upstream_slug_extraction() -> None:
    assert (
        checker.upstream_slug("https://github.com/doggy8088/codex-reset-checker.git")
        == "doggy8088/codex-reset-checker"
    )
    assert (
        checker.upstream_slug("https://github.com/doggy8088/codex-reset-checker")
        == "doggy8088/codex-reset-checker"
    )
    assert (
        checker.upstream_slug("git@github.com:doggy8088/codex-reset-checker.git")
        == "doggy8088/codex-reset-checker"
    )
    assert checker.upstream_slug("https://gitlab.com/some/repo.git") is None
