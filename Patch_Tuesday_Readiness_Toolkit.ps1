#requires -Version 5.1
<#
.SYNOPSIS
    Patch Tuesday Readiness Toolkit.
.DESCRIPTION
    Read-only monthly patch readiness context reporter for Windows support.
#>
[CmdletBinding()]
param([string]$OutputPath)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Patch_Readiness_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
function New-Check { param($Category,$Name,$Status,$Value,$Recommendation) [PSCustomObject]@{Category=$Category;Name=$Name;Status=$Status;Value=$Value;Recommendation=$Recommendation} }
$checks=@()
$os=Get-CimInstance Win32_OperatingSystem
$checks += New-Check 'System' 'OS build' 'Info' "$($os.Caption) Build $($os.BuildNumber)" 'Record OS build before patch cycle.'
$drive=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
$free=[math]::Round($drive.FreeSpace/1GB,2)
$checks += New-Check 'Disk' 'System drive free space' ($(if($free -lt 15){'Warning'}else{'OK'})) "$free GB" 'Low free space can affect update installation.'
$pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
$checks += New-Check 'Reboot' 'Pending reboot indicator' ($(if($pending){'Warning'}else{'OK'})) $pending 'Restart before patch window if pending.'
foreach($name in @('wuauserv','BITS','CryptSvc','UsoSvc')){ $svc=Get-Service $name -ErrorAction SilentlyContinue; if($svc){$checks += New-Check 'Services' $svc.DisplayName 'Info' "Status=$($svc.Status); StartType=$($svc.StartType)" 'Review update service context.'}}
try{$latest=Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1; $checks += New-Check 'Patch History' 'Latest hotfix' 'Info' "$($latest.HotFixID) $($latest.InstalledOn)" 'Review patch recency.'}catch{}
$checks | Export-Csv (Join-Path $OutputPath "patch_readiness_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$checks | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputPath "patch_readiness_$RunStamp.json") -Encoding UTF8
$checks | ConvertTo-Html -Title 'Patch Tuesday Readiness' -PreContent "<h1>Patch Tuesday Readiness - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p>" | Set-Content (Join-Path $OutputPath "patch_readiness_$RunStamp.html") -Encoding UTF8
$checks | Format-Table -AutoSize -Wrap
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
