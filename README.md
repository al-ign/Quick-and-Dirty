# Quick-and-Dirty
Contains fast-written, ugly but working scripts

[Protect-RDSFromBruteforce.ps1](Protect-RDSFromBruteforce.ps1)

Simple ad-hoc self-defence script for public accessible RDP servers.
Throw it to Task Scheduler (with SYSTEM privileges)

[Install-ProtectRDSFromBruteforce.ps1](Install-ProtectRDSFromBruteforce.ps1)

Script will install Protect-RDSFromBruteforce.ps1 as scheduled task. You can invoke it from elevated PowerShell session directly:
`Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/al-ign/Quick-and-Dirty/master/Install-ProtectRDSFromBruteforce.ps1' -UseBasicParsing).Content`

[Perform-DFSRSysvolRestore.ps1](Perform-DFSRSysvolRestore.ps1)

Plain and straightforward script for performing [Authoritative restore for DFS-R SYSVOL](https://support.microsoft.com/en-us/help/2218556/)

[PSWFGUI-QuickAdd.ps1](PSWFGUI-QuickAdd.ps1)

Simple WPF GUI to add a firewall rule from the list of running processes

[PSWFGUI-QuickAdd.cmd](PSWFGUI-QuickAdd.cmd)

Same but in the `.cmd` form, for easy "Run as administrator" start. Save as ASCII/ANSI if Windows PowerShell complains and refuses to execute script.
