<#
.SYNOPSIS
    Codex Reset Checker - Windows 解除安裝腳本
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$HOME\.codex-reset-checker"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 從 PATH 字串移除目錄（忽略大小寫與結尾反斜線）；結果可能為空字串。
function Remove-PathEntry {
    param([string]$PathValue, [string]$Dir)
    $target = $Dir.TrimEnd('\')
    $entries = @(($PathValue -split ';') | Where-Object {
        $_.Trim() -ne "" -and $_.Trim().TrimEnd('\') -ine $target
    })
    return ($entries -join ';')
}

Write-Host "==> 解除安裝 Codex Reset Checker..." -ForegroundColor Cyan

# 1. 自 User PATH 移除
$binDir = Join-Path $InstallDir "bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($userPath) {
    $newUserPath = Remove-PathEntry $userPath $binDir
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, [EnvironmentVariableTarget]::User)
    Write-Host "   已自使用者 PATH 移除 $binDir" -ForegroundColor Gray
}

# 2. 移除開始功能表捷徑
$programsMenu = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
$menuAppFolder = Join-Path $programsMenu "Codex Reset Checker"
if (Test-Path -LiteralPath $menuAppFolder) {
    Remove-Item -LiteralPath $menuAppFolder -Recurse -Force
    Write-Host "   已移除開始功能表捷徑" -ForegroundColor Gray
}

# 3. 移除桌面捷徑
$desktopFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
$desktopShortcut = Join-Path $desktopFolder "Codex Reset Tray.lnk"
if (Test-Path -LiteralPath $desktopShortcut) {
    Remove-Item -LiteralPath $desktopShortcut -Force
    Write-Host "   已移除桌面捷徑" -ForegroundColor Gray
}

# 4. 移除開機啟動捷徑
$startupFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
$startupShortcut = Join-Path $startupFolder "CodexResetTray.lnk"
if (Test-Path -LiteralPath $startupShortcut) {
    Remove-Item -LiteralPath $startupShortcut -Force
}

# 5. 移除安裝目錄
if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
    Write-Host "   已清除安裝檔案: $InstallDir" -ForegroundColor Gray
}

Write-Host "Codex Reset Checker 解除安裝完成。" -ForegroundColor Green
