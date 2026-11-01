<#
只读检查正式动画帧及来源素材表。不会写入或修改任何图像文件。
报告包括可解码性、原始尺寸、透明通道、12帧完整性和可见像素边界。
#>
[CmdletBinding()]
param(
  [string]$AssetsRoot = 'E:\Codex\Cache\Temp\naiwa-image-update\candidate-assets',
  [string]$ReferenceAssetsRoot = 'E:\Codex\Artifacts\results\naiwa-image-update-2026-11-01\backup\assets',
  [string]$SourceSheetRoot = 'E:\Codex\Workspaces\naiwa\assets\source-sheets',
  [string[]]$UpdatedActions = @('freeze','think','brain_loading','victory','sit','laugh'),
  [string]$ReportDirectory = 'E:\Codex\Artifacts\results\naiwa-image-update-2026-11-01',
  [string]$ReportName = 'qa-candidate-initial',
  [ValidateRange(1,255)][int]$AlphaThreshold = 16
)
$ErrorActionPreference = 'Stop'
$env:TEMP = 'E:\Codex\Cache\Temp\naiwa-image-update'
$env:TMP = $env:TEMP
[IO.Directory]::CreateDirectory($env:TEMP) | Out-Null
if (-not [IO.Path]::GetFullPath($ReportDirectory).StartsWith('E:\Codex\',[StringComparison]::OrdinalIgnoreCase)) { throw '检查结果必须保存在 E:\Codex 内。' }
if ($ReportName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { throw 'ReportName 必须为有效文件名。' }
$reportPath = Join-Path $ReportDirectory ($ReportName + '.json')
if (Test-Path -LiteralPath $reportPath) { throw "报告已存在，请为新检查使用其他 ReportName：$reportPath" }
Add-Type -AssemblyName System.Drawing
if (-not ('NaiwaImageAudit' -as [type])) {
  $code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public class NaiwaPixelStats {
  public int Width, Height, MinAlpha=255, MaxAlpha=0;
  public long TransparentPixels, PartialAlphaPixels, OpaquePixels, VisiblePixels;
  public int Left=-1, Top=-1, Right=-1, Bottom=-1;
  public bool TouchesBorder;
  public int[] RowVisiblePixels, ColumnVisiblePixels;
}
public static class NaiwaImageAudit {
  public static NaiwaPixelStats Measure(string path, int threshold, bool projection) {
    using (Bitmap input = new Bitmap(path)) {
      return MeasureBitmap(input, threshold, projection);
    }
  }
  private static NaiwaPixelStats MeasureBitmap(Bitmap input, int threshold, bool projection) {
    var stats = new NaiwaPixelStats { Width=input.Width, Height=input.Height };
    if (projection) {
      stats.RowVisiblePixels=new int[input.Height];
      stats.ColumnVisiblePixels=new int[input.Width];
    }
    using (Bitmap normalized = new Bitmap(input.Width,input.Height,PixelFormat.Format32bppArgb)) {
      using (Graphics graphics = Graphics.FromImage(normalized)) {
        graphics.CompositingMode=CompositingMode.SourceCopy;
        graphics.DrawImageUnscaled(input,0,0);
      }
      BitmapData data=normalized.LockBits(new Rectangle(0,0,input.Width,input.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      try {
        byte[] row=new byte[input.Width*4];
        int left=input.Width,top=input.Height,right=-1,bottom=-1;
        for(int y=0;y<input.Height;y++) {
          Marshal.Copy(IntPtr.Add(data.Scan0,y*data.Stride),row,0,row.Length);
          for(int x=0;x<input.Width;x++) {
            int alpha=row[x*4+3];
            stats.MinAlpha=Math.Min(stats.MinAlpha,alpha);
            stats.MaxAlpha=Math.Max(stats.MaxAlpha,alpha);
            if(alpha==0) stats.TransparentPixels++;
            else if(alpha==255) stats.OpaquePixels++;
            else stats.PartialAlphaPixels++;
            if(alpha>=threshold) {
              stats.VisiblePixels++;
              left=Math.Min(left,x); top=Math.Min(top,y); right=Math.Max(right,x); bottom=Math.Max(bottom,y);
              if(projection) { stats.RowVisiblePixels[y]++; stats.ColumnVisiblePixels[x]++; }
            }
          }
        }
        if(right>=0) {
          stats.Left=left; stats.Top=top; stats.Right=right; stats.Bottom=bottom;
          stats.TouchesBorder=left==0||top==0||right==input.Width-1||bottom==input.Height-1;
        }
      } finally { normalized.UnlockBits(data); }
    }
    return stats;
  }
}
'@
  if ($PSEdition -eq 'Core') {
    $references = @((Get-ChildItem -LiteralPath (Join-Path $PSHOME 'ref') -Filter '*.dll').FullName) + [Drawing.Bitmap].Assembly.Location
    $references += @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -like 'System.Private.Windows.*' } | ForEach-Object { $_.Location })
    Add-Type -TypeDefinition $code -ReferencedAssemblies $references
  } else { Add-Type -TypeDefinition $code -ReferencedAssemblies 'System.Drawing' }
}

function Get-GapBounds([int[]]$Projection, [int]$Parts) {
  $gaps = @()
  $start = -1
  for($index = 0; $index -le $Projection.Count; $index++) {
    $empty = $index -lt $Projection.Count -and $Projection[$index] -eq 0
    if($empty -and $start -lt 0) { $start = $index }
    if(-not $empty -and $start -ge 0) {
      $gaps += [pscustomobject]@{ Start=$start; EndExclusive=$index; Width=($index-$start); Center=[int][Math]::Floor(($start+$index)/2) }
      $start = -1
    }
  }
  $suggested = @(0)
  $reliable = $true
  for($part = 1; $part -lt $Parts; $part++) {
    $target = $Projection.Count*$part/[double]$Parts
    $nearby = @($gaps | Where-Object { [Math]::Abs($_.Center-$target) -lt $Projection.Count/($Parts*2.2) } | Sort-Object @{Expression={ [Math]::Abs($_.Center-$target) }})
    if($nearby.Count) { $suggested += $nearby[0].Center }
    else { $suggested += [int][Math]::Round($target); $reliable = $false }
  }
  $suggested += $Projection.Count
  return [pscustomobject]@{ Bounds=$suggested; EveryInternalBoundaryHasTransparentGap=$reliable; TransparentGaps=$gaps }
}

$frames = @()
$groups = @()
$issues = @()
foreach($groupName in @('animation_detailed','funny_detailed')) {
  $referenceDirectory = Join-Path $ReferenceAssetsRoot $groupName
  $actions = @((Get-ChildItem -LiteralPath $referenceDirectory -File -Filter '*_00.png').BaseName | ForEach-Object { $_ -replace '_00$','' })
  foreach($action in $actions) {
    $missing = @()
    for($index = 0; $index -lt 12; $index++) {
      $filename = $action + '_' + $index.ToString('00') + '.png'
      $relativePath = Join-Path $groupName $filename
      $path = Join-Path $AssetsRoot $relativePath
      if(-not (Test-Path -LiteralPath $path)) { $missing += $filename; $issues += "缺帧：$relativePath"; continue }
      try {
        $stats = [NaiwaImageAudit]::Measure($path,$AlphaThreshold,$false)
        $reference = [Drawing.Image]::FromFile((Join-Path $ReferenceAssetsRoot $relativePath))
        try { $sameSize = $stats.Width -eq $reference.Width -and $stats.Height -eq $reference.Height }
        finally { $reference.Dispose() }
        $isUpdated = $UpdatedActions -contains $action
        $record = [pscustomobject]@{
          RelativePath=$relativePath; Decodable=$true; Width=$stats.Width; Height=$stats.Height; SameDimensionsAsOriginal=$sameSize
          TransparentPixels=$stats.TransparentPixels; PartialAlphaPixels=$stats.PartialAlphaPixels; VisiblePixels=$stats.VisiblePixels
          HasTransparentArea=($stats.TransparentPixels -gt 0); IsNonEmpty=($stats.VisiblePixels -gt 0); UpdatedAction=$isUpdated
          BBox=@{Left=$stats.Left;Top=$stats.Top;Right=$stats.Right;Bottom=$stats.Bottom}
          Margins=@{Left=$stats.Left;Top=$stats.Top;Right=($stats.Width-1-$stats.Right);Bottom=($stats.Height-1-$stats.Bottom)}
          TouchesBorder=$stats.TouchesBorder
        }
        $frames += $record
        if(-not $sameSize) { $issues += "尺寸变化：$relativePath" }
        if(-not $record.HasTransparentArea) { $issues += "没有透明区域：$relativePath" }
        if(-not $record.IsNonEmpty) { $issues += "空白帧：$relativePath" }
        if($isUpdated -and $stats.TouchesBorder) { $issues += "新生成帧可见像素触边：$relativePath" }
      } catch { $frames += [pscustomobject]@{RelativePath=$relativePath;Decodable=$false;Error=$_.Exception.Message}; $issues += "无法解码：$relativePath" }
    }
    $actualFiles = @(Get-ChildItem -LiteralPath (Join-Path $AssetsRoot $groupName) -File -Filter ($action+'_*.png'))
    $groups += [pscustomobject]@{Group=$groupName;Action=$action;ExpectedFrames=12;ActualFrames=$actualFiles.Count;Missing=$missing;Complete=($missing.Count -eq 0 -and $actualFiles.Count -eq 12)}
    if($actualFiles.Count -ne 12) { $issues += "帧数异常：$groupName/$action（$($actualFiles.Count)）" }
  }
}
$sheets = @()
if(Test-Path -LiteralPath $SourceSheetRoot) {
  foreach($file in Get-ChildItem -LiteralPath $SourceSheetRoot -File -Filter '*.png') {
    try {
      $stats = [NaiwaImageAudit]::Measure($file.FullName,$AlphaThreshold,$true)
      $rowSuggestion = Get-GapBounds $stats.RowVisiblePixels 3
      $columnSuggestion = Get-GapBounds $stats.ColumnVisiblePixels 4
      $equalRowCrossings = @(1..2 | ForEach-Object {
        $boundary = [int][Math]::Round($_*$stats.Height/3.0)
        [pscustomobject]@{ Position=$boundary; VisiblePixels=$stats.RowVisiblePixels[$boundary] }
      })
      $equalColumnCrossings = @(1..3 | ForEach-Object {
        $boundary = [int][Math]::Round($_*$stats.Width/4.0)
        [pscustomobject]@{ Position=$boundary; VisiblePixels=$stats.ColumnVisiblePixels[$boundary] }
      })
      $sheets += [pscustomobject]@{
        File=$file.Name;Decodable=$true;Width=$stats.Width;Height=$stats.Height;HasTransparentArea=($stats.TransparentPixels -gt 0)
        SuggestedRowBounds=$rowSuggestion.Bounds;RowBoundsHaveTransparentGaps=$rowSuggestion.EveryInternalBoundaryHasTransparentGap
        SuggestedColumnBounds=$columnSuggestion.Bounds;ColumnBoundsHaveTransparentGaps=$columnSuggestion.EveryInternalBoundaryHasTransparentGap
        TransparentRowGaps=$rowSuggestion.TransparentGaps;TransparentColumnGaps=$columnSuggestion.TransparentGaps
        EqualGridRowBoundaries=$equalRowCrossings;EqualGridColumnBoundaries=$equalColumnCrossings
      }
    } catch { $sheets += [pscustomobject]@{File=$file.Name;Decodable=$false;Error=$_.Exception.Message} }
  }
}
$result = [pscustomobject]@{
  CheckedAt=[DateTimeOffset]::Now.ToString('o');AssetsRoot=$AssetsRoot;ReferenceAssetsRoot=$ReferenceAssetsRoot;AlphaThreshold=$AlphaThreshold
  Summary=[pscustomobject]@{
    ExpectedFrames=156;CheckedFrames=$frames.Count;DecodableFrames=@($frames|Where-Object{$_.Decodable}).Count
    CompleteGroups=@($groups|Where-Object{$_.Complete}).Count;UpdatedFrames=@($frames|Where-Object{$_.UpdatedAction}).Count
    UpdatedBorderTouches=@($frames|Where-Object{$_.UpdatedAction -and $_.TouchesBorder}).Count;IssueCount=$issues.Count;Passed=($issues.Count -eq 0 -and $frames.Count -eq 156)
  }
  Issues=$issues;Groups=$groups;Frames=$frames;SourceSheets=$sheets
}
[IO.Directory]::CreateDirectory($ReportDirectory) | Out-Null
$json = $result | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($reportPath,$json,(New-Object Text.UTF8Encoding $true))
$result.Summary | ConvertTo-Json -Compress
Write-Output "报告：$reportPath"
if($issues.Count) { $issues | ForEach-Object { Write-Output $_ } }
