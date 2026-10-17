[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$assetsDir = Join-Path $repoRoot "assets"
$publicDir = Join-Path $repoRoot "public"

function Draw-CodexResetIcon {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    [float]$scale = [float]$Size / 512.0

    # 1. 繪製圓角矩形背景 (深色漸層)
    [float]$rectX = 24.0 * $scale
    [float]$rectY = 24.0 * $scale
    [float]$rectW = 464.0 * $scale
    [float]$rectH = 464.0 * $scale
    [float]$radius = 108.0 * $scale

    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    [float]$diameter = $radius * 2.0
    $gp.AddArc($rectX, $rectY, $diameter, $diameter, 180.0, 90.0)
    $gp.AddArc(($rectX + $rectW - $diameter), $rectY, $diameter, $diameter, 270.0, 90.0)
    $gp.AddArc(($rectX + $rectW - $diameter), ($rectY + $rectH - $diameter), $diameter, $diameter, 0.0, 90.0)
    $gp.AddArc($rectX, ($rectY + $rectH - $diameter), $diameter, $diameter, 90.0, 90.0)
    $gp.CloseFigure()

    $rectF = New-Object System.Drawing.RectangleF($rectX, $rectY, $rectW, $rectH)
    $c1 = [System.Drawing.Color]::FromArgb(255, 15, 23, 42)
    $c2 = [System.Drawing.Color]::FromArgb(255, 2, 6, 23)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF, $c1, $c2, 45.0)
    $g.FillPath($bgBrush, $gp)
    $bgBrush.Dispose()

    # 邊框
    [float]$penWidth = [Math]::Max(1.0, [float](7.0 * $scale))
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 16, 185, 129), $penWidth)
    $g.DrawPath($borderPen, $gp)
    $borderPen.Dispose()
    $gp.Dispose()

    # 2. 雙向圓弧箭頭 (重置/循環)
    [float]$center = 256.0 * $scale
    [float]$arcR = 126.0 * $scale
    [float]$arcPenW = [Math]::Max(2.0, [float](26.0 * $scale))
    
    # 頂部/右側弧線 (Emerald)
    [float]$arcX = $center - $arcR
    [float]$arcY = $center - $arcR
    [float]$arcDiam = $arcR * 2.0
    $arcRect = New-Object System.Drawing.RectangleF($arcX, $arcY, $arcDiam, $arcDiam)

    $emeraldPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 16, 185, 129), $arcPenW)
    $emeraldPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $emeraldPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($emeraldPen, $arcRect, 220.0, 100.0)
    $emeraldPen.Dispose()

    # 上箭頭
    $topArrow = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF([float](356.0 * $scale), [float](160.0 * $scale))),
        (New-Object System.Drawing.PointF([float](400.0 * $scale), [float](216.0 * $scale))),
        (New-Object System.Drawing.PointF([float](336.0 * $scale), [float](226.0 * $scale)))
    )
    $emBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 16, 185, 129))
    $g.FillPolygon($emBrush, $topArrow)
    $emBrush.Dispose()

    # 底部/左側弧線 (Cyan)
    $cyanPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 6, 182, 212), $arcPenW)
    $cyanPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $cyanPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($cyanPen, $arcRect, 40.0, 100.0)
    $cyanPen.Dispose()

    # 下箭頭
    $bottomArrow = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF([float](156.0 * $scale), [float](352.0 * $scale))),
        (New-Object System.Drawing.PointF([float](112.0 * $scale), [float](296.0 * $scale))),
        (New-Object System.Drawing.PointF([float](176.0 * $scale), [float](286.0 * $scale)))
    )
    $cyanBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 6, 182, 212))
    $g.FillPolygon($cyanBrush, $bottomArrow)
    $cyanBrush.Dispose()

    # 3. 中心終端符號 >_
    [float]$promptPenW = [Math]::Max(1.5, [float](16.0 * $scale))
    $promptPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 56, 189, 248), $promptPenW)
    $promptPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $promptPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $promptPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $promptPts = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF([float](204.0 * $scale), [float](228.0 * $scale))),
        (New-Object System.Drawing.PointF([float](242.0 * $scale), [float](256.0 * $scale))),
        (New-Object System.Drawing.PointF([float](204.0 * $scale), [float](284.0 * $scale)))
    )
    $g.DrawLines($promptPen, $promptPts)
    $promptPen.Dispose()

    # 游標 _
    $cursorPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 16, 185, 129), $promptPenW)
    $cursorPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $cursorPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($cursorPen, [float](262.0 * $scale), [float](284.0 * $scale), [float](308.0 * $scale), [float](284.0 * $scale))
    $cursorPen.Dispose()

    # 4. 底部用量指示標記
    if ($Size -ge 32) {
        [float]$bH = [Math]::Max(2.0, [float](12.0 * $scale))
        [float]$bW = [Math]::Max(4.0, [float](34.0 * $scale))
        [float]$bY = 390.0 * $scale

        $b1 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 16, 185, 129))
        $b2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
        $b3 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 129, 140, 248))

        $g.FillRectangle($b1, [float](190.0 * $scale), $bY, $bW, $bH)
        $g.FillRectangle($b2, [float](239.0 * $scale), $bY, $bW, $bH)
        $g.FillRectangle($b3, [float](288.0 * $scale), $bY, $bW, $bH)

        $b1.Dispose(); $b2.Dispose(); $b3.Dispose()
    }

    $g.Dispose()
    return $bmp
}

