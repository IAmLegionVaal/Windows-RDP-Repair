# Windows RDP Repair

> **Testing note:** This was tested by me to be working. User experience may vary.

## One-click use

1. Download and extract the repository.
2. Double-click `Run-OneClick.bat`.
3. Approve the Windows administrator prompt.
4. When Remote Desktop is already enabled in Windows, the launcher restores the service and built-in firewall-rule readiness directly. There is no menu.
5. Review the exit code and logs in `C:\ProgramData\WindowsRDPRepair\Logs`.

Included script: `Repair-WindowsRDP.ps1`

## PowerShell usage

```powershell
.\Repair-WindowsRDP.ps1
.\Repair-WindowsRDP.ps1 -Repair
.\Repair-WindowsRDP.ps1 -Repair -WhatIf
```

The script reports Remote Desktop configuration, services, firewall rules and port status. Repair mode does not enable Remote Desktop on a computer where it is disabled; it repairs readiness only when remote access is already authorised and enabled.

Exit codes: `0` success, `1` fatal error, `2` warnings or unmet readiness conditions.

Follow your organisation’s remote-access policy. MIT License.
