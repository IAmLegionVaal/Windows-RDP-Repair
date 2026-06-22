<#
.SYNOPSIS
Diagnoses and repairs Windows Remote Desktop service readiness.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Repair,
    [string]$LogRoot="$env:ProgramData\WindowsRDPRepair\Logs"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$runPath=Join-Path $LogRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
$warnings=New-Object System.Collections.Generic.List[string]

function Test-Admin{
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try{
    if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
    if($Repair -and -not(Test-Admin)){throw 'Run PowerShell as Administrator for repair mode.'}
    New-Item $runPath -ItemType Directory -Force|Out-Null

    Get-CimInstance Win32_OperatingSystem|Select-Object Caption,Version,BuildNumber|
        Export-Csv (Join-Path $runPath 'OperatingSystem.csv') -NoTypeInformation
    Get-Service TermService,UmRdpService -ErrorAction SilentlyContinue|
        Select-Object Name,Status,StartType|Export-Csv (Join-Path $runPath 'RdpServices.csv') -NoTypeInformation

    $terminal=Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $rdpEnabled=$terminal.fDenyTSConnections -eq 0
    [pscustomobject]@{RdpEnabled=$rdpEnabled;DenyConnections=$terminal.fDenyTSConnections}|
        Export-Csv (Join-Path $runPath 'RdpConfiguration.csv') -NoTypeInformation

    Get-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue|
        Select-Object DisplayName,Enabled,Direction,Action,Profile|
        Export-Csv (Join-Path $runPath 'RdpFirewallRules.csv') -NoTypeInformation
    Get-NetTCPConnection -LocalPort 3389 -ErrorAction SilentlyContinue|
        Select-Object LocalAddress,LocalPort,State,OwningProcess|
        Export-Csv (Join-Path $runPath 'RdpPort.csv') -NoTypeInformation

    if($Repair){
        if(-not $rdpEnabled){
            $warnings.Add('Remote Desktop is disabled in Windows settings. The script did not enable it.')
        }
        elseif($PSCmdlet.ShouldProcess('Remote Desktop services and existing firewall rules','Restore readiness')){
            Set-Service TermService -StartupType Manual
            Start-Service TermService
            Get-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue|Enable-NetFirewallRule
        }
    }

    $warnings|Out-File (Join-Path $runPath 'Warnings.txt')
    if($warnings.Count -gt 0){Write-Host "[WARN] Completed with warnings. Logs: $runPath" -ForegroundColor Yellow;exit 2}
    Write-Host "[OK] Completed. Logs: $runPath" -ForegroundColor Green;exit 0
}catch{Write-Error $_.Exception.Message;exit 1}
