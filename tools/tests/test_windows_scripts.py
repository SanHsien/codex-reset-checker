from __future__ import annotations

import json
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


NODE_JSON_OUTPUT = r"""
const checker = require(process.argv[1]);
const now = Math.floor(Date.now() / 1000);
const usageRaw = {
  plan_type: 'pro',
  rate_limit: {
    primary_window: { used_percent: 42, limit_window_seconds: 18000, reset_after_seconds: 8100, reset_at: now + 8100 },
    secondary_window: { used_percent: 18, limit_window_seconds: 604800, reset_after_seconds: 345600, reset_at: now + 345600 },
  },
};
const result = { available_count: 2, credits: [{ id: 'a' }, { id: 'b' }] };
checker.renderOutput(result, checker.normalizeUsageResponse(usageRaw), usageRaw, null, null,
  { json: true, accessToken: 'tok-secret-123', accountId: 'acct-secret-456' });
"""

SUMMARY_PROBE = r"""
param([string]$TrayScript, [string]$JsonPath)
. $TrayScript
$data = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
Get-TraySummary $data | ConvertTo-Json -Compress
$empty = '{"available_count":0,"credits":[],"usage":null,"usage_raw":null,"account_status":null}' | ConvertFrom-Json
Get-TraySummary $empty | ConvertTo-Json -Compress
"""


@needs_pwsh
@pytest.mark.skipif(NODE is None, reason="node not available")
def test_tray_summary_reads_real_cli_json(tmp_path: Path) -> None:
    cli = subprocess.run(
        [NODE, "-e", NODE_JSON_OUTPUT, str(ROOT / "bin" / "codex-reset-checker.js")],
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=60,
    )
    assert cli.returncode == 0, cli.stderr
    json_path = tmp_path / "cli.json"
    json_path.write_text(cli.stdout, encoding="utf-8")
    probe = tmp_path / "probe.ps1"
    probe.write_text(SUMMARY_PROBE, encoding="utf-8")

    result = run_pwsh(
        ["-File", str(probe), str(ROOT / "scripts" / "codex-reset-tray.ps1"), str(json_path)]
    )
    assert result.returncode == 0, result.stdout + result.stderr
    full, empty = (json.loads(line) for line in result.stdout.strip().splitlines()[-2:])

    assert full["Plan"] == "pro"
    assert full["Credits"] == 2
    assert full["PrimaryUsed"] == 42
    assert full["SecondaryUsed"] == 18
    assert "2h" in full["PrimaryReset"]
    assert "4d" in full["SecondaryReset"]

    # 缺欄位（查詢失敗）時不得丟例外，並退回預設值
    assert empty["Credits"] == 0
    assert empty["PrimaryUsed"] == 0
