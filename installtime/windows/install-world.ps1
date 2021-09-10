# ==========================
# install-world.ps1
#
# Set up the machine and $env:USERPROFILE.
#
# ==========================

[CmdletBinding()]
param (
    [Parameter()]
    [int]
    $ParentProgressId = -1,
    [switch]
    $SkipAutoInstallVsBuildTools
)

$ErrorActionPreference = "Stop"

$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
$DkmlPath = $HereDir.Parent.Parent.FullName
if (!(Test-Path -Path $DkmlPath\.dkmlroot)) {
    throw "Could not locate where this script was in the project. Thought DkmlPath was $DkmlPath"
}

$env:PSModulePath += ";$HereDir"
Import-Module UnixInvokers
Import-Module Project

# Make sure not Run as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error -Category SecurityError `
        -Message "You are in an PowerShell Run as Administrator session. Please run $HereScript from a non-Administrator PowerShell session."
    exit 1
}

# ----------------------------------------------------------------
# Progress Reporting

$global:ProgressStep = 0
$global:ProgressActivity = $null
$ProgressTotalSteps = 2
$ProgressId = $ParentProgressId + 1
function Write-ProgressStep {
    if (!$global:SkipProgress) {
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
    } else {
        Write-Host -ForegroundColor DarkGreen "[$($global:ProgressStep) of $ProgressTotalSteps]: $($global:ProgressActivity)"
    }
    $global:ProgressStep += 1
}

# ----------------------------------------------------------------
# BEGIN Setup machine

$global:ProgressActivity = "Setup machine"
Write-ProgressStep

Invoke-Expression -Command "$HereDir\setup-machine.ps1 -ParentProgressId $ProgressId -SkipAutoInstallVsBuildTools:`$$SkipAutoInstallVsBuildTools"

# END Setup machine
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Setup $env:USERPROFILE

$global:ProgressActivity = "Setup user profile"
Write-ProgressStep

Invoke-Expression -Command "$HereDir\setup-userprofile.ps1 -ParentProgressId $ProgressId"

# END Setup $env:USERPROFILE
# ----------------------------------------------------------------

Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $global:ProgressActivity -Completed
