<#
.SYNOPSIS
Get failed logins through RDP from Eventlog and add firewall rule to block offending IPs

.DESCRIPTION
He protec
He attac
But most important
He put a block rule against brute-force attac

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
.\ProtectFrom-RDPBruteForce.ps1
Call it from PS commandline

.EXAMPLE
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -file 'C:\Shares\Scripts\Protect-RDSFromBruteforce\Protect-RDSFromBruteforce.ps1' -FailedLoginCount 10
Call this script from Task Scheduler with FailedLoginCount set to 10 attempts
#>
param (
#How deep to look in the log, in minutes. Should be reasonably low, to avoid performance impact.
[int]$timePeriod = 60,

#How many failed logon attempts should be found for a single IP address to be added to the list of offending IPs
[int]$FailedLoginCount = 5,

#Time period, in minutes, after which block rule will be removed
[int]$RemoveBlockRuleAfter = 480,

#Full path for HTML report file. Report is generated only if path is given.
[string]$HTMLReportPath
    
    )

$xpath = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational">
    <Select Path="Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational">*[System[(Level=3) and (EventID=140) and TimeCreated[timediff(@SystemTime) &lt;= $($timePeriod * 60 * 1000)]]]</Select>
  </Query>
</QueryList>
"@

$Events= Get-WinEvent -Listlog Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational  | Get-WinEvent  -FilterXPath $xpath | select TimeCreated, MachineName, @{N="IP";E={$_.Properties.Value}}
if ($Events) {
    $UniqueIPs = $events | select IP -Unique
    $OffendingIPs = `
        foreach ($UniqueIP in $UniqueIPs) {
            $filteredEvents =  @($events | ? {$_.ip -eq $UniqueIP.ip} | Sort-Object -Descending -Property TimeCreated)
            if ($filteredEvents.count -ge $FailedLoginCount) {
                $obj = '' | select `
                @{N='IP';E={
                    $UniqueIP.IP}},
                @{N='Attempts';E={
                    $filteredEvents.count}},
                @{N='MinutesBetween';E={
                    $TimeDiff = $filteredEvents[0].TimeCreated - ($filteredEvents[$filteredEvents.count - 1].TimeCreated) 
                    [math]::Round($TimeDiff.TotalMinutes,0)}},
                @{N='LastAttemptAt';E={
                    $filteredEvents[0].TimeCreated}},
                @{N='FirstAttemptAt';E={
                    $filteredEvents[$filteredEvents.count - 1].TimeCreated}}
                $obj
                }#end if
            }#end foreach
    }#end if events

#Get FW rules for blocking IPs
$dtNow = [datetime]::UtcNow | get-date -Format o  | get-date
$NetFWRules = @(Get-NetFirewallRule -DisplayName "RDP-BruteForce-Block" ) | select `
    @{N="DateAdded";E={
        get-date $_.Description }},
    @{N="IP";E={
        ($_ | Get-NetFirewallAddressFilter).RemoteAddress }},
    @{N="TimeSpan";E={
          [math]::Round(( ($dtNow ) - ($_.Description | get-date )).TotalMinutes,0) }},
    @{N="Guid";E={$_.Name}},
    @{N="Deleted";E={
        if ([math]::Round(( ($dtNow ) - ($_.Description | get-date )).TotalMinutes,0) -ge $RemoveBlockRuleAfter) {
            $True
            }
            else {
            $False
            }
        }}


if ($OffendingIPs) {
    #Generate FW rules
    foreach ($OffendingIP in $OffendingIPs) {
        $Splat = @{
            DisplayName = "RDP-BruteForce-Block"
            Description = [string]([datetime]::UtcNow | Get-Date -Format o)
            RemoteAddress = $OffendingIP.IP
            }
        if ($NetFWRules | ? {$_.IP -eq $OffendingIP.ip}) {
            "IP " + $OffendingIP.IP +" already in block list" | Write-Host
            }
            else {
            $NewRule = New-NetFirewallRule @Splat `
                -Action Block -Direction Inbound -Enabled True -Profile Any 
            }
        }#end foreach
    }#end offendingIPs


#Remove FW rules;
$NetFWRules | ? {$_.deleted} | % { Remove-NetFirewallRule -Name $_.Guid }

#Generate HTML Report
if ($HTMLReportPath) {
    $HTMLBody =  "* Generated at " + (get-date) + "<br>"
    $HTMLBody += "* Time period is " + ($timePeriod ) + " seconds<br>"
    $HTMLBody += "* Current bad login count cutoff: " + $FailedLoginCount + "<br>"
    $HTMLBody += "* Current timeout for FW rule removal (minutes): " + $RemoveBlockRuleAfter + "<br>"

    if ($OffendingIPs) {
        $HTMLBody += "<hr><br>Current offending IPs:<br>"
        $HTMLBody += $OffendingIPs | ConvertTo-Html -Fragment
        $HTMLBody += "<hr><br>Mikrotik CLI generation:<br>"
        $HTMLBody += $OffendingIPs | % {
            "/ip firewall address-list add list=`"BLACK LIST IN`" address=$($_.IP)/32" + "<br>"
            }
        }
        else {
        $HTMLBody += "<hr><br>There is no offending IPs in log<br>"
        }

    if ($NetFWRules) {
        $HTMLBody += "<hr><br>Local firewall rules block list:<br>"
        $HTMLBody += $NetFWRules | ConvertTo-Html -Fragment
        }
        else {
        $HTMLBody += "<hr><br>No local firewall rules block list<br>"
        }

    if ( -not (Test-Path (Split-Path $HTMLReportPath) -ErrorAction SilentlyContinue) ) {
        New-Item -ItemType Folder (Split-Path $HTMLReportPath)
        }
    ConvertTo-Html -Body $HTMLBody -Title "RDP-BruteForce-Block" | Set-Content -Path $HTMLReportPath 
    }#end HTML
