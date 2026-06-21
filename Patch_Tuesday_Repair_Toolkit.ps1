[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [switch]$RepairUpdateComponents,
 [switch]$RunDism,
 [switch]$RunSfc,
 [switch]$TriggerScan,
 [switch]$DryRun,[switch]$Yes,
 [string]$OutputPath=(Join-Path $env:ProgramData 'PatchTuesdayRepair')
)
$ErrorActionPreference='Stop';$script:Failures=0;$script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss);New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log';$before=Join-Path $run 'before.json';$after=Join-Path $run 'after.json'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function Admin{$p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function State{[pscustomobject]@{Collected=Get-Date;OS=Get-CimInstance Win32_OperatingSystem|Select-Object Caption,BuildNumber,Version,LastBootUpTime;Services=Get-Service wuauserv,bits,cryptsvc,msiserver -ErrorAction SilentlyContinue|Select-Object Name,Status,StartType;Disk=Get-Volume -DriveLetter C|Select-Object Size,SizeRemaining,HealthStatus;PendingReboot=[bool](Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending');Hotfix=Get-HotFix|Sort-Object InstalledOn -Descending|Select-Object -First 10 HotFixID,InstalledOn}}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
State|ConvertTo-Json -Depth 5|Set-Content $before -Encoding UTF8
if(-not($RepairUpdateComponents -or $RunDism -or $RunSfc -or $TriggerScan)){Write-Error 'Choose at least one repair action.';exit 2}
if(-not $DryRun -and -not(Admin)){Write-Error 'Run from elevated PowerShell.';exit 4}
if(-not $Yes -and -not $DryRun){if((Read-Host 'Apply selected patch-readiness repairs? Type YES') -ne 'YES'){Log 'Cancelled.';exit 10}}
if($RepairUpdateComponents){$services='bits','wuauserv','cryptsvc','msiserver';foreach($s in $services){Act "Stopping $s" {Stop-Service $s -Force -ErrorAction SilentlyContinue}};$sd="$env:SystemRoot\SoftwareDistribution";$cr="$env:SystemRoot\System32\catroot2";Act 'Resetting SoftwareDistribution cache' {if(Test-Path $sd){Rename-Item $sd "$sd.bak.$(Get-Date -Format yyyyMMddHHmmss)"}};Act 'Resetting catroot2 cache' {if(Test-Path $cr){Rename-Item $cr "$cr.bak.$(Get-Date -Format yyyyMMddHHmmss)"}};foreach($s in $services){Act "Starting $s" {Start-Service $s -ErrorAction Stop}}}
if($RunDism){Act 'Running DISM RestoreHealth' {$p=Start-Process dism.exe -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' -Wait -PassThru -NoNewWindow;if($p.ExitCode){throw "DISM exited $($p.ExitCode)"}}}
if($RunSfc){Act 'Running System File Checker' {$p=Start-Process sfc.exe -ArgumentList '/scannow' -Wait -PassThru -NoNewWindow;if($p.ExitCode -notin 0,1){throw "SFC exited $($p.ExitCode)"}}}
if($TriggerScan){Act 'Triggering Windows Update scan' {Start-Process "$env:SystemRoot\System32\UsoClient.exe" -ArgumentList 'StartScan' -Wait}}
Start-Sleep 3;State|ConvertTo-Json -Depth 5|Set-Content $after -Encoding UTF8
if($script:Failures){Log "Completed with $script:Failures failure(s).";exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
