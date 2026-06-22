# Windows RDP Repair

> **Testing note:** This was tested by me to be working. User experience may vary.

Included script: `Repair-WindowsRDP.ps1`

```powershell
.\Repair-WindowsRDP.ps1
.\Repair-WindowsRDP.ps1 -Repair
.\Repair-WindowsRDP.ps1 -Repair -WhatIf
```

The script reports Remote Desktop configuration, services, firewall rules and port status. Repair mode restores service and existing firewall-rule readiness only when Remote Desktop is already enabled in Windows settings. It does not enable Remote Desktop on a disabled computer.

Logs: `C:\ProgramData\WindowsRDPRepair\Logs`

Exit codes: `0` success, `1` fatal error, `2` warnings.

Use at your own risk and follow your organisation’s remote-access policy.

MIT License.
