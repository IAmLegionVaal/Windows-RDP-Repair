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

function Get-RdpFirewallRule{
    @(Get-NetFirewallRule -ErrorAction SilentlyContinue|Where-Object{
        $_.Name -like 'RemoteDesktop*' -or
        $_.Group -eq '@FirewallAPI.dll,-28752' -or
        $_.DisplayGroup -eq 'Remote Desktop'
    })
}

try{
    if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
    if($Repair -and -not(Test-Admin)){throw 'Run PowerShell as Administrator for repair mode.'}
    New-Item $runPath -ItemType Directory -Force|Out-Null

    Get-CimInstance Win32_OperatingSystem|Select-Object Caption,Version,BuildNumber|
        Export-Csv (Join-Path $runPath 'OperatingSystem.csv') -NoTypeInformation
    Get-Service TermService,UmRdpService -ErrorAction SilentlyContinue|
        Select-Object Name,Status,StartType|Export-Csv (Join-Path $runPath 'RdpServices-Before.csv') -NoTypeInformation

    $terminal=Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -ErrorAction Stop
    $rdpEnabled=$terminal.fDenyTSConnections -eq 0
    [pscustomobject]@{RdpEnabled=$rdpEnabled;DenyConnections=$terminal.fDenyTSConnections}|
        Export-Csv (Join-Path $runPath 'RdpConfiguration.csv') -NoTypeInformation

    $rulesBefore=Get-RdpFirewallRule
    $rulesBefore|Select-Object Name,DisplayName,DisplayGroup,Enabled,Direction,Action,Profile|
        Export-Csv (Join-Path $runPath 'RdpFirewallRules-Before.csv') -NoTypeInformation
    Get-NetTCPConnection -LocalPort 3389 -ErrorAction SilentlyContinue|
        Select-Object LocalAddress,LocalPort,State,OwningProcess|
        Export-Csv (Join-Path $runPath 'RdpPort-Before.csv') -NoTypeInformation

    if($Repair){
        if(-not $rdpEnabled){
            $warnings.Add('Remote Desktop is disabled in Windows settings. The script did not enable it.')
        }
        elseif($PSCmdlet.ShouldProcess('Remote Desktop services and existing firewall rules','Restore readiness')){
            Set-Service TermService -StartupType Manual -ErrorAction Stop
            $service=Get-Service TermService -ErrorAction Stop
            if($service.Status -ne 'Running'){Start-Service TermService -ErrorAction Stop}
            (Get-Service TermService -ErrorAction Stop).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))

            $rules=Get-RdpFirewallRule
            if($rules.Count -eq 0){
                $warnings.Add('No built-in Remote Desktop firewall rules were found.')
            }else{
                $rules|Enable-NetFirewallRule -ErrorAction Stop
            }
        }
    }

    $afterService=Get-Service TermService -ErrorAction Stop
    $afterRules=Get-RdpFirewallRule
    $afterService|Select-Object Name,Status,StartType|Export-Csv (Join-Path $runPath 'RdpServices-After.csv') -NoTypeInformation
    $afterRules|Select-Object Name,DisplayName,DisplayGroup,Enabled,Direction,Action,Profile|
        Export-Csv (Join-Path $runPath 'RdpFirewallRules-After.csv') -NoTypeInformation
    Get-NetTCPConnection -LocalPort 3389 -ErrorAction SilentlyContinue|
        Select-Object LocalAddress,LocalPort,State,OwningProcess|
        Export-Csv (Join-Path $runPath 'RdpPort-After.csv') -NoTypeInformation

    if($Repair -and $rdpEnabled){
        if($afterService.Status -ne 'Running'){$warnings.Add('Remote Desktop Services is not running after repair.')}
        if(@($afterRules|Where-Object{$_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' -and $_.Enabled -eq 'True'}).Count -eq 0){
            $warnings.Add('No enabled inbound Remote Desktop allow rule was verified after repair.')
        }
    }

    $warnings|Out-File (Join-Path $runPath 'Warnings.txt') -Encoding UTF8
    if($warnings.Count -gt 0){Write-Host "[WARN] Completed with warnings. Logs: $runPath" -ForegroundColor Yellow;exit 2}
    Write-Host "[OK] Completed. Logs: $runPath" -ForegroundColor Green;exit 0
}catch{Write-Error $_.Exception.Message;exit 1}
