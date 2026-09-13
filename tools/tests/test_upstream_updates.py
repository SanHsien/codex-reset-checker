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


def test_render_ticket_section_when_none() -> None:
    lines = checker.render_ticket_section(
        title="Pull requests",
        watermark=4,
        tickets=None,
        kind="pr",
        decision_log="docs/DECISIONS.md",
    )
    text = "\n".join(lines)
    assert "Not checked" in text
    assert "Triaged through `#4`" in text


def test_render_ticket_section_when_empty() -> None:
    lines = checker.render_ticket_section(
        title="Pull requests",
        watermark=4,
        tickets=[],
        kind="pr",
        decision_log="docs/DECISIONS.md",
    )
    text = "\n".join(lines)
    assert "No new items above that number." in text


def test_render_ticket_section_with_items() -> None:
    tickets = [
        {"number": 5, "title": "feat: test feature"},
        {"number": 6, "title": "fix: pipe | symbol"},
    ]
    lines = checker.render_ticket_section(
        title="Pull requests",
        watermark=4,
        tickets=tickets,
        kind="pr",
        decision_log="docs/DECISIONS.md",
    )
    text = "\n".join(lines)
    assert "| #5 | feat: test feature |" in text
    assert r"| #6 | fix: pipe \| symbol |" in text
    assert "2 new item(s) to triage." in text