# 產出 PNG 與多尺寸 ICO
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$pngList = @()

foreach ($sz in $sizes) {
    $bmp = Draw-CodexResetIcon -Size $sz
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngList += [PSCustomObject]@{
        Size = $sz
        Bytes = $ms.ToArray()
    }
    $bmp.Dispose()
    $ms.Dispose()
}

# 儲存高解析度 512x512 PNG
$hiResBmp = Draw-CodexResetIcon -Size 512
$hiResPngPath = Join-Path $assetsDir "icon.png"
$hiResBmp.Save($hiResPngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$hiResBmp.Save((Join-Path $publicDir "icon.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$hiResBmp.Dispose()
Write-Host "Created: $hiResPngPath (512x512 PNG)"

# 打包多尺寸 ICO 檔案 (使用標準 PNG 內嵌規格)
$icoPath = Join-Path $assetsDir "icon.ico"
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fs)

# ICONHEADER (6 bytes)
$bw.Write([uint16]0) # Reserved
$bw.Write([uint16]1) # Type: 1 = ICO
$bw.Write([uint16]$sizes.Count) # Number of images

[int]$headerSize = 6 + (16 * $sizes.Count)
[int]$currentOffset = $headerSize

# ICONDIRENTRY (16 bytes each)
foreach ($entry in $pngList) {
    [byte]$szByte = if ($entry.Size -eq 256) { [byte]0 } else { [byte]$entry.Size }
    $bw.Write($szByte) # Width
    $bw.Write($szByte) # Height
    $bw.Write([byte]0) # Color count
    $bw.Write([byte]0) # Reserved
    $bw.Write([uint16]1) # Planes
    $bw.Write([uint16]32) # Bit count
    $bw.Write([uint32]$entry.Bytes.Length) # Size of image data
    $bw.Write([uint32]$currentOffset) # Offset of image data
    $currentOffset += $entry.Bytes.Length
}

# Image Data
foreach ($entry in $pngList) {
    $bw.Write($entry.Bytes)
}

$bw.Flush()
$bw.Close()
$fs.Close()

# 複製到 public 作為 favicon
Copy-Item -LiteralPath $icoPath -Destination (Join-Path $publicDir "favicon.ico") -Force

Write-Host "Created: $icoPath (multi-size ICO: 16, 24, 32, 48, 64, 128, 256)"
