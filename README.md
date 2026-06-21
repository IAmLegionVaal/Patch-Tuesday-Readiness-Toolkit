# Patch Tuesday Readiness Toolkit

A PowerShell toolkit for monthly Windows patch readiness checks and selected guarded update repairs.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Patch_Tuesday_Readiness_Toolkit.ps1
```

## Repair script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Patch_Tuesday_Repair_Toolkit.ps1 -RepairUpdateComponents -DryRun
```

Examples:

```powershell
.\Patch_Tuesday_Repair_Toolkit.ps1 -RepairUpdateComponents
.\Patch_Tuesday_Repair_Toolkit.ps1 -RunDism -RunSfc
.\Patch_Tuesday_Repair_Toolkit.ps1 -TriggerScan
```

## What the repair does

- Restarts Windows Update, BITS, Cryptographic Services and Windows Installer.
- Renames the SoftwareDistribution and catroot2 caches so Windows can rebuild them.
- Runs DISM RestoreHealth and System File Checker.
- Triggers a Windows Update scan.
- Captures build, disk, service, reboot and hotfix state before and after repair.
- Supports `-DryRun`, confirmation prompts, logs and clear exit codes.

## Safety

Cache reset stops update-related services briefly and retains timestamped backup folders. The script does not install updates or reboot automatically.

## Author

Dewald Pretorius — L2 IT Support Engineer
