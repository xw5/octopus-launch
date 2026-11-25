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

[Sim]::Park(500, 500)
Start-Sleep -Milliseconds 300
[Sim]::MoveTo(960, 3, 20)
Start-Sleep -Milliseconds 700

$menus = VisibleMenus
Write-Output '--- visible after popup ---'
$menus | ForEach-Object { $_ }
$rootRect = ParseRect ($menus | Select-Object -First 1)
Write-Output ("rootRect: {0}" -f ($menus | Select-Object -First 1))
$rowY = $rootRect.T + 26

# open submenu on item 0
[Sim]::MoveTo(($rootRect.L + 100), $rowY, 12)
Start-Sleep -Milliseconds 450
$n = (VisibleMenus | Measure-Object).Count
Write-Output ("T1 submenu open: {0} visible (expect 2)" -f $n)

# move DOWN to the separator row (rt+40+6+13/2 ~ +52) then next item -> submenu should close after 300ms
[Sim]::Park(($rootRect.L + 100), ($rootRect.T + 52))
Start-Sleep -Milliseconds 550
$n = (VisibleMenus | Measure-Object).Count
Write-Output ("T2 after move to sep row: {0} visible (expect 1)" -f $n)

# move back up to item 0 -> submenu reopens
[Sim]::Park(($rootRect.L + 100), $rowY)
Start-Sleep -Milliseconds 450
$n = (VisibleMenus | Measure-Object).Count
Write-Output ("T3 back on item0: {0} visible (expect 2)" -f $n)

# fast diagonal sweep: from item0 straight into submenu area in one quick move (regression: rescue path)
[Sim]::Park(($rootRect.L + 100), $rowY)
Start-Sleep -Milliseconds 300
$wins = VisibleMenus
$subRect = ParseRect ($wins | Sort-Object { (ParseRect $_).L } -Descending | Select-Object -First 1)
[Sim]::Park(($subRect.L + 80), ($rowY))   # single jump across the gap
Start-Sleep -Milliseconds 450             # sub timer was armed before jump; rescue check fires
$n = (VisibleMenus | Measure-Object).Count
Write-Output ("T4 fast jump into submenu lane: {0} visible (expect 2)" -f $n)

[Sim]::Park(1500, 900)
Start-Sleep -Milliseconds 800
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 15
