Start-Process 'D:\code\ahk_pro\octopus-launch\bin\octopus_launch.exe'
Start-Sleep -Milliseconds 1500
Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\sim.cs'
# baseline: hook alive?
[Sim]::Park(900, 300)
Start-Sleep -Milliseconds 1300
# trigger menu
[Sim]::TriggerEdge(960, 3, 800)
# leave
[Sim]::Park(700, 400)
Start-Sleep -Milliseconds 900
# click elsewhere
[Sim]::Click(700, 400)
Start-Sleep -Milliseconds 700
# re-trigger
[Sim]::TriggerEdge(960, 3, 800)
# leave
[Sim]::Park(500, 450)
Start-Sleep -Milliseconds 900
# click
[Sim]::Click(500, 450)
Start-Sleep -Milliseconds 700
# third trigger
[Sim]::TriggerEdge(960, 3, 800)
[Sim]::Park(400, 500)
Start-Sleep -Milliseconds 900
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 40
