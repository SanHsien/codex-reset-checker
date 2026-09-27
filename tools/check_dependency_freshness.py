"""Compare the declared requirement ranges against the latest PyPI releases.

Dependabot proposes upgrades one pull request at a time, which answers "is there a
newer release of this package?" but never "how far behind is what we declare?".
This reads every direct requirement the repo declares, asks PyPI for the current
release of each, and writes a Markdown report.

It compares declarations only. Nothing here inspects the installed environment and
nothing here edits a requirements file: a newer release is a prompt to read the
changelog and run the suite, not a merge.

    python tools/check_dependency_freshness.py --output report.md --github-output
"""

from __future__ import annotations

import argparse
import json
import os
import re
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
USER_AGENT = "codex-reset-checker-dependency-freshness"

REQUIREMENT_FILES = (
    "requirements-dev.txt",
)

_REQUIREMENT_RE = re.compile(r"^([A-Za-z0-9_.-]+)(?:\[[^\]]+\])?\s*(.*)$")
_MINIMUM_RE = re.compile(r"(>=|>|==|~=)\s*([0-9][0-9A-Za-z.!+_-]*)")
_RELEASE_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)*")
HOLD_MARKER = "freshness-hold:"
DEFERRALS_PATH = REPO_ROOT / ".github" / "dependency-deferrals.json"


class DependencyCheckError(RuntimeError):
    """Raised when a requirements file cannot be read."""


def release_key(version: str) -> tuple[int, ...] | None:
    match = _RELEASE_RE.match(version.strip())
    if not match:
        return None
    return tuple(int(part) for part in match.group(0).split("."))


def is_newer_version(latest: str, declared: str) -> bool:
    latest_key = release_key(latest)
    declared_key = release_key(declared)
    if latest_key is None or declared_key is None:
        return False
    depth = len(declared_key)
    padded = latest_key + (0,) * (depth - len(latest_key))
    return padded[:depth] > declared_key


def load_deferrals(path: Path = DEFERRALS_PATH) -> dict[str, tuple[str, str]]:
    try:
        entries = json.loads(path.read_text(encoding="utf-8")).get("deferrals", {})
    except (OSError, ValueError):
        return {}
    deferrals: dict[str, tuple[str, str]] = {}
    for name, entry in (entries or {}).items():
        if not isinstance(entry, dict):
            continue
        latest = str(entry.get("deferredLatest", "")).strip()
        reason = str(entry.get("reason", "")).strip()
        if latest and reason:
            deferrals[name.lower()] = (latest, reason)
    return deferrals


def parse_requirements(text: str, source: str) -> list[dict[str, str]]:
    packages: list[dict[str, str]] = []
    for raw_line in text.splitlines():
        comment = raw_line.split("#", 1)[1].strip() if "#" in raw_line else ""
        line = raw_line.split("#", 1)[0].strip()
        if not line or line.startswith("-"):
            continue
        hold = comment[len(HOLD_MARKER):].strip() if comment.startswith(HOLD_MARKER) else ""
        head = line.split(";", 1)[0].strip()
        match = _REQUIREMENT_RE.match(head)
        if not match:
            continue
        name, specifiers = match.groups()
        minimum = _MINIMUM_RE.search(specifiers)
        packages.append(
            {
                "name": name,
                "minimum": minimum.group(2) if minimum else "",
                "requirement": line,
                "source": source,
                "hold": hold,
            }
        )
    return packages


def load_direct_dependencies(root: Path = REPO_ROOT) -> list[dict[str, str]]:
    packages: list[dict[str, str]] = []
    seen: set[str] = set()
    for name in REQUIREMENT_FILES:
        path = root / name
        if not path.is_file():
            raise DependencyCheckError(f"missing requirements file: {name}")
        for package in parse_requirements(path.read_text(encoding="utf-8"), name):
            key = package["name"].lower().replace("_", "-")
            if key in seen:
                continue
            seen.add(key)
            packages.append(package)
    return packages


