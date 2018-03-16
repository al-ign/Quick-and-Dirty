#This script performs D4 DFRS restore of SYSVOL
#While there is some safety features (it won't run without at least Test-Connection to ALL DCs), it is not fail-safe script in any way
#If you want to make D4/Authoritative on non-PDC controller - manually define $AuthoritativeController variable with FQDN of the server


function Set-DFSRSysvolRestoreFlags {
    [cmdletBinding()]
    param (
        [parameter(mandatory=$true)]$ComputerName,
        [parameter(mandatory=$false)][Switch]$Authoritative,
        [parameter(mandatory=$true)]
        [ValidateSet(1,2)]
        [int]$Step
        )
    try {
        $Domain = Get-ADDomain
        }
    catch {
        Throw "Can't get domain info"
        }

    if (Test-Connection $ComputerName -Count 1 -Quiet) {
        try {
            $Identity = "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=$($ComputerName),OU=Domain Controllers,$($Domain.distinguishedname)"
            $obj = Get-ADObject -identity $Identity -properties *
            }
        catch {
            Throw "Can't get SYSVOL Object for $Identity"
            }#end try

        switch ($Step) {
            1 {
                $obj.'msDFSR-Enabled'=$FALSE
                if ($Authoritative) {
                    $obj.'msDFSR-options'=1
                    }
                }
            2 {
                $obj.'msDFSR-Enabled'=$TRUE
                }
            }

        try {
            Set-ADObject -Instance $obj
            }
        catch {
            Throw "Can't set ADObject for $ComputerName"
            }#end try
        }
        else {
            Throw "Can't test connection to $ComputerName"
        }#end if

    }#end function


filter No-Empty {
    $_ | ? {$PSItem -notmatch '^$' }
    }

try {
    $Domain = Get-ADDomain
    }
catch {
    Throw "Can't get Domain info"
    }

if ($AuthoritativeController) {
    #
    }
    else {
    $AuthoritativeController = $Domain.PDCEmulator
    }

$StatusTable = @()
    
    foreach ($DC in $Domain.ReplicaDirectoryServers) {
        $Status = '' | select CN, FQDN, dfsrEnable, dfsrOptions, Available, Authoritative
        $Status.CN = $DC -replace '^(\w+)(.+)','$1'
        $Status.FQDN = $DC
        $Status.Authoritative = $false
        if ($DC -eq $AuthoritativeController) {
            $Status.Authoritative = $true
            }
        $Status.Available = Test-Connection -ComputerName $DC -Quiet -Count 1

        $StatusTable += $Status
        }#end %

if ($StatusTable.available -contains $false) {
    throw "Some DCs is not available, aborting"
    }

    foreach ($DC in $StatusTable) {
        try {
            $Options = Get-DFSRSysvolConf -ComputerName $DC.CN
            }
        Catch {
            Throw "Can't access dfsr configuration for $($DC.CN)"
            }
        $DC.dfsrEnable = $Options.msDFSREnabled
        $DC.dfsrOptions = $Options.msDFSROptions
        }#end %

$StatusTable | ft

"Step 1: D4 for authoriative server" | Write-Host -ForegroundColor Yellow

$DC = $StatusTable | ? {$_.Authoritative -eq $true}
"Setting D4 Options for $($DC.FQDN)" | Write-Host -ForegroundColor Yellow
"Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Authoritative -Step 1" | Write-Host -ForegroundColor Cyan
Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Authoritative -Step 1

"Step 2: D2 for non-authoriative server" | Write-Host -ForegroundColor Yellow

foreach ($DC in ($StatusTable | ? {$_.Authoritative -eq $false}) ) {
    "Setting D2 Options for $($DC.FQDN)" | Write-Host -ForegroundColor Yellow
    "Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Step 1" | Write-Host -ForegroundColor Cyan
    Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Step 1
    }

