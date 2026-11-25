Start-Process 'D:\code\ahk_pro\octopus-launch\bin\octopus_launch.exe'
Start-Sleep -Milliseconds 1500
Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\sim.cs'
# Reproduce the failure scenario: dwell fires MID-STREAM during fast continuous movement
# (this is what killed the hook in the previous run)
[Sim]::Park(300, 300)
Start-Sleep -Milliseconds 300
# fast continuous stream to top edge (30 rapid steps, dwell fires mid-path)
[Sim]::MoveTo(960, 3, 30)
Start-Sleep -Milliseconds 600
# stream away
[Sim]::MoveTo(700, 400, 20)
Start-Sleep -Milliseconds 900
# repeat burst trigger
[Sim]::Park(300, 300)
Start-Sleep -Milliseconds 300
[Sim]::MoveTo(960, 3, 30)
Start-Sleep -Milliseconds 600
[Sim]::MoveTo(700, 400, 20)
Start-Sleep -Milliseconds 900
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 25
