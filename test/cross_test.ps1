Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\sim.cs'
Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\enumwin.cs'
$p = Get-Process octopus_launch | Select-Object -First 1
$procId = [uint32]$p.Id

function VisibleMenus {
  [WinEnum]::Dump($procId) | Where-Object { $_ -match 'visible=True' }
}
function ParseRect($s) {
  if ($s -match 'rect=\((-?\d+),(-?\d+),(-?\d+),(-?\d+)\)') {
    return @{ L=[int]$Matches[1]; T=[int]$Matches[2]; R=[int]$Matches[3]; B=[int]$Matches[4] }
  }
  return $null
}

# trigger menu at top edge of primary monitor
[Sim]::Park(500, 500)
Start-Sleep -Milliseconds 300
[Sim]::MoveTo(960, 3, 20)
Start-Sleep -Milliseconds 700   # dwell + popup

$menus = VisibleMenus
if (($menus | Measure-Object).Count -lt 1) { Write-Output 'FAIL: menu did not open'; exit 1 }
$rootRect = ParseRect ($menus | Select-Object -First 1)
Write-Output ("root rect: {0},{1},{2},{3}" -f $rootRect.L, $rootRect.T, $rootRect.R, $rootRect.B)

# hover onto first item row (has children), wait for submenu
$rowY = $rootRect.T + 26
[Sim]::MoveTo(($rootRect.L + 100), $rowY, 12)
Start-Sleep -Milliseconds 450   # sub timer 220ms

$menus = VisibleMenus
Write-Output ("visible menus after hover: {0}" -f ($menus | Measure-Object).Count)
$menus | ForEach-Object { $_ }

# pick the submenu = visible window with the largest L (opens to the right of parent)
$subWin = $menus | ForEach-Object { $_ } | Sort-Object { (ParseRect $_).L } -Descending | Select-Object -First 1
$subRect = ParseRect $subWin
Write-Output ("submenu rect: {0},{1},{2},{3}" -f $subRect.L, $subRect.T, $subRect.R, $subRect.B)

if ($subRect.L -le $rootRect.R) { Write-Output 'NOTE: submenu overlaps/not right of root; using root right edge anyway' }

# THE TEST: SLOWLY walk across parent-right-edge gap into submenu
# 2px per step, 40ms pause -> total crossing of ~35px takes ~700ms (way slower than old tolerance)
$x = $rootRect.R - 10
while ($x -lt ($subRect.L + 50)) {
  [Sim]::Park($x, $rowY)
  Start-Sleep -Milliseconds 40
  $x += 2
}
Start-Sleep -Milliseconds 500

$menus = VisibleMenus
Write-Output ("--- after SLOW cross: {0} visible menu(s) ---" -f ($menus | Measure-Object).Count)
$menus | ForEach-Object { $_ }
if (($menus | Measure-Object).Count -ge 2) { Write-Output 'PASS: submenu survives slow crossing' }
else { Write-Output 'FAIL: submenu closed' }

# also verify hovering a child item keeps it open
[Sim]::MoveTo(($subRect.L + 60), ($subRect.T + 26), 8)
Start-Sleep -Milliseconds 300
Write-Output ("after move inside submenu: {0} visible" -f ((VisibleMenus | Measure-Object).Count))

[Sim]::Park(1500, 900)   # leave -> closes
Start-Sleep -Milliseconds 800
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 30