"Step 3: replicate changes" | Write-Host -ForegroundColor Yellow
foreach ($DC in $StatusTable) {
    repadmin /syncall /APed /q $($DC.FQDN) | No-Empty
    dfsrdiag PollAD /Member:$($DC.FQDN) | No-Empty    
    }

"Step 4: Update status" | Write-Host -ForegroundColor Yellow

foreach ($DC in $StatusTable) {
        try {
            $Options = Get-DFSRSysvolConf -ComputerName $DC.CN
            }
        Catch {
            Throw "Can't access dfsr configuration for $($DC.CN)"
            }
        $DC.dfsrEnable = $Options.msDFSREnabled
        $DC.dfsrOptions = $Options.msDFSROptions
        }#end %

$StatusTable | ft

"Step 5: Enabling DFSR on Authoritative server" | Write-Host -ForegroundColor Yellow
$DC = $StatusTable | ? {$_.Authoritative -eq $true}

"Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Authoritative -Step 2" | Write-Host -ForegroundColor Cyan
Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Authoritative -Step 2

"Step 6: replicate changes" | Write-Host -ForegroundColor Yellow
foreach ($DC in $StatusTable) {
    repadmin /syncall /APed /q $($DC.FQDN) | No-Empty
    #dfsrdiag PollAD /Member:$($DC.FQDN) | No-Empty    
    }

"Step 7: Start DFSR on Authoritative server" | Write-Host -ForegroundColor Yellow

$DC = $StatusTable | ? {$_.Authoritative -eq $true}
#Get-Service -ComputerName $DC.FQDN -Name DFSR | Restart-Service
dfsrdiag PollAD /Member:$($DC.FQDN) | No-Empty

"Step 8: Update status" | Write-Host -ForegroundColor Yellow

foreach ($DC in $StatusTable) {
        try {
            $Options = Get-DFSRSysvolConf -ComputerName $DC.CN
            }
        Catch {
            Throw "Can't access dfsr configuration for $($DC.CN)"
            }
        $DC.dfsrEnable = $Options.msDFSREnabled
        $DC.dfsrOptions = $Options.msDFSROptions
        }#end %

$StatusTable | ft

"Step 9: Enable DFSR on non-Auth servers" | Write-Host -ForegroundColor Yellow

foreach ($DC in ($StatusTable | ? {$_.Authoritative -eq $false}) ) {
    "Setting D2 Options for $($DC.FQDN)" | Write-Host -ForegroundColor Yellow
    "Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Step 2" | Write-Host -ForegroundColor Cyan
    Set-DFSRSysvolRestoreFlags -ComputerName $($DC.CN) -Step 2

    }

"Step 9: Enable DFSR on non-Auth servers" | Write-Host -ForegroundColor Yellow

foreach ($DC in $StatusTable) {
        try {
            $Options = Get-DFSRSysvolConf -ComputerName $DC.CN
            }
        Catch {
            Throw "Can't access dfsr configuration for $($DC.CN)"
            }
        $DC.dfsrEnable = $Options.msDFSREnabled
        $DC.dfsrOptions = $Options.msDFSROptions
        }#end %

$StatusTable | ft

"Step 10: replicate changes and poll dfsr configuration" | Write-Host -ForegroundColor Yellow
foreach ($DC in $StatusTable) {
    repadmin /syncall /APed /q $($DC.FQDN) | No-Empty
    dfsrdiag PollAD /Member:$($DC.FQDN) | No-Empty    
    }

"Step 11: gather final dfsr configuration" | Write-Host -ForegroundColor Yellow
foreach ($DC in $StatusTable) {
        try {
            $Options = Get-DFSRSysvolConf -ComputerName $DC.CN
            }
        Catch {
            Throw "Can't access dfsr configuration for $($DC.CN)"
            }
        $DC.dfsrEnable = $Options.msDFSREnabled
        $DC.dfsrOptions = $Options.msDFSROptions
        }#end %

$StatusTable | ft
