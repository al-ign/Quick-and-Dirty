$sPowerShellPath = Join-Path -Path $env:windir -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (Test-Path $sPowerShellPath) {
    Write-Debug 'Powershell.exe exists'
    }
    else {
    Throw 'Powershell.exe does not exists, can''t continue'
    }

Write-Verbose 'Downloading main script content'
$iwrMainScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/al-ign/Quick-and-Dirty/master/Protect-RDSFromBruteforce.ps1' -UseBasicParsing
if ($iwrMainScript.Content -notmatch 'RdpCoreTS') {
    Throw 'Something wrong happened - couldn''t get main script content. Aborting'
    }

$stName = 'Block bruteforcing IPs for RDP service' 
$stDescription = 'Script scans RdpCoreTS log for failed logon attempts and blocks offending IPs'

$scriptFolder = 'C:\Shares\Scripts\Protect-RDSFromBruteforce'
$scriptPath = $scriptFolder + '\Protect-RDSFromBruteforce.ps1'
$statsFolder = 'C:\Shares\www\Stats'
$statsPath =  $statsFolder + '\Protect-RDSFromBruteforce.html'

try {
    New-Item -Path $scriptFolder -ItemType directory  -Force
    Set-Content -Value $iwrMainScript.Content -LiteralPath $scriptPath -ErrorAction Stop
    New-Item -Path $statsFolder -ItemType directory   -Force
    Set-Content -Value 'TEST' -LiteralPath $statsPath -ErrorAction Stop
    }
catch {
    Throw ('Couldn''t create necessary files, aborting: ' + $Error[0])
    break
    }

if (Get-ScheduledTask -TaskName $stName -ErrorAction 0) {
    Write-Verbose 'Task with same name was found, removing'
    Unregister-ScheduledTask -TaskName $stName  -Confirm:$false -ErrorAction 0
    }

$stActionExecute = $sPowerShellPath
$stActionArgument = '-ExecutionPolicy Bypass -NoLogo -NoProfile -NonInteractive -File "'+ $scriptPath +'" -HTMLReportPath "'+ $statsPath +'" -timePeriod 60'
$stActionWorkingDirectory = $env:SystemRoot

$hstAction = @{
    Execute = $stActionExecute 
    Argument = $stActionArgument
    WorkingDirectory = $stActionWorkingDirectory
    }

try {
    $stPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel 'Highest'
    $stSettings = New-ScheduledTaskSettingsSet -Compatibility Win8 -ExecutionTimeLimit '00:10:00' -MultipleInstances IgnoreNew -RestartCount 0 
    $stTrigger = New-ScheduledTaskTrigger -At '00:00' -Daily 
    $stAction = New-ScheduledTaskAction @hstAction
    $stObject = New-ScheduledTask -Settings $stSettings -Trigger $stTrigger -Description $stDescription -Action $stAction 
    $stTask = Register-ScheduledTask -TaskName $stName  -User $stPrincipal.UserId -InputObject $stObject 
    $stTask.Triggers[0].Repetition.Interval = 'PT15M'
    $stTask.Triggers[0].Repetition.Duration = 'P1D'
    Set-ScheduledTask -InputObject $stTask
    }
    catch {
    Throw ("Could not create new task: "  + $Error[0]) 
    }
