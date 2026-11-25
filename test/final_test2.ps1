Start-Process 'D:\code\ahk_pro\octopus-launch\bin\octopus_launch.exe'
Start-Sleep -Milliseconds 1500
Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\sim.cs'
# 4 consecutive trigger->close cycles with correct coordinates (primary monitor)
[Sim]::Park(400, 300)
Start-Sleep -Milliseconds 400
[Sim]::TriggerEdge(960, 3, 800)
[Sim]::Park(700, 400)
Start-Sleep -Milliseconds 900
[Sim]::TriggerEdge(960, 3, 800)
[Sim]::Park(700, 400)
Start-Sleep -Milliseconds 900
[Sim]::TriggerEdge(960, 3, 800)
[Sim]::Park(900, 500)
Start-Sleep -Milliseconds 900
[Sim]::TriggerEdge(960, 3, 800)
# leave menu open a moment and screenshot it
Start-Sleep -Milliseconds 400
Add-Type -AssemblyName System.Drawing
$b = New-Object System.Drawing.Bitmap(1920, 360)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen(0, 0, 0, 0, $b.Size)
$b.Save('D:\code\ahk_pro\octopus-launch\test\menu_open2.png')
$g.Dispose(); $b.Dispose()
[Sim]::Park(400, 600)
Start-Sleep -Milliseconds 900
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 22
