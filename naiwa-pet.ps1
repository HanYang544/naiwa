Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Title="Naiwa Desktop Pet" Topmost="True" ShowInTaskbar="False" Width="280" Height="310"
        ResizeMode="NoResize" Focusable="True">
  <Grid>
    <Border x:Name="Bubble" VerticalAlignment="Top" HorizontalAlignment="Center"
            Background="#F2FFFFFF" BorderBrush="#33A05B00" BorderThickness="1"
            CornerRadius="13" Padding="10,6" Visibility="Collapsed">
      <TextBlock x:Name="Message" FontFamily="Microsoft YaHei UI" FontSize="13" Foreground="#4A3210"/>
    </Border>
    <Image x:Name="PetImage" Width="265" Height="265" VerticalAlignment="Bottom"
           Stretch="Uniform" RenderTransformOrigin="0.5,0.82">
      <Image.RenderTransform>
        <TransformGroup>
          <ScaleTransform x:Name="Facing" ScaleX="1" ScaleY="1"/>
          <ScaleTransform x:Name="Pulse" ScaleX="1" ScaleY="1"/>
          <RotateTransform x:Name="Lean" Angle="0"/>
          <TranslateTransform x:Name="Shift" X="0" Y="0"/>
        </TransformGroup>
      </Image.RenderTransform>
    </Image>
  </Grid>
</Window>
'@

function U([string]$base64) {
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64))
}

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$petImage = $window.FindName('PetImage')
$facing = $window.FindName('Facing')
$pulse = $window.FindName('Pulse')
$lean = $window.FindName('Lean')
$shift = $window.FindName('Shift')
$bubble = $window.FindName('Bubble')
$message = $window.FindName('Message')
$area = [System.Windows.SystemParameters]::WorkArea
$assetRoot = Join-Path $PSScriptRoot 'assets'
$script:action = 0
$script:actionStarted = Get-Date
$script:currentSprite = ''
$script:paused = $false
$script:dragging = $false
$script:dx = -0.85
$script:phase = 0.0
$script:sitStage = ''
$phrases = @(
  (U '5L2g5aW95ZGA77yB'),
  (U '6Zmq5oiR546p5ZCn77yB'),
  (U '5oiR5piv5aW25aiD44CC'),
  (U '5Zi/5Zi/5Zi/77yB'),
  (U '5Ly45Liq5oeS6IWw77yB')
)

function Set-Sprite([string]$name) {
  if ($script:currentSprite -eq $name) { return }
  $path = Join-Path $assetRoot ($name + '.png')
  $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
  $bitmap.BeginInit()
  $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
  $bitmap.UriSource = New-Object System.Uri($path, [System.UriKind]::Absolute)
  $bitmap.EndInit()
  $bitmap.Freeze()
  $petImage.Source = $bitmap
  $script:currentSprite = $name
}

function Reset-Transform {
  $pulse.ScaleX = 1.0
  $pulse.ScaleY = 1.0
  $lean.Angle = 0.0
  $shift.X = 0.0
  $shift.Y = 0.0
}

function Set-Action([int]$index) {
  $script:action = (($index % 13) + 13) % 13
  $script:actionStarted = Get-Date
  $script:phase = 0.0
  $script:sitStage = ''
  Reset-Transform
  switch ($script:action) {
    0 { Set-Sprite 'animation_detailed/walk_00' }
    1 { Set-Sprite 'animation_detailed/victory_00' }
    2 { Set-Sprite 'animation_detailed/sit_00' }
    3 { Set-Sprite 'animation_detailed/laugh_00' }
    4 { Set-Sprite 'animation_detailed/stretch_00' }
    5 { Set-Sprite 'funny_detailed/think_00' }
    6 { Set-Sprite 'funny_detailed/noodle_dance_00' }
    7 { Set-Sprite 'funny_detailed/belly_drum_00' }
    8 { Set-Sprite 'funny_detailed/pretzel_twist_00' }
    9 { Set-Sprite 'funny_detailed/freeze_00' }
    10 { Set-Sprite 'funny_detailed/fake_faint_00' }
    11 { Set-Sprite 'funny_detailed/brain_loading_00' }
    12 { Set-Sprite 'funny_detailed/play_bow_00' }
  }
}

