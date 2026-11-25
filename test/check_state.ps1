Add-Type -Path 'D:\code\ahk_pro\octopus-launch\test\enumwin.cs'
$p = Get-Process octopus_launch | Select-Object -First 1
[WinEnum]::Dump([uint32]$p.Id)
'--- log tail ---'
Get-Content 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\debug.log' -Tail 8
