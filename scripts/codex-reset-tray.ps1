#Requires -Version 5.1
<#
.SYNOPSIS
    Codex Reset Checker - Windows 11 原生系統匣小工具 (System Tray App)
.DESCRIPTION
    常駐於 Windows 工作列通知區，背景定時監看 Codex/ChatGPT 額度，
    懸停顯示剩餘時間與次數，左鍵點擊展開 Fluent 深色卡片儀表板，支援右鍵選單與 Windows Toast 通知。
#>

[CmdletBinding()]
param(
    [string]$AuthPath,
    [int]$IntervalSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptRoot
$iconPath = Join-Path $repoRoot "assets\icon.ico"
if (-not (Test-Path -LiteralPath $iconPath)) {
    $iconPath = Join-Path $scriptRoot "icon.ico"
}

# 決定 CLI 執行檔路徑
$cliExe = Join-Path $repoRoot "dist\codex-reset-checker.exe"
if (-not (Test-Path -LiteralPath $cliExe)) {
    $cliExe = (Get-Command codex-reset-checker -ErrorAction SilentlyContinue)?.Source
}

# 全域狀態
$global:LastData = $null
$global:TrayIcon = $null
$global:CardWindow = $null
$global:IsQuerying = $false

function Get-Prop {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Format-ResetWords {
    param($Window)
    $seconds = Get-Prop $Window 'reset_after_seconds'
    if ($null -eq $seconds) { return "即將重置" }
    $totalMinutes = [math]::Floor([math]::Max(0, [double]$seconds) / 60)
    if ($totalMinutes -eq 0 -and [double]$seconds -gt 0) { $totalMinutes = 1 }
    $days = [math]::Floor($totalMinutes / 1440)
    $hours = [math]::Floor(($totalMinutes % 1440) / 60)
    $minutes = $totalMinutes % 60
    $parts = @()
    if ($days -gt 0) { $parts += "${days}d" }
    if ($hours -gt 0 -or $days -gt 0) { $parts += "${hours}h" }
    if ($minutes -gt 0 -or $parts.Count -eq 0) { $parts += "${minutes}m" }
    return ($parts -join " ") + " 後重置"
}

# 把 CLI `--json` 輸出（available_count／credits、usage、usage_raw）整理成系統匣顯示用的欄位。
function Get-TraySummary {
    param($Data)

    $credits = Get-Prop $Data 'available_count'
    if ($null -eq $credits) {
        $list = Get-Prop $Data 'credits'
        if ($null -eq $list) { $list = Get-Prop $Data 'items' }
        if ($null -eq $list) { $list = Get-Prop $Data 'data' }
        $credits = if ($null -ne $list) { @($list).Count } else { 0 }
    }

    $usage = Get-Prop $Data 'usage'
    $primary = Get-Prop $usage 'primary_window'
    $secondary = Get-Prop $usage 'secondary_window'
    $primaryUsed = Get-Prop $primary 'used_percent'
    $secondaryUsed = Get-Prop $secondary 'used_percent'
    $plan = Get-Prop (Get-Prop $Data 'usage_raw') 'plan_type'

    [pscustomobject]@{
        Plan           = if ($plan) { [string]$plan } else { "Codex" }
        Credits        = [int]$credits
        PrimaryUsed    = if ($null -ne $primaryUsed) { $primaryUsed } else { 0 }
        SecondaryUsed  = if ($null -ne $secondaryUsed) { $secondaryUsed } else { 0 }
        PrimaryReset   = Format-ResetWords $primary
        SecondaryReset = Format-ResetWords $secondary
    }
}

function Invoke-CheckerQuery {
    if ($global:IsQuerying) { return $null }
    $global:IsQuerying = $true
    try {
        $argsList = @("--json")
        if ($AuthPath) { $argsList += @("--auth", $AuthPath) }

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        if ($cliExe -and (Test-Path -LiteralPath $cliExe)) {
            $pinfo.FileName = $cliExe
            $pinfo.Arguments = ($argsList -join " ")
        } else {
            $jsPath = Join-Path $repoRoot "bin\codex-reset-checker.js"
            $pinfo.FileName = "node"
            $pinfo.Arguments = "`"$jsPath`" " + ($argsList -join " ")
        }

        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit(15000)

        if ($proc.ExitCode -eq 0 -and $stdout.Trim()) {
            $data = $stdout.Trim() | ConvertFrom-Json
            $global:LastData = $data
            return $data
        }
        return $null
    } catch {
        return $null
    } finally {
        $global:IsQuerying = $false
    }
}

function Update-TrayStatus {
    $data = Invoke-CheckerQuery
    if (-not $data) {
        if ($global:TrayIcon) {
            $global:TrayIcon.Text = "Codex: 無法取得額度"
        }
        return
    }

    $summary = Get-TraySummary $data
    $tip = "Codex: 5h用量 $($summary.PrimaryUsed)% | 週用量 $($summary.SecondaryUsed)% | 重置: $($summary.Credits) 次"
    if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 60) + "..." }
    if ($global:TrayIcon) {
        $global:TrayIcon.Text = $tip
    }
}

function Show-DashboardCard {
    if ($global:CardWindow -and $global:CardWindow.IsVisible) {
        $global:CardWindow.Close()
        $global:CardWindow = $null
        return
    }

    $data = $global:LastData
    if (-not $data) {
        $data = Invoke-CheckerQuery
    }

    if (-not $data) { return }
    $summary = Get-TraySummary $data
    $plan = $summary.Plan
    $credits = $summary.Credits
    $pUsed = $summary.PrimaryUsed
    $sUsed = $summary.SecondaryUsed
    $pReset = $summary.PrimaryReset
    $sReset = $summary.SecondaryReset

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Codex Reset Status"
        Width="350" Height="410"
        WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="False">
  <Border CornerRadius="16" Background="#0F172A" BorderBrush="#10B981" BorderThickness="1.5" Margin="10">
    <Border.Effect>
      <DropShadowEffect Color="#000000" BlurRadius="20" ShadowDepth="4" Opacity="0.6"/>
    </Border.Effect>
    <Grid Margin="18">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <!-- 標頭 -->
      <Grid Grid.Row="0" Margin="0,0,0,14">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="⚡" FontSize="18" Foreground="#10B981" Margin="0,0,6,0"/>
          <TextBlock Text="Codex 額度狀態" FontSize="16" FontWeight="SemiBold" Foreground="#F8FAFC"/>
          <Border Background="#1E293B" CornerRadius="8" Padding="6,2" Margin="8,0,0,0">
            <TextBlock Text="$plan" FontSize="11" Foreground="#38BDF8" FontWeight="Bold"/>
          </Border>
        </StackPanel>
        <Button Name="BtnClose" Content="✕" HorizontalAlignment="Right" Background="Transparent" Foreground="#94A3B8" BorderThickness="0" FontSize="14" Cursor="Hand" Width="26" Height="26"/>
      </Grid>

      <!-- 5 小時額度 -->
      <Border Grid.Row="1" Background="#1E293B" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
          <Grid>
            <TextBlock Text="5 小時工作階段" Foreground="#94A3B8" FontSize="12"/>
            <TextBlock Text="$pReset" HorizontalAlignment="Right" Foreground="#38BDF8" FontSize="11"/>
          </Grid>
          <ProgressBar Value="$pUsed" Maximum="100" Height="8" Margin="0,8,0,4" Background="#334155" Foreground="#10B981" BorderThickness="0"/>
          <TextBlock Text="已使用 $pUsed%" Foreground="#E2E8F0" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right"/>
        </StackPanel>
      </Border>

      <!-- 每週額度 -->
      <Border Grid.Row="2" Background="#1E293B" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
          <Grid>
            <TextBlock Text="每週限制視窗" Foreground="#94A3B8" FontSize="12"/>
            <TextBlock Text="$sReset" HorizontalAlignment="Right" Foreground="#38BDF8" FontSize="11"/>
          </Grid>
          <ProgressBar Value="$sUsed" Maximum="100" Height="8" Margin="0,8,0,4" Background="#334155" Foreground="#06B6D4" BorderThickness="0"/>
          <TextBlock Text="已使用 $sUsed%" Foreground="#E2E8F0" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right"/>
        </StackPanel>
      </Border>

      <!-- 手動重置額度 -->
      <Border Grid.Row="3" Background="#1E293B" CornerRadius="10" Padding="12" Margin="0,0,0,12">
        <Grid>
          <StackPanel>
            <TextBlock Text="手動重置額度 (Reset Credits)" Foreground="#94A3B8" FontSize="12"/>
            <TextBlock Text="可用 $credits 筆" Foreground="#10B981" FontSize="15" FontWeight="Bold" Margin="0,4,0,0"/>
          </StackPanel>
          <Button Name="BtnRedeem" Content="使用重置" HorizontalAlignment="Right" VerticalAlignment="Center" Padding="10,5" Background="#10B981" Foreground="#FFFFFF" BorderThickness="0" FontWeight="Bold" Cursor="Hand">
            <Button.Resources>
              <Style TargetType="Border">
                <Setter Property="CornerRadius" Value="6"/>
              </Style>
            </Button.Resources>
          </Button>
        </Grid>
      </Border>

      <!-- 底部操作列 -->
      <Grid Grid.Row="4" VerticalAlignment="Bottom">
        <Button Name="BtnWatch" Content="🖥️ 終端監看" HorizontalAlignment="Left" Padding="10,6" Background="#334155" Foreground="#F8FAFC" BorderThickness="0" Cursor="Hand">
          <Button.Resources>
            <Style TargetType="Border"><Setter Property="CornerRadius" Value="6"/></Style>
          </Button.Resources>
        </Button>
        <Button Name="BtnRefresh" Content="🔄 刷新" HorizontalAlignment="Right" Padding="12,6" Background="#0284C7" Foreground="#F8FAFC" BorderThickness="0" Cursor="Hand">
          <Button.Resources>
            <Style TargetType="Border"><Setter Property="CornerRadius" Value="6"/></Style>
          </Button.Resources>
        </Button>
      </Grid>
    </Grid>
  </Border>
</Window>
"@

    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    # 視窗定位在右下角 (工作列上方)
    $workingArea = [System.Windows.SystemParameters]::WorkArea
    $window.Left = $workingArea.Right - $window.Width - 10
    $window.Top = $workingArea.Bottom - $window.Height - 10

    # 事件綁定
    $btnClose = $window.FindName("BtnClose")
    $btnClose.add_Click({
        $global:CardWindow.Close()
        $global:CardWindow = $null
    })

    $btnRefresh = $window.FindName("BtnRefresh")
    $btnRefresh.add_Click({
        Update-TrayStatus
        $global:CardWindow.Close()
        $global:CardWindow = $null
        Show-DashboardCard
    })

    $btnWatch = $window.FindName("BtnWatch")
    $btnWatch.add_Click({
        if ($cliExe -and (Test-Path -LiteralPath $cliExe)) {
            Start-Process wt -ArgumentList "-w 0 new-tab --title `"Codex Rate Limit`" `"$cliExe`" --watch" -ErrorAction SilentlyContinue
        } else {
            $jsPath = Join-Path $repoRoot "bin\codex-reset-checker.js"
            Start-Process wt -ArgumentList "-w 0 new-tab --title `"Codex Rate Limit`" node `"$jsPath`" --watch" -ErrorAction SilentlyContinue
        }
    })

    $btnRedeem = $window.FindName("BtnRedeem")
    $btnRedeem.add_Click({
        $res = [System.Windows.Forms.MessageBox]::Show(
            "確定要使用一筆手動重置額度嗎？此操作不可復原。",
            "確認使用手動重置額度",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
            if ($cliExe -and (Test-Path -LiteralPath $cliExe)) {
                Start-Process wt -ArgumentList "-w 0 new-tab `"$cliExe`" --reset"
            } else {
                $jsPath = Join-Path $repoRoot "bin\codex-reset-checker.js"
                Start-Process wt -ArgumentList "-w 0 new-tab node `"$jsPath`" --reset"
            }
            $global:CardWindow.Close()
            $global:CardWindow = $null
        }
    })

    $global:CardWindow = $window
    $window.Show()
    $window.Activate()
}

# 被 dot-source（例如測試）時只載入函式，不建立系統匣圖示與訊息循環
if ($MyInvocation.InvocationName -eq '.') { return }

# 建立 NotifyIcon
$tray = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path -LiteralPath $iconPath) {
    $tray.Icon = New-Object System.Drawing.Icon($iconPath)
} else {
    $tray.Icon = [System.Drawing.SystemIcons]::Application
}
$tray.Text = "Codex Reset Checker"
$tray.Visible = $true