function Next-Action {
  Set-Action ($script:action + 1)
}

function Get-SequenceFrame([int[]]$sequence, [double]$elapsedMs, [double]$stepMs) {
  $index = [int][Math]::Floor(($elapsedMs / $stepMs) % $sequence.Count)
  return $sequence[$index]
}

function Show-Message([string]$text) {
  $message.Text = $text
  $bubble.Visibility = 'Visible'
  $hide = New-Object Windows.Threading.DispatcherTimer
  $hide.Interval = [TimeSpan]::FromSeconds(2.5)
  $hide.Add_Tick({ $bubble.Visibility = 'Collapsed'; $this.Stop() })
  $hide.Start()
}

$window.Left = $area.Right - $window.Width - 30
$window.Top = $area.Bottom - $window.Height - 10
Set-Action 0

$window.Add_MouseLeftButtonDown({
  $script:dragging = $true
  $window.DragMove()
  $script:dragging = $false
})
$window.Add_MouseDoubleClick({
  Next-Action
  Show-Message ($phrases | Get-Random)
})

$menu = New-Object Windows.Controls.ContextMenu
$actionMenu = New-Object Windows.Controls.MenuItem
$actionMenu.Header = U '6YCJ5oup5Yqo5L2c'
$actionNames = @(
  (U '5oqx6IKa6KGM6LWw'),
  (U '5Li+5omL5aSn56yR'),
  (U '5Z2Q5LiL5ZWD6ISa6La+'),
  (U '5o2n6IW55aSn56yR'),
  (U '6La05Zyw5pGH5pGG5ZCQ6IiM5aS0'),
  (U '6K6k55yf5oCd6ICD'),
  (U '6Z2i5p2h5Lmx6Iie'),
  (U '6IKa55qu5omT6byT'),
  (U '6bq76Iqx5omt6Lqr'),
  (U '56qB54S255+z5YyW'),
  (U '5oiP57K+5YGH5pGU'),
  (U '5aSn6ISR5Yqg6L295Lit'),
  (U '5bGB6IKh5pyd5aSp5YG355yL')
)
for ($index = 0; $index -lt $actionNames.Count; $index++) {
  $actionChoice = New-Object Windows.Controls.MenuItem
  $actionChoice.Header = $actionNames[$index]
  $actionChoice.Tag = $index
  $actionChoice.Add_Click({ param($sender, $eventArgs) Set-Action ([int]$sender.Tag) })
  [void]$actionMenu.Items.Add($actionChoice)
}
$talkItem = New-Object Windows.Controls.MenuItem
$talkItem.Header = U '5ZKM5aW25aiD6K+06K+d'
$talkItem.Add_Click({ Show-Message ($phrases | Get-Random) })
$pauseItem = New-Object Windows.Controls.MenuItem
$pauseItem.Header = U '5pqC5YGc6LWw5Yqo'
$pauseItem.Add_Click({
  $script:paused = -not $script:paused
  $pauseItem.Header = if ($script:paused) { U '57un57ut6LWw5Yqo' } else { U '5pqC5YGc6LWw5Yqo' }
})
$exitItem = New-Object Windows.Controls.MenuItem
$exitItem.Header = U '6YCA5Ye6'
$exitItem.Add_Click({ $window.Close() })
[void]$menu.Items.Add($actionMenu)
[void]$menu.Items.Add($talkItem)
[void]$menu.Items.Add($pauseItem)
[void]$menu.Items.Add((New-Object Windows.Controls.Separator))
[void]$menu.Items.Add($exitItem)
$window.ContextMenu = $menu

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(60)
$timer.Add_Tick({
  $elapsed = ((Get-Date) - $script:actionStarted).TotalSeconds
  $elapsedMs = $elapsed * 1000
  Reset-Transform

  switch ($script:action) {
    0 {
      # Continuous walk at about 8 FPS; each pose remains crisp.
      $frame = [int][Math]::Floor(($elapsedMs / 120) % 12)
      Set-Sprite ("animation_detailed/walk_" + $frame.ToString('00'))
      if (-not $script:paused -and -not $script:dragging) {
        $window.Left += $script:dx * 1.05
        if ($window.Left -le $area.Left -or $window.Left + $window.Width -ge $area.Right) {
          $script:dx = -$script:dx
          $facing.ScaleX = if ($script:dx -lt 0) { 1 } else { -1 }
          $window.Left = [Math]::Max($area.Left, [Math]::Min($window.Left, $area.Right - $window.Width))
        }
      }
    }
    1 {
      # Smooth arm raise, facial change, jump, and landing.
      # Smooth motion with holds only at anticipation, airborne peak, and recovery.
      $sequence = @(0,0,0,1,2,3,4,5,6,7,8,8,8,8,8,9,10,11,11,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 160
      Set-Sprite ("animation_detailed/victory_" + $frame.ToString('00'))
    }
    2 {
      # Smooth sit, reach, foot lift, nibble, and return.
      # Natural pacing: observe, reach, lift, nibble hold, satisfied recovery.
      $sequence = @(0,0,0,0,1,2,3,4,5,6,7,8,9,10,10,10,10,10,10,11,11,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 200
      Set-Sprite ("animation_detailed/sit_" + $frame.ToString('00'))
    }
    3 {
      # Smooth face, finger, belly, and torso laugh cycle.
      # Quick facial progression with longer maximum-laugh and breathing holds.
      $sequence = @(0,0,0,0,1,2,3,4,5,6,7,8,8,8,8,9,10,11,11,11,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 180
      Set-Sprite ("animation_detailed/laugh_" + $frame.ToString('00'))
    }
    4 {
      # Smooth elbows, head, tongue, tail, and weight shift.
      # Smooth rock, longer deepest stretch, then a deliberate recovery.
      $sequence = @(0,0,0,1,2,3,4,5,6,6,6,6,6,7,8,9,10,11,11,11,11,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 180
      Set-Sprite ("animation_detailed/stretch_" + $frame.ToString('00'))
    }
    5 {
      # Hand, head, eyes and posture change across real rendered frames.
      $sequence = @(0,0,1,2,3,4,5,6,6,7,7,8,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 190
      Set-Sprite ("funny_detailed/think_" + $frame.ToString('00'))
    }
    6 {
      # Alternating kicks, arms, tongue and airborne poses.
      $sequence = @(0,1,2,3,3,4,5,6,7,7,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 155
      Set-Sprite ("funny_detailed/noodle_dance_" + $frame.ToString('00'))
    }
    7 {
      # Alternating hands visibly dent and release the belly.
      $sequence = @(0,0,1,2,3,4,5,6,7,8,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 170
      Set-Sprite ("funny_detailed/belly_drum_" + $frame.ToString('00'))
    }
    8 {
      # Legs, hips, torso and head counter-rotate through twelve poses.
      $sequence = @(0,0,1,2,3,4,5,5,6,7,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 185
      Set-Sprite ("funny_detailed/pretzel_twist_" + $frame.ToString('00'))
    }
    9 {
      # Startle, lock up, eye twitch, blink, then release.
      $sequence = @(0,0,0,1,2,3,4,4,4,4,5,5,6,6,7,7,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 190
      Set-Sprite ("funny_detailed/freeze_" + $frame.ToString('00'))
    }
    10 {
      # Hand to forehead, buckle, airborne fall, impact, peek and recovery.
      $sequence = @(0,0,1,2,3,4,5,6,7,7,7,8,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 185
      Set-Sprite ("funny_detailed/fake_faint_" + $frame.ToString('00'))
    }
    11 {
      # Eyes drift independently while head, arms and body lag behind.
      $sequence = @(0,0,1,2,3,4,5,6,7,7,8,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 205
      Set-Sprite ("funny_detailed/brain_loading_" + $frame.ToString('00'))
    }
    12 {
      # Hands, feet, hips, head, eyes and tongue articulate independently.
      $sequence = @(0,0,1,2,3,4,5,6,7,8,9,10,11,11)
      $frame = Get-SequenceFrame $sequence $elapsedMs 175
      Set-Sprite ("funny_detailed/play_bow_" + $frame.ToString('00'))
    }
  }

})
$timer.Start()
$window.Add_KeyDown({ if ($_.Key -eq 'Escape') { $window.Close() } })
$window.Add_Closed({ $timer.Stop() })
Show-Message (U '5aW25aiD5p2l5ZWm77yB')
[void]$window.ShowDialog()
