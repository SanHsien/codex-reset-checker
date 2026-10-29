from __future__ import annotations

import codecs
import json
import os
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


WINDOWS_POWERSHELL = shutil.which("powershell")
CSCRIPT = shutil.which("cscript")


def run_pwsh(
    args: list[str], shell: str | None = None, **kwargs
) -> subprocess.CompletedProcess[str]:
    exe = shell or PWSH
    assert exe is not None
    return subprocess.run(
        [exe, "-NoProfile", "-NonInteractive", *args],
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
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. $TrayScript
$data = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
Get-TraySummary $data | ConvertTo-Json -Compress
$empty = '{"available_count":0,"credits":[],"usage":null,"usage_raw":null,"account_status":null}' | ConvertFrom-Json
Get-TraySummary $empty | ConvertTo-Json -Compress
"""


@needs_pwsh
@pytest.mark.skipif(NODE is None, reason="node not available")
@pytest.mark.parametrize("shell_name", ["pwsh", "powershell"])
def test_tray_summary_reads_real_cli_json(shell_name: str, tmp_path: Path) -> None:
    # 托盤在沒有 pwsh 的機器上改用 Windows PowerShell 5.1，兩個 host 都要能載入並正確處理中文
    shell = PWSH if shell_name == "pwsh" else WINDOWS_POWERSHELL
    if shell is None:
        pytest.skip(f"{shell_name} not available")
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
        ["-File", str(probe), str(ROOT / "scripts" / "codex-reset-tray.ps1"), str(json_path)],
        shell=shell,
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
    assert empty["PrimaryReset"] == "即將重置"


FUNCTION_PROBE = r"""
param([string]$ScriptPath, [string]$Name, [string]$Current, [string]$Dir)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
$def = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
if (-not $def) { throw "function $Name not found in $ScriptPath" }
. ([scriptblock]::Create($def.Extent.Text))
& $Name $Current $Dir
"""


def call_path_function(script: str, name: str, current: str, directory: str, tmp: Path) -> str:
    probe = tmp / "fn_probe.ps1"
    probe.write_text(FUNCTION_PROBE, encoding="utf-8")
    result = run_pwsh(
        ["-File", str(probe), str(ROOT / "scripts" / script), name, current, directory]
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout.strip()


@needs_pwsh
@pytest.mark.parametrize(
    ("current", "expected"),
    [
        ("", r"C:\bin"),
        (r"C:\Only", r"C:\Only;C:\bin"),
        (r"C:\A;C:\B", r"C:\A;C:\B;C:\bin"),
        (r"C:\A;C:\BIN\;C:\B", r"C:\A;C:\BIN\;C:\B"),
        (r"C:\A;;C:\B;", r"C:\A;C:\B;C:\bin"),
    ],
)
def test_install_path_entry_is_appended_once(current: str, expected: str, tmp_path: Path) -> None:
    assert call_path_function("install.ps1", "Add-PathEntry", current, r"C:\bin", tmp_path) == expected


@needs_pwsh
@pytest.mark.parametrize(
    ("current", "expected"),
    [
        (r"C:\bin", ""),
        (r"C:\A;C:\bin\;C:\B", r"C:\A;C:\B"),
        (r"C:\A", r"C:\A"),
    ],
)
def test_uninstall_path_entry_is_removed(current: str, expected: str, tmp_path: Path) -> None:
    assert call_path_function("uninstall.ps1", "Remove-PathEntry", current, r"C:\bin", tmp_path) == expected


LAUNCHER = ROOT / "scripts" / "launch-tray.vbs"
BASE_DIRS = [
    str(Path(os.environ.get("SystemRoot", "C:/Windows")) / "System32"),
    str(Path(os.environ.get("SystemRoot", "C:/Windows"))),
]


def print_launcher_shell(path_dirs: list[str]) -> str:
    assert CSCRIPT is not None
    env = {**os.environ, "PATH": os.pathsep.join(path_dirs)}
    result = subprocess.run(
        [CSCRIPT, "//nologo", str(LAUNCHER), "--print-shell"],
        capture_output=True,
        text=True,
        errors="replace",
        timeout=60,
        env=env,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout.strip()


@pytest.mark.skipif(CSCRIPT is None, reason="cscript not available")
def test_launcher_falls_back_to_windows_powershell_without_pwsh(tmp_path: Path) -> None:
    # PATH 只有系統目錄（沒有 pwsh）
    assert print_launcher_shell(BASE_DIRS) == "powershell.exe"


@pytest.mark.skipif(CSCRIPT is None, reason="cscript not available")
def test_launcher_prefers_pwsh_when_available(tmp_path: Path) -> None:
    (tmp_path / "pwsh.cmd").write_text("@echo off", encoding="ascii")
    assert print_launcher_shell([str(tmp_path), *BASE_DIRS]) == "pwsh"


PARSE_PROBE = r"""
param([string]$Path)
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
$errs | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }
if ($errs.Count -gt 0) { exit 1 }
"""


@pytest.mark.skipif(WINDOWS_POWERSHELL is None, reason="Windows PowerShell not available")
@pytest.mark.parametrize("name", ["uninstall.ps1", "codex-reset-tray.ps1"])
def test_user_scripts_parse_in_windows_powershell_5_1(name: str, tmp_path: Path) -> None:
    # 沒有 pwsh 的機器會以 powershell.exe 5.1 執行：不得有 7+ 專屬語法，
    # 含中文的檔案也必須有 BOM，否則 5.1 以系統碼頁誤讀而解析失敗。
    probe = tmp_path / "parse.ps1"
    probe.write_text(PARSE_PROBE, encoding="utf-8")
    result = run_pwsh(
        ["-File", str(probe), str(ROOT / "scripts" / name)], shell=WINDOWS_POWERSHELL
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_install_script_has_no_bom_for_irm_iex() -> None:
    # README 的一行安裝是 `irm <url> | iex`：BOM 會變成字串開頭的 U+FEFF，
    # 讓開頭的 <# 區塊註解失效、整支腳本解析失敗。irm 會依 charset 正確解碼中文，不需要 BOM。
    assert not (ROOT / "scripts" / "install.ps1").read_bytes().startswith(codecs.BOM_UTF8)


QUERY_PROBE = r"""
param([string]$TrayScript, [string]$FakeRoot, [string]$Mode)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. $TrayScript
$cliExe = $null
$repoRoot = $FakeRoot
$AuthPath = $null
$env:TRAY_QUERY_TEST_MODE = $Mode
$clock = [Diagnostics.Stopwatch]::StartNew()
$data = Invoke-CheckerQuery -TimeoutMilliseconds 500
$errorText = Get-Variable -Name LastQueryError -Scope Global -ValueOnly -ErrorAction SilentlyContinue
$elapsed = $clock.ElapsedMilliseconds
$busy = $global:IsQuerying
$env:TRAY_QUERY_TEST_MODE = 'success'
$retry = Invoke-CheckerQuery -TimeoutMilliseconds 2000
$retryError = $global:LastQueryError
$global:LastQueryError = $errorText
$global:TrayIcon = [pscustomobject]@{ Text = '' }
function Invoke-CheckerQuery { return $null }
Update-TrayStatus
[pscustomobject]@{
    Data = $data; Error = $errorText; Elapsed = $elapsed
    Busy = $busy; Retry = $retry; HostVersion = $PSVersionTable.PSVersion.ToString()
    Tooltip = $global:TrayIcon.Text; RetryError = $retryError
} | ConvertTo-Json -Compress
"""

FAKE_QUERY_CLI = r"""
const fs = require('fs');
const path = require('path');
fs.appendFileSync(path.join(__dirname, 'pids.txt'), process.pid + '\n');
const mode = process.env.TRAY_QUERY_TEST_MODE;
if (mode === 'hang') setInterval(() => {}, 1000);
else if (mode === 'stderr-hang') {
  fs.writeSync(2, Buffer.alloc(2 * 1024 * 1024, 'e'));
  setInterval(() => {}, 1000);
} else if (mode === 'nonzero') process.exit(2);
else if (mode === 'invalid') console.log('invalid json');
else {
  fs.writeSync(2, Buffer.alloc(2 * 1024 * 1024, 'e'));
  console.log(JSON.stringify({available_count: 3}));
}
"""


@pytest.mark.skipif(NODE is None, reason="node not available")
@pytest.mark.parametrize("shell", [PWSH, WINDOWS_POWERSHELL], ids=["7", "5.1"])
@pytest.mark.parametrize("mode", ["hang", "stderr-hang", "success", "nonzero", "invalid"])
def test_tray_query_deadline_and_streams(shell: str | None, mode: str, tmp_path: Path) -> None:
    if shell is None:
        pytest.skip("PowerShell host not available")
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    (fake_bin / "codex-reset-checker.js").write_text(FAKE_QUERY_CLI, encoding="utf-8")
    probe = tmp_path / "query.ps1"
    probe.write_text(QUERY_PROBE, encoding="utf-8-sig")
    proc = subprocess.Popen(
        [shell, "-NoProfile", "-NonInteractive", "-File", str(probe),
         str(ROOT / "scripts" / "codex-reset-tray.ps1"), str(tmp_path), mode],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding="utf-8", errors="replace",
    )
    try:
        try:
            stdout, stderr = proc.communicate(timeout=8)
        except subprocess.TimeoutExpired:
            pytest.fail(f"{mode}: query blocked beyond watchdog (8 seconds)")
        assert proc.returncode == 0, stdout + stderr
        result = json.loads(stdout.strip().splitlines()[-1])
        assert result["HostVersion"].startswith("7." if shell == PWSH else "5.1.")
        assert result["Elapsed"] < 4000
        assert result["Busy"] is False
        assert result["Retry"]["available_count"] == 3
        assert not result["RetryError"]
        if mode == "success":
            assert result["Data"]["available_count"] == 3
            assert not result["Error"]
        else:
            assert result["Data"] is None
            assert result["Error"]
            assert result["Tooltip"] == "Codex: " + result["Error"]
            if "hang" in mode:
                assert "逾時" in result["Error"]
        for pid in (fake_bin / "pids.txt").read_text().splitlines():
            check = subprocess.run(
                [shell, "-NoProfile", "-NonInteractive", "-Command",
                 f"if (Get-Process -Id {int(pid)} -ErrorAction SilentlyContinue) {{ exit 1 }}"],
                capture_output=True, timeout=10,
            )
            assert check.returncode == 0, f"fake CLI {pid} survived query"
    finally:
        if proc.poll() is None:
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"],
                           capture_output=True, timeout=10)
            proc.communicate(timeout=10)