# 右鍵選單
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$itemStatus = $contextMenu.Items.Add("⚡ 開啟額度儀表板")
$itemStatus.add_Click({ Show-DashboardCard })
$itemStatus.Font = New-Object System.Drawing.Font($itemStatus.Font, [System.Drawing.FontStyle]::Bold)

$itemRefresh = $contextMenu.Items.Add("🔄 立即刷新")
$itemRefresh.add_Click({ Update-TrayStatus })

$itemWatch = $contextMenu.Items.Add("🖥️ 開啟終端監看 (Watch)")
$itemWatch.add_Click({
    if ($cliExe -and (Test-Path -LiteralPath $cliExe)) {
        Start-Process wt -ArgumentList "-w 0 new-tab --title `"Codex Rate Limit`" `"$cliExe`" --watch" -ErrorAction SilentlyContinue
    }
})

$contextMenu.Items.Add("-")

$itemExit = $contextMenu.Items.Add("❌ 結束 (Exit)")
$itemExit.add_Click({
    $timer.Stop()
    $tray.Visible = $false
    $tray.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$tray.ContextMenuStrip = $contextMenu

# 左鍵點擊事件
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Show-DashboardCard
    }
})

# 定時器
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $IntervalSeconds * 1000
$timer.add_Tick({ Update-TrayStatus })
$timer.Start()

$global:TrayIcon = $tray

# 首次背景查詢更新
Update-TrayStatus

# 進入 Windows Forms 訊息循環
[System.Windows.Forms.Application]::Run()
