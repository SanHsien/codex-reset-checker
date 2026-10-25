<#
.SYNOPSIS
    Codex Reset Checker - Windows 一鍵安裝與環境配置腳本 (Zero-Friction Installer)
.DESCRIPTION
    自動將 codex-reset-checker 免安裝二進位檔與系統匣 GUI 安裝至本機使用者目錄 ($HOME\.codex-reset-checker)，
    自動設定 User PATH 環境變數（無需管理員權限）、建立開始功能表捷徑與專屬圖示。
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$HOME\.codex-reset-checker",
    [switch]$NoDesktopShortcut,
    [switch]$AutoStartTray
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 把目錄附加到 PATH 字串；已存在（忽略大小寫與結尾反斜線）就不重複。
# 以 @() 包住，PATH 只有一個項目時才不會被當成字串相加。
function Add-PathEntry {
    param([string]$PathValue, [string]$Dir)
    $entries = @(($PathValue -split ';') | Where-Object { $_.Trim() -ne "" })
    $target = $Dir.TrimEnd('\')
    $exists = @($entries | Where-Object { $_.Trim().TrimEnd('\') -ieq $target }).Count -gt 0
    if (-not $exists) { $entries += $Dir }
    return ($entries -join ';')
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Codex Reset Checker - Windows 安裝程式  " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan

# 1. 建立目標安裝目錄
$binDir = Join-Path $InstallDir "bin"
$assetsDir = Join-Path $InstallDir "assets"
$scriptsDir = Join-Path $InstallDir "scripts"

New-Item -ItemType Directory -Path $binDir -Force | Out-Null
New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

$scriptRoot = $PSScriptRoot
$repoRoot = if ($scriptRoot) { Split-Path -Parent $scriptRoot } else { $null }

# 2. 複製或下載檔案
$localExe = if ($repoRoot) { Join-Path $repoRoot "dist\codex-reset-checker.exe" } else { $null }
$targetExe = Join-Path $binDir "codex-reset-checker.exe"
$targetIco = Join-Path $assetsDir "icon.ico"
$targetPng = Join-Path $assetsDir "icon.png"

if ($localExe -and (Test-Path -LiteralPath $localExe)) {
    Write-Host "==> [1/4] 從本機專案複製執行檔與資源..." -ForegroundColor Yellow
    Copy-Item -LiteralPath $localExe -Destination $targetExe -Force
    
    $localIco = Join-Path $repoRoot "assets\icon.ico"
    if (Test-Path -LiteralPath $localIco) {
        Copy-Item -LiteralPath $localIco -Destination $targetIco -Force
    }
    $localPng = Join-Path $repoRoot "assets\icon.png"
    if (Test-Path -LiteralPath $localPng) {
        Copy-Item -LiteralPath $localPng -Destination $targetPng -Force
    }

    # 複製 GUI 腳本
    Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\codex-reset-tray.ps1") -Destination (Join-Path $scriptsDir "codex-reset-tray.ps1") -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\launch-tray.vbs") -Destination (Join-Path $scriptsDir "launch-tray.vbs") -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "codex-reset-tray.bat") -Destination (Join-Path $InstallDir "codex-reset-tray.bat") -Force
} else {
    Write-Host "==> [1/4] 從 GitHub Releases 下載最新免安裝執行檔..." -ForegroundColor Yellow
    $releaseUrl = "https://github.com/SanHsien/codex-reset-checker/releases/latest/download/codex-reset-checker.exe"
    $iconUrl = "https://raw.githubusercontent.com/SanHsien/codex-reset-checker/main/assets/icon.ico"
    $trayPs1Url = "https://raw.githubusercontent.com/SanHsien/codex-reset-checker/main/scripts/codex-reset-tray.ps1"
    $vbsUrl = "https://raw.githubusercontent.com/SanHsien/codex-reset-checker/main/scripts/launch-tray.vbs"

    Invoke-WebRequest -Uri $releaseUrl -OutFile $targetExe -UseBasicParsing
    Invoke-WebRequest -Uri $iconUrl -OutFile $targetIco -UseBasicParsing
    Invoke-WebRequest -Uri $trayPs1Url -OutFile (Join-Path $scriptsDir "codex-reset-tray.ps1") -UseBasicParsing
    Invoke-WebRequest -Uri $vbsUrl -OutFile (Join-Path $scriptsDir "launch-tray.vbs") -UseBasicParsing
}

Write-Host "   已安裝至: $InstallDir" -ForegroundColor Gray

# 3. 配置 User PATH 環境變數
Write-Host "==> [2/4] 配置 Windows 環境變數 (User PATH)..." -ForegroundColor Yellow
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $newUserPath = Add-PathEntry $userPath $binDir

    $alreadyInPath = @(($userPath -split ';') | Where-Object { $_.Trim().TrimEnd('\') -ieq $binDir.TrimEnd('\') }).Count -gt 0

    if (-not $alreadyInPath) {
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, [EnvironmentVariableTarget]::User)
        $env:Path = "$binDir;$env:Path"
        Write-Host "   已將 $binDir 加入使用者 PATH 環境變數。" -ForegroundColor Green
    } else {
        Write-Host "   $binDir 已在 PATH 中，無需重複新增。" -ForegroundColor Gray
    }
} catch {
    $env:Path = "$binDir;$env:Path"
    Write-Host "   提示：因環境權限限制，未持久寫入 User Registry，已於目前工作階段臨時載入 PATH。" -ForegroundColor Yellow
}

# 4. 建立 Windows 捷徑 (開始功能表與桌面)
Write-Host "==> [3/4] 建立開始功能表捷徑與應用圖示..." -ForegroundColor Yellow
try {
    $wsh = New-Object -ComObject WScript.Shell
    $programsMenu = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
    $menuAppFolder = Join-Path $programsMenu "Codex Reset Checker"
    New-Item -ItemType Directory -Path $menuAppFolder -Force | Out-Null

    # 4.1 CLI 捷徑
    $shortcutCli = $wsh.CreateShortcut((Join-Path $menuAppFolder "Codex Reset Checker (CLI).lnk"))
    $shortcutCli.TargetPath = "powershell.exe"
    $shortcutCli.Arguments = "-NoExit -Command `"& '$targetExe' --watch`""
    $shortcutCli.WorkingDirectory = $InstallDir
    if (Test-Path -LiteralPath $targetIco) { $shortcutCli.IconLocation = "$targetIco,0" }
    $shortcutCli.Description = "Codex/ChatGPT 額度查詢與重置檢查工具 (即時監看模式)"
    $shortcutCli.Save()

    # 4.2 GUI 系統匣小工具捷徑
    $trayVbs = Join-Path $scriptsDir "launch-tray.vbs"
    $shortcutTray = $wsh.CreateShortcut((Join-Path $menuAppFolder "Codex Reset Tray (常駐監看).lnk"))
    $shortcutTray.TargetPath = "wscript.exe"
    $shortcutTray.Arguments = "`"$trayVbs`""
    $shortcutTray.WorkingDirectory = $InstallDir
    if (Test-Path -LiteralPath $targetIco) { $shortcutTray.IconLocation = "$targetIco,0" }
    $shortcutTray.Description = "Codex Reset Checker 系統匣常駐小工具"
    $shortcutTray.Save()

    # 4.3 桌面捷徑 (可選)
    if (-not $NoDesktopShortcut) {
        $desktopFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
        $desktopShortcut = $wsh.CreateShortcut((Join-Path $desktopFolder "Codex Reset Tray.lnk"))
        $desktopShortcut.TargetPath = "wscript.exe"
        $desktopShortcut.Arguments = "`"$trayVbs`""
        $desktopShortcut.WorkingDirectory = $InstallDir
        if (Test-Path -LiteralPath $targetIco) { $desktopShortcut.IconLocation = "$targetIco,0" }
        $desktopShortcut.Description = "Codex Reset Checker 系統匣常駐小工具"
        $desktopShortcut.Save()
        Write-Host "   已在桌面建立捷徑: Codex Reset Tray.lnk" -ForegroundColor Gray
    }

    # 5. 開機自動啟動 (若有指定)
    if ($AutoStartTray) {
        $startupFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Startup)
        $startupShortcut = $wsh.CreateShortcut((Join-Path $startupFolder "CodexResetTray.lnk"))
        $startupShortcut.TargetPath = "wscript.exe"
        $startupShortcut.Arguments = "`"$trayVbs`""
        $startupShortcut.WorkingDirectory = $InstallDir
        if (Test-Path -LiteralPath $targetIco) { $startupShortcut.IconLocation = "$targetIco,0" }
        $startupShortcut.Save()
        Write-Host "   已設定為 Windows 開機自動常駐。" -ForegroundColor Gray
    }
} catch {
    Write-Host "   提示：跳過建立 Windows Shell 捷徑 ($($_.Exception.Message))" -ForegroundColor Yellow
}

Write-Host "==> [4/4] 驗證安裝..." -ForegroundColor Yellow
if (Test-Path -LiteralPath $targetExe) {
    & $targetExe --version
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  安裝成功！現在您可以：" -ForegroundColor Green
    Write-Host "  1. 打開任意命令提示字元或 PowerShell，輸入: codex-reset-checker" -ForegroundColor White
    Write-Host "  2. 從開始功能表啟動 'Codex Reset Tray' 開啟系統匣常駐圖示" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Green
}
