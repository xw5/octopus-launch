Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\sim.cs'
# 1. click far away -> closes lingering menu (outside click)
[Sim]::Click(700, 400)
Start-Sleep -Milliseconds 700
# 2. trigger menu (jump to edge, park)
[Sim]::TriggerEdge(960, 3, 800)
# 3. leave -> close
[Sim]::Park(700, 400)
Start-Sleep -Milliseconds 900
# 4. trigger again (second consecutive appearance)
[Sim]::TriggerEdge(960, 3, 800)
# 5. leave -> close
[Sim]::Park(1100, 500)
Start-Sleep -Milliseconds 900
# 6. trigger third time
[Sim]::TriggerEdge(960, 3, 800)
# 7. leave, then click to close
[Sim]::Park(400, 600)
Start-Sleep -Milliseconds 900
[Sim]::Click(400, 600)
Start-Sleep -Milliseconds 500
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 14