def fetch_pypi_version(package_name: str, timeout: float = 10.0) -> str | None:
    quoted_name = urllib.parse.quote(package_name, safe="")
    request = urllib.request.Request(
        f"https://pypi.org/pypi/{quoted_name}/json",
        headers={"Accept": "application/json", "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (OSError, ValueError):
        return None
    version = payload.get("info", {}).get("version")
    return str(version) if version else None


def collect_status(
    packages: list[dict[str, str]],
    deferrals: dict[str, tuple[str, str]] | None = None,
) -> list[dict[str, object]]:
    deferrals = deferrals if deferrals is not None else load_deferrals()
    rows: list[dict[str, object]] = []
    for package in packages:
        minimum = package["minimum"]
        latest = fetch_pypi_version(package["name"])
        reviewed, reason = deferrals.get(package["name"].lower(), ("", ""))
        deferred = bool(reviewed and latest and not is_newer_version(latest, reviewed))
        rows.append(
            {
                **package,
                "latest": latest or "unknown",
                "outdated": bool(minimum and latest and is_newer_version(latest, minimum)),
                "check_failed": not minimum or latest is None,
                "deferred_reason": reason if deferred else "",
            }
        )
    return rows


def needs_review(row: dict[str, object]) -> bool:
    return (
        bool(row["outdated"])
        and not row.get("hold")
        and not row.get("deferred_reason")
    )


def render_markdown(rows: list[dict[str, object]], error: str | None = None) -> str:
    lines = ["# Dependency freshness report", ""]
    if error:
        lines.extend(["## Check failed", "", f"```text\n{error}\n```", ""])
        return "\n".join(lines)

    lines.extend(
        [
            "| Package | Declared in | Requirement | PyPI latest | Status |",
            "| --- | --- | --- | --- | --- |",
        ]
    )
    for row in rows:
        if row["check_failed"]:
            status = "CHECK FAILED"
        elif row.get("hold") and row["outdated"]:
            status = f"HELD: {row['hold']}"
        elif row.get("deferred_reason") and row["outdated"]:
            status = f"DEFERRED at {row['latest']}: {row['deferred_reason']}"
        elif row["outdated"]:
            status = "REVIEW UPDATE"
        else:
            status = "OK"
        lines.append(
            f"| `{row['name']}` | `{row['source']}` | `{row['requirement']}` | "
            f"`{row['latest']}` | {status} |"
        )
    if not rows:
        lines.append("| - | - | - | - | CHECK FAILED |")
    lines.extend(
        [
            "",
            "Declared ranges are compared against PyPI. The installed environment is",
            "not inspected and no file is edited by this check.",
            "",
            "## Review policy",
            "",
            "0. A red line has exactly two honest exits, and both leave a reason behind:",
            "   `# freshness-hold: <why>` on the declaring line for a standing policy, or",
            "   an entry in `.github/dependency-deferrals.json` with `deferredLatest` for",
            "   \"reviewed, not now\" -- that one expires by itself once PyPI moves past the",
            "   release it was reviewed against. Raising the declared floor to silence the",
            "   report is not one of them: the declaration is a compatibility promise, not a",
            "   mute button.",
            "1. Read the release notes, and check the supported Python versions.",
            "2. Run `python -m pytest` and `ruff check` before widening a range.",
            "3. A ruff bump can surface new rules across the tree; land it on its own",
            "   rather than inside a change that is about something else.",
            "",
        ]
    )
    return "\n".join(lines)


def write_github_output(rows: list[dict[str, object]], report_path: Path) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        return
    outdated = any(needs_review(row) for row in rows)
    check_failed = not rows or any(bool(row["check_failed"]) for row in rows)
    with open(output_path, "a", encoding="utf-8") as output:
        output.write(f"outdated={'true' if outdated else 'false'}\n")
        output.write(f"check_failed={'true' if check_failed else 'false'}\n")
        output.write(
            f"needs_attention={'true' if outdated or check_failed else 'false'}\n"
        )
        output.write(f"report_path={report_path.as_posix()}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="dependency-freshness-report.md")
    parser.add_argument(
        "--github-output",
        action="store_true",
        help="Write status fields to GITHUB_OUTPUT",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Return non-zero when a declared range has aged.",
    )
    args = parser.parse_args()

    rows: list[dict[str, object]] = []
    error: str | None = None
    try:
        rows = collect_status(load_direct_dependencies())
    except DependencyCheckError as exc:
        error = str(exc)

    report = render_markdown(rows, error)
    output_path = Path(args.output)
    output_path.write_text(report, encoding="utf-8")
    print(report)

    if args.github_output:
        write_github_output(rows, output_path)
    if error:
        return 2
    if args.strict and any(
        needs_review(row) or bool(row["check_failed"])
        for row in rows
    ):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
