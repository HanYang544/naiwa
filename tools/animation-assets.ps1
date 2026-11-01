<#
素材封装工具：拼接输入联系表、切分生成结果、重建文档预览。
这里只做排版、裁切、等比例缩放和动画编码；角色形象应由图像编辑工具生成。
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Assemble', 'Split', 'Preview')]
  [string]$Mode,
  [string]$Action,
  [string]$SourcePath,
  [string]$OutputPath,
  [string]$AssetsRoot,
  [string]$OutputDirectory = 'E:\Codex\Cache\Temp\naiwa-image-update\staged',
  [ValidateRange(64, 2048)][int]$CellSize = 512,
  [int[]]$RowBounds,
  [int[]]$ColumnBounds,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $AssetsRoot) { $AssetsRoot = Join-Path $projectRoot 'assets' }
$script:gifExpectedDelays = New-Object 'System.Collections.Generic.Dictionary[object,object]'
$daily = @(
  @{ Name = 'walk'; Label = '抱肚行走'; Step = 120; Sequence = @(0,1,2,3,4,5,6,7,8,9,10,11) },
  @{ Name = 'victory'; Label = '举手大笑'; Step = 160; Sequence = @(0,0,0,1,2,3,4,5,6,7,8,8,8,8,8,9,10,11,11,11,11) },
  @{ Name = 'sit'; Label = '坐下啃脚趾'; Step = 200; Sequence = @(0,0,0,0,1,2,3,4,5,6,7,8,9,10,10,10,10,10,10,11,11,11,11) },
  @{ Name = 'laugh'; Label = '捧腹大笑'; Step = 180; Sequence = @(0,0,0,0,1,2,3,4,5,6,7,8,8,8,8,9,10,11,11,11,11,11) },
  @{ Name = 'stretch'; Label = '趴地摇摆吐舌头'; Step = 180; Sequence = @(0,0,0,1,2,3,4,5,6,6,6,6,6,7,8,9,10,11,11,11,11,11,11) }
)
$funny = @(
  @{ Name = 'think'; Label = '认真思考'; Step = 190; Sequence = @(0,0,1,2,3,4,5,6,6,7,7,8,8,9,10,11,11) },
  @{ Name = 'noodle_dance'; Label = '面条乱舞'; Step = 155; Sequence = @(0,1,2,3,3,4,5,6,7,7,8,9,10,11,11) },
  @{ Name = 'belly_drum'; Label = '肚皮打鼓'; Step = 170; Sequence = @(0,0,1,2,3,4,5,6,7,8,8,9,10,11,11) },
  @{ Name = 'pretzel_twist'; Label = '麻花扭身'; Step = 185; Sequence = @(0,0,1,2,3,4,5,5,6,7,8,9,10,11,11) },
  @{ Name = 'freeze'; Label = '突然石化'; Step = 190; Sequence = @(0,0,0,1,2,3,4,4,4,4,5,5,6,6,7,7,8,9,10,11,11) },
  @{ Name = 'fake_faint'; Label = '戏精假摔'; Step = 185; Sequence = @(0,0,1,2,3,4,5,6,7,7,7,8,8,9,10,11,11) },
  @{ Name = 'brain_loading'; Label = '大脑加载中'; Step = 205; Sequence = @(0,0,1,2,3,4,5,6,7,7,8,8,9,10,11,11) },
  @{ Name = 'play_bow'; Label = '屁股朝天偷看'; Step = 175; Sequence = @(0,0,1,2,3,4,5,6,7,8,9,10,11,11) }
)
$actionGroups = @{}
foreach ($item in $daily) { $actionGroups[$item.Name] = 'animation_detailed' }
foreach ($item in $funny) { $actionGroups[$item.Name] = 'funny_detailed' }

function Assert-Output([string]$Path) {
  if ((Test-Path -LiteralPath $Path) -and -not $Force) { throw "目标已存在，请指定新路径或显式使用 -Force：$Path" }
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))) | Out-Null
}

