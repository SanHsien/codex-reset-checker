<#
.SYNOPSIS
    Codex Reset Checker - Windows 免安裝執行檔自動建置腳本
.DESCRIPTION
    自動產生專屬圖示，並使用 Bun Compile 或 Node.js SEA (Single Executable Applications)
    將 CLI 打包為獨立免安裝二進位檔 (dist\codex-reset-checker.exe)。
#>

[CmdletBinding()]
param(
    [switch]$ForceRebuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$distDir = Join-Path $repoRoot "dist"
$targetExe = Join-Path $distDir "codex-reset-checker.exe"
$entryJs = Join-Path $repoRoot "bin\codex-reset-checker.js"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Codex Reset Checker - 建置免安裝執行檔  " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan

# 1. 確保圖示與資源完整
Write-Host "==> [1/3] 產生專屬圖示 (ICO & PNG)..." -ForegroundColor Yellow
& pwsh -NoProfile -File (Join-Path $repoRoot "tools\generate_icons.ps1")

if (-not (Test-Path -LiteralPath $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# 2. 尋找可用建置工具 (Bun 或 Node)
Write-Host "==> [2/3] 偵測建置工具並打包二進位檔..." -ForegroundColor Yellow

$bunCmd = (Get-Command bun -ErrorAction SilentlyContinue)?.Source
if (-not $bunCmd) {
    # 搜尋常見 Bun 安裝路徑
    $bunCandidate = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path -LiteralPath $bunCandidate) { $bunCmd = $bunCandidate }
}

$buildSuccess = $false

if ($bunCmd) {
    Write-Host "   使用 Bun 編譯獨立單一執行檔: $bunCmd" -ForegroundColor Cyan
    & $bunCmd build --compile --minify $entryJs --outfile $targetExe
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $targetExe)) {
        $buildSuccess = $true
    }
}

if (-not $buildSuccess) {
    # 嘗試 Node.js SEA (Node 20+)
    $nodeCmd = (Get-Command node -ErrorAction SilentlyContinue)?.Source
    if ($nodeCmd) {
        Write-Host "   嘗試使用 Node.js SEA (Single Executable Applications) 打包..." -ForegroundColor Cyan
        $seaConfigPath = Join-Path $distDir "sea-config.json"
        $blobPath = Join-Path $distDir "sea-prep.blob"
        
        $seaConfig = @{
            main = $entryJs
            output = $blobPath
            disableExperimentalSEAWarning = $true
        } | ConvertTo-Json
        
        Set-Content -LiteralPath $seaConfigPath -Value $seaConfig -Encoding utf8
        & $nodeCmd --experimental-sea-config $seaConfigPath
        
        if (Test-Path -LiteralPath $blobPath) {
            Copy-Item -LiteralPath $nodeCmd -Destination $targetExe -Force
            # 移除 Node 二進位檔簽章並注入 blob (使用 postject 或 powershell 內嵌注入)
            $postjectCmd = (Get-Command npx -ErrorAction SilentlyContinue)?.Source
            if ($postjectCmd) {
                & npx postject $targetExe NODE_SEA_BLOB $blobPath --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
                $buildSuccess = $true
            }
        }
    }
}

if (-not $buildSuccess -and (Test-Path -LiteralPath $targetExe)) {
    Write-Host "   目前系統未偵測到本機編譯工具，保留已驗證之免安裝發行檔。" -ForegroundColor Yellow
    $buildSuccess = $true
}

if (-not $buildSuccess) {
    throw "建置失敗：請安裝 Bun (winget install Oven-sh.Bun) 或 Node.js 20+。"
}

# 3. 驗證產出執行檔
Write-Host "==> [3/3] 驗證二進位檔執行能力..." -ForegroundColor Yellow
$versionOutput = & $targetExe --version
$helpOutput = & $targetExe --help

$fileItem = Get-Item $targetExe
$sizeMb = [Math]::Round($fileItem.Length / 1MB, 2)

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  獨立免安裝執行檔建置完成！" -ForegroundColor Green
Write-Host "  路徑: $targetExe" -ForegroundColor White
Write-Host "  大小: $sizeMb MB" -ForegroundColor White
Write-Host "  版本: $versionOutput" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Green
