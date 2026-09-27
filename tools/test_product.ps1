[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

Write-Host "--> 1. Node.js unit tests"
& node test/codex-reset-checker.test.js
if ($LASTEXITCODE -ne 0) {
    throw "Unit tests failed with exit code $LASTEXITCODE"
}

Write-Host "--> 2. CLI version check"
$versionOutput = (& node bin/codex-reset-checker.js --version | Out-String).Trim()
Write-Host "    Version: $versionOutput"
if (-not $versionOutput) {
    throw "CLI --version output was empty"
}

Write-Host "--> 3. CLI help check"
$helpText = & node bin/codex-reset-checker.js --help | Out-String
if ($helpText -notmatch "用法：") {
    throw "CLI --help did not contain expected usage text"
}

Write-Host "--> 4. NPM pack dry-run verification"
& npm pack --dry-run
if ($LASTEXITCODE -ne 0) {
    throw "npm pack --dry-run failed with exit code $LASTEXITCODE"
}

Write-Host "PRODUCT TESTS GREEN"