function New-Canvas([int]$Width, [int]$Height, [Drawing.Color]$Background = [Drawing.Color]::Transparent) {
  $bitmap = New-Object Drawing.Bitmap $Width, $Height, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear($Background)
  $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Draw-Fit($Graphics, $Image, [int]$X, [int]$Y, [int]$Width, [int]$Height) {
  $scale = [Math]::Min($Width / [double]$Image.Width, $Height / [double]$Image.Height)
  $drawWidth = [int][Math]::Round($Image.Width * $scale)
  $drawHeight = [int][Math]::Round($Image.Height * $scale)
  $drawX = $X + [int][Math]::Floor(($Width - $drawWidth) / 2)
  $drawY = $Y + [int][Math]::Floor(($Height - $drawHeight) / 2)
  $Graphics.DrawImage($Image, $drawX, $drawY, $drawWidth, $drawHeight)
}

function Get-FramePath([string]$Name, [int]$Index) {
  return Join-Path (Join-Path $AssetsRoot $actionGroups[$Name]) ($Name + '_' + $Index.ToString('00') + '.png')
}

function Save-Canvas($Canvas, [string]$Path) {
  Assert-Output $Path
  $Canvas.Graphics.Dispose()
  $Canvas.Bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
  $Canvas.Bitmap.Dispose()
}

function Draw-Label($Graphics, [string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height, [int]$FontSize = 22) {
  $font = New-Object Drawing.Font 'Microsoft YaHei UI', $FontSize, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
  $brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(80, 49, 14))
  $format = New-Object Drawing.StringFormat
  $format.Alignment = [Drawing.StringAlignment]::Center
  $format.LineAlignment = [Drawing.StringAlignment]::Center
  try { $Graphics.DrawString($Text, $font, $brush, (New-Object Drawing.RectangleF $X,$Y,$Width,$Height), $format) }
  finally { $font.Dispose(); $brush.Dispose(); $format.Dispose() }
}

function Draw-Checker($Graphics, [int]$Width, [int]$Height) {
  $white = New-Object Drawing.SolidBrush ([Drawing.Color]::White)
  $gray = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(237,237,239))
  try {
    $Graphics.FillRectangle($white,0,0,$Width,$Height)
    for($y = 0; $y -lt $Height; $y += 16) {
      for($x = 0; $x -lt $Width; $x += 16) {
        if (([int]($x/16) + [int]($y/16)) % 2 -eq 0) { $Graphics.FillRectangle($gray,$x,$y,16,16) }
      }
    }
  } finally { $white.Dispose(); $gray.Dispose() }
}

