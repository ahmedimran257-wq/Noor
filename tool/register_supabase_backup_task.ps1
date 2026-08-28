[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRef,
    [string]$TaskName = 'Silarah Supabase Weekly Backup',
    [DayOfWeek]$DayOfWeek = [DayOfWeek]::Sunday,
    [datetime]$At = '03:00'
)

$ErrorActionPreference = 'Stop'

$backupScript = (Resolve-Path (Join-Path $PSScriptRoot 'backup_supabase.ps1')).Path
$powerShell = (Get-Command powershell.exe).Source
$arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -ProjectRef "{1}"' -f `
    $backupScript,
    $ProjectRef

$action = New-ScheduledTaskAction `
    -Execute $powerShell `
    -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek $DayOfWeek -At $At
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description 'Creates an ignored, checksummed logical backup of Silarah app-owned database schemas and data.' `
    -Force | Out-Null

$registered = Get-ScheduledTask -TaskName $TaskName
Write-Output "Registered: $($registered.TaskName)"
Write-Output "State: $($registered.State)"
Write-Output "Schedule: every $DayOfWeek at $($At.ToString('HH:mm')); starts when next available if missed"
