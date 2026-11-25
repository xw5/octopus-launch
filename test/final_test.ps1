Start-Process 'D:\code\ahk_pro\octopus-launch\bin\octopus_launch.exe'
Start-Sleep -Milliseconds 1500
Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\sim.cs'
# full user-like flow: burst trigger, browse into menu, click item, re-trigger x2
[Sim]::Park(400, 300)
Start-Sleep -Milliseconds 400
[Sim]::MoveTo(960, 3, 30)          # burst toward edge, dwell fires mid-path
Start-Sleep -Milliseconds 800
# capture screen while menu open
Add-Type -AssemblyName System.Drawing
$b = New-Object System.Drawing.Bitmap(1492, 320)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen(0, 0, 0, 0, $b.Size)
$b.Save('D:\code\ahk_pro\octopus-launch\test\menu_open1.png')
$g.Dispose(); $b.Dispose()
[Sim]::MoveTo(700, 400, 20)        # leave -> close
Start-Sleep -Milliseconds 900
[Sim]::TriggerEdge(960, 3, 700)    # trigger 2 (park style)
[Sim]::Park(700, 400)
Start-Sleep -Milliseconds 900
[Sim]::TriggerEdge(960, 3, 700)    # trigger 3
[Sim]::Park(500, 450)
Start-Sleep -Milliseconds 900
[Sim]::TriggerEdge(960, 3, 700)    # trigger 4
[Sim]::Park(900, 500)
Start-Sleep -Milliseconds 900
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 30