function Add-GifFrame($Encoder, $Bitmap, [int]$DelayMs) {
  $delayCentiseconds = [UInt16][Math]::Max(1, [Math]::Round($DelayMs / 10.0))
  if (-not $script:gifExpectedDelays.ContainsKey($Encoder)) {
    $script:gifExpectedDelays[$Encoder] = New-Object 'System.Collections.Generic.List[UInt16]'
  }
  $stream = New-Object IO.MemoryStream
  try {
    $Bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
    $stream.Position = 0
    $source = [Windows.Media.Imaging.BitmapFrame]::Create($stream, [Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    $metadata = New-Object Windows.Media.Imaging.BitmapMetadata 'gif'
    $metadata.SetQuery('/grctlext/Delay', $delayCentiseconds)
    $metadata.SetQuery('/grctlext/Disposal', [byte]2)
    $frame = [Windows.Media.Imaging.BitmapFrame]::Create($source, $null, $metadata, $null)
    $Encoder.Frames.Add($frame)
    $script:gifExpectedDelays[$Encoder].Add($delayCentiseconds)
  } finally { $stream.Dispose() }
}

function Set-GifContainerDelays([byte[]]$Bytes, [UInt16[]]$Delays) {
  # WPF 可接受帧 metadata 却把 Delay 编码成0；直接修正GIF容器的GCE字段。
  # 解析块结构而不搜索字节模式，避免把LZW压缩图像中的相似字节当作扩展块。
  $position = 13
  if (($Bytes[10] -band 128) -ne 0) { $position += 3 * [int][Math]::Pow(2, ($Bytes[10] -band 7) + 1) }
  $frameIndex = 0
  $pendingDelayOffset = -1
  $insertions = @()
  while ($position -lt $Bytes.Length) {
    $marker = $Bytes[$position]
    if ($marker -eq 0x3b) { break }
    if ($marker -eq 0x21) {
      if (($position+2) -ge $Bytes.Length) { throw 'GIF扩展块截断。' }
      if ($Bytes[$position+1] -eq 0xf9) {
        if ($Bytes[$position+2] -ne 4) { throw 'GIF图形控制扩展大小异常。' }
        $pendingDelayOffset = $position+4
      }
      $position += 2
      do {
        if ($position -ge $Bytes.Length) { throw 'GIF扩展子块截断。' }
        $blockLength = [int]$Bytes[$position]
        $position += 1+$blockLength
        if ($position -gt $Bytes.Length) { throw 'GIF扩展子块越界。' }
      } while ($blockLength -ne 0)
      continue
    }
    if ($marker -eq 0x2c) {
      if ($frameIndex -ge $Delays.Count) { throw 'GIF图像帧数超过预期延时数量。' }
      $delay = $Delays[$frameIndex]
      if ($delay -eq 0) { throw 'GIF预期延时不得为0。' }
      if ($pendingDelayOffset -ge 0) {
        $Bytes[$pendingDelayOffset] = [byte]($delay -band 255)
        $Bytes[$pendingDelayOffset+1] = [byte](($delay -shr 8) -band 255)
      } else {
        [byte[]]$gce = @(0x21,0xf9,4,2,($delay -band 255),(($delay -shr 8) -band 255),0,0)
        $insertions += @{ Offset=$position; Bytes=$gce }
      }
      if (($position+9) -ge $Bytes.Length) { throw 'GIF图像描述符截断。' }
      $packed = $Bytes[$position+9]
      $position += 10
      if (($packed -band 128) -ne 0) { $position += 3 * [int][Math]::Pow(2, ($packed -band 7) + 1) }
      $position++ # LZW最小码长，压缩图像子块保持原字节。
      do {
        if ($position -ge $Bytes.Length) { throw 'GIF图像子块截断。' }
        $blockLength = [int]$Bytes[$position]
        $position += 1+$blockLength
        if ($position -gt $Bytes.Length) { throw 'GIF图像子块越界。' }
      } while ($blockLength -ne 0)
      $frameIndex++
      $pendingDelayOffset = -1
      continue
    }
    throw "GIF含未知块类型：$marker，位置$position。"
  }
  if ($frameIndex -ne $Delays.Count) { throw "GIF帧数$frameIndex 与预期延时数量$($Delays.Count)不一致。" }
  if (-not $insertions.Count) { return ,$Bytes }
  $result = New-Object IO.MemoryStream
  try {
    $copyPosition = 0
    foreach ($insertion in $insertions) {
      $result.Write($Bytes,$copyPosition,$insertion.Offset-$copyPosition)
      $result.Write($insertion.Bytes,0,$insertion.Bytes.Length)
      $copyPosition = $insertion.Offset
    }
    $result.Write($Bytes,$copyPosition,$Bytes.Length-$copyPosition)
    return ,$result.ToArray()
  } finally { $result.Dispose() }
}

function Save-Gif($Encoder, [string]$Path) {
  Assert-Output $Path
  if (-not $script:gifExpectedDelays.ContainsKey($Encoder)) { throw 'GIF没有记录预期帧延时。' }
  [UInt16[]]$expectedDelays = $script:gifExpectedDelays[$Encoder].ToArray()
  if ($expectedDelays.Count -ne $Encoder.Frames.Count) { throw 'GIF帧数与记录延时数量不一致。' }
  $stream = New-Object IO.MemoryStream
  try {
    $Encoder.Save($stream)
    $bytes = $stream.ToArray()
  } finally { $stream.Dispose() }
  $bytes = Set-GifContainerDelays $bytes $expectedDelays
  # GIF 容器加入无限循环扩展，不改变帧像素。
  $offset = 13
  if (($bytes[10] -band 128) -ne 0) { $offset += 3 * [int][Math]::Pow(2, ($bytes[10] -band 7) + 1) }
  [byte[]]$loopExtension = @(0x21,0xff,0x0b,0x4e,0x45,0x54,0x53,0x43,0x41,0x50,0x45,0x32,0x2e,0x30,0x03,0x01,0,0,0)
  $file = [IO.File]::Create($Path)
  try {
    $file.Write($bytes, 0, $offset)
    $file.Write($loopExtension, 0, $loopExtension.Length)
    $file.Write($bytes, $offset, $bytes.Length - $offset)
  } finally { $file.Dispose() }
  $checkStream = [IO.File]::OpenRead($Path)
  try {
    $decoder = New-Object Windows.Media.Imaging.GifBitmapDecoder $checkStream, ([Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat), ([Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    if ($decoder.Frames.Count -ne $expectedDelays.Count) { throw 'GIF回读帧数不符。' }
    $actualDelays = @($decoder.Frames | ForEach-Object { [UInt16]$_.Metadata.GetQuery('/grctlext/Delay') })
    for ($index = 0; $index -lt $expectedDelays.Count; $index++) {
      if ($actualDelays[$index] -ne $expectedDelays[$index] -or $actualDelays[$index] -eq 0) { throw "GIF第$index 帧延时回读不符。" }
    }
    $totalMilliseconds = [int](($actualDelays | Measure-Object -Sum).Sum*10)
    Write-Output "GIF逐帧延时验证通过：$($expectedDelays.Count)帧，总时长${totalMilliseconds}ms，前12帧延时(cs)=$(@($actualDelays|Select-Object -First 12)-join ',')"
  } finally { $checkStream.Dispose() }
}

if ($Mode -in @('Assemble', 'Split')) {
  if (-not $actionGroups.ContainsKey($Action)) { throw '请指定有效动作名称，例如 freeze、think、victory。' }
}

if ($Mode -eq 'Assemble') {
  if (-not $OutputPath) { $OutputPath = "E:\Codex\Cache\Temp\naiwa-image-update\inputs\$Action.png" }
  $canvas = New-Canvas (4 * $CellSize) (3 * $CellSize)
  for ($index = 0; $index -lt 12; $index++) {
    $image = [Drawing.Image]::FromFile((Get-FramePath $Action $index))
    try { Draw-Fit $canvas.Graphics $image (($index % 4) * $CellSize) ([int][Math]::Floor($index / 4) * $CellSize) $CellSize $CellSize }
    finally { $image.Dispose() }
  }
  Save-Canvas $canvas $OutputPath
  Write-Output $OutputPath
  return
}

if ($Mode -eq 'Split') {
  if (-not $SourcePath) { throw 'Split 模式需要 -SourcePath 指定生成的 4×3 素材表。' }
  $source = [Drawing.Bitmap]::FromFile($SourcePath)
  $original = [Drawing.Image]::FromFile((Get-FramePath $Action 0))
  $frameWidth = $original.Width
  $frameHeight = $original.Height
  $original.Dispose()
  try {
    if (-not $ColumnBounds) { $ColumnBounds = @(0..4 | ForEach-Object { [int][Math]::Round($_ * $source.Width / 4.0) }) }
    if (-not $RowBounds) { $RowBounds = @(0..3 | ForEach-Object { [int][Math]::Round($_ * $source.Height / 3.0) }) }
    foreach ($spec in @(@{ Bounds = $ColumnBounds; Count = 5; Extent = $source.Width; Label = 'ColumnBounds' }, @{ Bounds = $RowBounds; Count = 4; Extent = $source.Height; Label = 'RowBounds' })) {
      if ($spec.Bounds.Count -ne $spec.Count -or $spec.Bounds[0] -ne 0 -or $spec.Bounds[-1] -ne $spec.Extent) { throw "$($spec.Label) 必须从0到图片边界，列5个值/行4个值。" }
      for ($boundIndex = 1; $boundIndex -lt $spec.Bounds.Count; $boundIndex++) {
        if ($spec.Bounds[$boundIndex] -le $spec.Bounds[$boundIndex-1]) { throw "$($spec.Label) 必须严格递增。" }
      }
    }
    $maximumCellWidth = 0
    $maximumCellHeight = 0
    for ($boundIndex = 1; $boundIndex -lt 5; $boundIndex++) { $maximumCellWidth = [Math]::Max($maximumCellWidth, $ColumnBounds[$boundIndex] - $ColumnBounds[$boundIndex-1]) }
    for ($boundIndex = 1; $boundIndex -lt 4; $boundIndex++) { $maximumCellHeight = [Math]::Max($maximumCellHeight, $RowBounds[$boundIndex] - $RowBounds[$boundIndex-1]) }
    $uniformScale = [Math]::Min($frameWidth / [double]$maximumCellWidth, $frameHeight / [double]$maximumCellHeight)
    $frameDirectory = Join-Path $OutputDirectory $actionGroups[$Action]
    for ($index = 0; $index -lt 12; $index++) {
      $column = $index % 4
      $row = [int][Math]::Floor($index / 4)
      $left = $ColumnBounds[$column]
      $right = $ColumnBounds[$column+1]
      $top = $RowBounds[$row]
      $bottom = $RowBounds[$row+1]
      $cell = $source.Clone((New-Object Drawing.Rectangle $left,$top,($right-$left),($bottom-$top)), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
      try {
        $canvas = New-Canvas $frameWidth $frameHeight
        $drawWidth = [int][Math]::Round($cell.Width * $uniformScale)
        $drawHeight = [int][Math]::Round($cell.Height * $uniformScale)
        $drawX = [int][Math]::Floor(($frameWidth - $drawWidth) / 2)
        $drawY = [int][Math]::Floor(($frameHeight - $drawHeight) / 2)
        $canvas.Graphics.DrawImage($cell, $drawX, $drawY, $drawWidth, $drawHeight)
        Save-Canvas $canvas (Join-Path $frameDirectory ($Action + '_' + $index.ToString('00') + '.png'))
      } finally { $cell.Dispose() }
    }
    Write-Output "已封装 $Action：12 帧，${frameWidth}×${frameHeight}，$frameDirectory"
  } finally { $source.Dispose() }
  return
}

# Preview 输出可指向临时目录，完成验收后再由维护者替换文档预览。
Add-Type -AssemblyName PresentationCore, WindowsBase
$cream = [Drawing.Color]::FromArgb(255,248,235)
$dailyOverview = New-Canvas 1948 998 $cream
for($row = 0; $row -lt $daily.Count; $row++) {
  $item = $daily[$row]
  Draw-Label $dailyOverview.Graphics $item.Label 0 ($row*198) 216 198 23
  for($index = 0; $index -lt 12; $index++) {
    $image = [Drawing.Image]::FromFile((Get-FramePath $item.Name $index))
    try { Draw-Fit $dailyOverview.Graphics $image (220+$index*144) (10+$row*198) 140 180 }
    finally { $image.Dispose() }
  }
}
Save-Canvas $dailyOverview (Join-Path $OutputDirectory '逐帧动作总览.png')

$funnyOverview = New-Canvas 1344 896
Draw-Checker $funnyOverview.Graphics 1344 896
for($row = 0; $row -lt $funny.Count; $row++) {
  for($index = 0; $index -lt 12; $index++) {
    $image = [Drawing.Image]::FromFile((Get-FramePath $funny[$row].Name $index))
    try { Draw-Fit $funnyOverview.Graphics $image ($index*112) ($row*112) 112 112 }
    finally { $image.Dispose() }
  }
}
Save-Canvas $funnyOverview (Join-Path $OutputDirectory '搞怪逐帧动作总览.png')

$setting = New-Canvas 1536 1024 $cream
for($index = 0; $index -lt $funny.Count; $index++) {
  $x = ($index % 4)*384
  $y = [int][Math]::Floor($index/4)*512
  $representativeIndex = @(0,3,3,4,0,1,3,0)[$index]
  $image = [Drawing.Image]::FromFile((Get-FramePath $funny[$index].Name $representativeIndex))
  try { Draw-Fit $setting.Graphics $image ($x+12) ($y+18) 360 416 }
  finally { $image.Dispose() }
  Draw-Label $setting.Graphics $funny[$index].Label $x ($y+436) 384 60 26
}
Save-Canvas $setting (Join-Path $OutputDirectory '抽象搞怪动作设定.png')

$dailyEncoder = New-Object Windows.Media.Imaging.GifBitmapEncoder
foreach($item in $daily) {
  for($sequenceIndex = 0; $sequenceIndex -lt $item.Sequence.Count;) {
    $frameIndex = $item.Sequence[$sequenceIndex]
    $repeats = 1
    while(($sequenceIndex+$repeats) -lt $item.Sequence.Count -and $item.Sequence[$sequenceIndex+$repeats] -eq $frameIndex) { $repeats++ }
    $canvas = New-Canvas 520 520 $cream
    Draw-Label $canvas.Graphics $item.Label 0 10 520 50 32
    $image = [Drawing.Image]::FromFile((Get-FramePath $item.Name $frameIndex))
    try { Draw-Fit $canvas.Graphics $image 30 60 460 440 }
    finally { $image.Dispose() }
    $canvas.Graphics.Dispose()
    Add-GifFrame $dailyEncoder $canvas.Bitmap ($repeats*$item.Step)
    $canvas.Bitmap.Dispose()
    $sequenceIndex += $repeats
  }
}
Save-Gif $dailyEncoder (Join-Path $OutputDirectory '逐帧动画预览.gif')

# 每100ms采样八组各自的真实动作序列，横向比较时仍保留各自节奏。
$funnyEncoder = New-Object Windows.Media.Imaging.GifBitmapEncoder
for($elapsedMs = 0; $elapsedMs -lt 12000; $elapsedMs += 100) {
  $canvas = New-Canvas 760 420 $cream
  for($index = 0; $index -lt $funny.Count; $index++) {
    $item = $funny[$index]
    $sequenceIndex = [int][Math]::Floor($elapsedMs / $item.Step) % $item.Sequence.Count
    $frameIndex = $item.Sequence[$sequenceIndex]
    $x = ($index % 4)*190
    $y = [int][Math]::Floor($index/4)*210
    $image = [Drawing.Image]::FromFile((Get-FramePath $item.Name $frameIndex))
    try { Draw-Fit $canvas.Graphics $image ($x+5) $y 180 182 }
    finally { $image.Dispose() }
    Draw-Label $canvas.Graphics $item.Label $x ($y+183) 190 25 17
  }
  $canvas.Graphics.Dispose()
  Add-GifFrame $funnyEncoder $canvas.Bitmap 100
  $canvas.Bitmap.Dispose()
}
Save-Gif $funnyEncoder (Join-Path $OutputDirectory '搞怪逐帧动画预览.gif')
Write-Output "已重建五份预览：$OutputDirectory"
