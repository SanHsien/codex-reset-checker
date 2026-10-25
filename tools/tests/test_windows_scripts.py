from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
PWSH = shutil.which("pwsh")
NODE = shutil.which("node")

needs_pwsh = pytest.mark.skipif(PWSH is None, reason="pwsh not available")

# 只求值 GetFolderPath 那幾行（無副作用），確認 SpecialFolder 寫法合法。
EVAL_FOLDER_LINES = r"""
param([string]$Path)
$lines = Select-String -LiteralPath $Path -Pattern 'GetFolderPath\(' | ForEach-Object { $_.Line }
foreach ($line in $lines) {
    $expr = ($line -replace '^.*?=\s*', '').Trim()
    if ($expr -notmatch '^\[(System\.)?Environment\]::GetFolderPath\(') { continue }
    $value = Invoke-Expression $expr
    if ([string]::IsNullOrWhiteSpace($value)) { throw "empty folder: $expr" }
}
"""


def run_pwsh(args: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    assert PWSH is not None
    return subprocess.run(
        [PWSH, "-NoProfile", "-NonInteractive", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=120,
        **kwargs,
    )


@needs_pwsh
@pytest.mark.parametrize("name", ["install.ps1", "uninstall.ps1"])
def test_special_folder_expressions_are_valid(name: str, tmp_path: Path) -> None:
    probe = tmp_path / "probe.ps1"
    probe.write_text(EVAL_FOLDER_LINES, encoding="utf-8")
    result = run_pwsh(["-File", str(probe), str(ROOT / "scripts" / name)])
    assert result.returncode == 0, result.stdout + result.stderr
