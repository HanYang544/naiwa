<#
Packaging only: split one reference-rebuild sprite sheet using independently
measured transparent column gaps in each row. No character pixels are edited.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][ValidateSet('fake_faint','play_bow','stretch')][string]$Action,
  [Parameter(Mandatory=$true)][string]$SourcePath,
  [Parameter(Mandatory=$true)][string]$ReferenceAssetsRoot,
  [Parameter(Mandatory=$true)][string]$OutputDirectory,
  [Parameter(Mandatory=$true)][int[]]$RowBounds,
  [Parameter(Mandatory=$true)][string]$RecordPath,
  [ValidateRange(1,255)][int]$AlphaThreshold=16,
  [switch]$Force
)
$ErrorActionPreference='Stop'
$env:TEMP='E:\Codex\Cache\Temp\naiwa-reference-rebuild'
$env:TMP=$env:TEMP
[IO.Directory]::CreateDirectory($env:TEMP) | Out-Null
$taskOutputPrefix=[IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')+'\'
if (-not $taskOutputPrefix.StartsWith('E:\Codex\Cache\Temp\naiwa-reference-rebuild\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Output must stay in this task staging directory.' }
if (-not [IO.Path]::GetFullPath($RecordPath).StartsWith('E:\Codex\Artifacts\results\naiwa-reference-rebuild-2026-11-01\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Record path is outside this task report directory.' }
if ((Test-Path -LiteralPath $RecordPath) -and -not $Force) { throw 'Record already exists.' }
Add-Type -AssemblyName System.Drawing
if (-not ('NaiwaRowProjection' -as [type])) {
  $taskCode=@'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public class NaiwaRowProjectionResult {
  public int Width, Height;
  public int[][] Columns;
}
public static class NaiwaRowProjection {
  public static NaiwaRowProjectionResult Measure(string path, int[] bounds, int threshold) {
    using (Bitmap original=new Bitmap(path)) {
      if(bounds.Length!=4||bounds[0]!=0||bounds[3]!=original.Height) throw new Exception("Invalid row bounds.");
      for(int i=1;i<bounds.Length;i++) if(bounds[i]<=bounds[i-1]) throw new Exception("Row bounds must increase.");
      var result=new NaiwaRowProjectionResult { Width=original.Width, Height=original.Height, Columns=new int[3][] };
      for(int i=0;i<3;i++) result.Columns[i]=new int[original.Width];
      using(Bitmap image=new Bitmap(original.Width,original.Height,PixelFormat.Format32bppArgb)) {
        using(Graphics g=Graphics.FromImage(image)) { g.CompositingMode=CompositingMode.SourceCopy; g.DrawImageUnscaled(original,0,0); }
        BitmapData data=image.LockBits(new Rectangle(0,0,image.Width,image.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
        try {
          byte[] bytes=new byte[image.Width*4];
          for(int y=0;y<image.Height;y++) {
            Marshal.Copy(IntPtr.Add(data.Scan0,y*data.Stride),bytes,0,bytes.Length);
            int row=y<bounds[1]?0:(y<bounds[2]?1:2);
            for(int x=0;x<image.Width;x++) if(bytes[x*4+3]>=threshold) {
              if(y==bounds[1]||y==bounds[2]) throw new Exception("A supplied row boundary crosses visible pixels.");
              result.Columns[row][x]++;
            }
          }
        } finally { image.UnlockBits(data); }
      }
      return result;
    }
  }
}
'@
  if ($PSEdition -eq 'Core') {
    $taskReferences=@((Get-ChildItem -LiteralPath (Join-Path $PSHOME 'ref') -Filter '*.dll').FullName)+[Drawing.Bitmap].Assembly.Location
    $taskReferences+=@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {$_.GetName().Name -like 'System.Private.Windows.*'} | ForEach-Object {$_.Location})
    Add-Type -TypeDefinition $taskCode -ReferencedAssemblies $taskReferences
  } else { Add-Type -TypeDefinition $taskCode -ReferencedAssemblies 'System.Drawing' }
}
function Get-RowColumnBounds([int[]]$Projection) {
  $gaps=@();$start=-1
  for($index=0;$index -le $Projection.Count;$index++) {
    $empty=$index -lt $Projection.Count -and $Projection[$index] -eq 0
    if($empty -and $start -lt 0) {$start=$index}
    if(-not $empty -and $start -ge 0) {
      $gaps+=[pscustomobject]@{Start=$start;EndExclusive=$index;Center=[int][Math]::Floor(($start+$index)/2)}
      $start=-1
    }
  }
  $bounds=@(0)
  for($part=1;$part -lt 4;$part++) {
    $target=$Projection.Count*$part/4.0
    $nearby=@($gaps | Where-Object {[Math]::Abs($_.Center-$target) -lt $Projection.Count/8.8} | Sort-Object @{Expression={[Math]::Abs($_.Center-$target)}})
    if(-not $nearby.Count) {throw "No real transparent gap near column split $part."}
    $bounds+=$nearby[0].Center
  }
  $bounds+=$Projection.Count
  for($part=1;$part -lt $bounds.Count;$part++) {if($bounds[$part] -le $bounds[$part-1]) {throw 'Column gaps do not form four ordered cells.'}}
  [pscustomobject]@{Bounds=[int[]]$bounds;TransparentGaps=$gaps}
}
$taskMeasurement=[NaiwaRowProjection]::Measure($SourcePath,$RowBounds,$AlphaThreshold)
$taskRowRecords=@()
for($taskRow=0;$taskRow -lt 3;$taskRow++) {
  try { $taskColumns=Get-RowColumnBounds $taskMeasurement.Columns[$taskRow] }
  catch { throw "Action=$Action row=$taskRow : $($_.Exception.Message)" }
  $taskRowRecords+=[pscustomobject]@{Row=$taskRow;Top=$RowBounds[$taskRow];Bottom=$RowBounds[$taskRow+1];ColumnBounds=$taskColumns.Bounds;TransparentGaps=$taskColumns.TransparentGaps}
}
$taskGroup=if($Action -eq 'stretch') {'animation_detailed'} else {'funny_detailed'}
$taskOriginal=[Drawing.Image]::FromFile((Join-Path (Join-Path $ReferenceAssetsRoot $taskGroup) ($Action+'_00.png')))
try {$taskWidth=$taskOriginal.Width;$taskHeight=$taskOriginal.Height} finally {$taskOriginal.Dispose()}
$taskMaxWidth=0;$taskMaxHeight=0
foreach($taskRowRecord in $taskRowRecords) {
  $taskMaxHeight=[Math]::Max($taskMaxHeight,$taskRowRecord.Bottom-$taskRowRecord.Top)
  for($taskColumn=0;$taskColumn -lt 4;$taskColumn++) {$taskMaxWidth=[Math]::Max($taskMaxWidth,$taskRowRecord.ColumnBounds[$taskColumn+1]-$taskRowRecord.ColumnBounds[$taskColumn])}
}
$taskScale=[Math]::Min($taskWidth/[double]$taskMaxWidth,$taskHeight/[double]$taskMaxHeight)
$taskFrameDirectory=Join-Path $OutputDirectory $taskGroup
[IO.Directory]::CreateDirectory($taskFrameDirectory) | Out-Null
# Validate all destinations before any frame is written.
for($taskIndex=0;$taskIndex -lt 12;$taskIndex++) {
  $taskFramePath=Join-Path $taskFrameDirectory ($Action+'_'+$taskIndex.ToString('00')+'.png')
  if((Test-Path -LiteralPath $taskFramePath) -and -not $Force) {throw "Frame already exists: $taskFramePath"}
}
$taskSource=[Drawing.Bitmap]::new($SourcePath)
$taskFrameRecords=@()
try {
  for($taskIndex=0;$taskIndex -lt 12;$taskIndex++) {
    $taskRow=[int][Math]::Floor($taskIndex/4);$taskColumn=$taskIndex%4
    $taskRowRecord=$taskRowRecords[$taskRow]
    $taskLeft=$taskRowRecord.ColumnBounds[$taskColumn];$taskRight=$taskRowRecord.ColumnBounds[$taskColumn+1]
    $taskTop=$taskRowRecord.Top;$taskBottom=$taskRowRecord.Bottom
    $taskCell=$taskSource.Clone([Drawing.Rectangle]::new($taskLeft,$taskTop,($taskRight-$taskLeft),($taskBottom-$taskTop)),[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $taskCanvas=[Drawing.Bitmap]::new($taskWidth,$taskHeight,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $taskGraphics=[Drawing.Graphics]::FromImage($taskCanvas)
    try {
      $taskGraphics.Clear([Drawing.Color]::Transparent)
      $taskGraphics.CompositingQuality=[Drawing.Drawing2D.CompositingQuality]::HighQuality
      $taskGraphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $taskGraphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $taskDrawWidth=[int][Math]::Round($taskCell.Width*$taskScale);$taskDrawHeight=[int][Math]::Round($taskCell.Height*$taskScale)
      $taskX=[int][Math]::Floor(($taskWidth-$taskDrawWidth)/2);$taskY=[int][Math]::Floor(($taskHeight-$taskDrawHeight)/2)
      $taskGraphics.DrawImage($taskCell,$taskX,$taskY,$taskDrawWidth,$taskDrawHeight)
      $taskFramePath=Join-Path $taskFrameDirectory ($Action+'_'+$taskIndex.ToString('00')+'.png')
      $taskCanvas.Save($taskFramePath,[Drawing.Imaging.ImageFormat]::Png)
      $taskFrameRecords+=[pscustomobject]@{Index=$taskIndex;SourceRect=@{Left=$taskLeft;Top=$taskTop;Right=$taskRight;Bottom=$taskBottom};Output=$taskFramePath;SHA256=(Get-FileHash -LiteralPath $taskFramePath -Algorithm SHA256).Hash}
    } finally {$taskGraphics.Dispose();$taskCanvas.Dispose();$taskCell.Dispose()}
  }
} finally {$taskSource.Dispose()}
$taskRecord=[pscustomobject]@{Action=$Action;Source=$SourcePath;SourceSHA256=(Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash;AlphaThreshold=$AlphaThreshold;SourceWidth=$taskMeasurement.Width;SourceHeight=$taskMeasurement.Height;RowBounds=$RowBounds;Rows=$taskRowRecords;UniformScale=$taskScale;FrameWidth=$taskWidth;FrameHeight=$taskHeight;Frames=$taskFrameRecords}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($RecordPath))) | Out-Null
$taskRecord | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $RecordPath -Encoding UTF8
Write-Output "Packaged $Action with independent transparent column gaps per row: 12 frames, ${taskWidth}x${taskHeight}."
Write-Output $RecordPath
