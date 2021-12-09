<#
.Synopsis
    Set up the machine and $env:USERPROFILE.
.Description
    Installs Visual Studio Build Tools on the machine if a compatible installation of
    Visual Studio Community/Enterprise/Professional/Build Tools is not found.

    Installs Diskuv OCaml into a User directory.
.Parameter SilentInstall
    When specified no user interface should be shown.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
.Parameter AllowRunAsAdmin
    When specified you will be allowed to run this script using
    Run as Administrator.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
.Parameter ParentProgressId
    The PowerShell progress identifier. Optional, defaults to -1.
    Use when embedding this script within another setup program
    that reports its own progress.
.Parameter SkipProgress
    Do not use the progress user interface.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [int]
    $ParentProgressId = -1,
    [switch]
    $SkipAutoInstallVsBuildTools,
    [switch]
    $SilentInstall,
    [switch]
    $AllowRunAsAdmin,
    [switch]
    $SkipProgress
)

$ErrorActionPreference = "Stop"

$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
$DkmlPath = $HereDir.Parent.Parent.FullName
if (!(Test-Path -Path $DkmlPath\.dkmlroot)) {
    throw "Could not locate where this script was in the project. Thought DkmlPath was $DkmlPath"
}

$env:PSModulePath += "$([System.IO.Path]::PathSeparator)$HereDir"
Import-Module UnixInvokers
Import-Module Project

# Make sure not Run as Administrator
if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ((-not $AllowRunAsAdmin) -and $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error -Category SecurityError `
            -Message "You are in an PowerShell Run as Administrator session. Please run $HereScript from a non-Administrator PowerShell session."
        exit 1
    }
}

# ----------------------------------------------------------------
# Progress Reporting

$global:ProgressStep = 0
$global:ProgressActivity = $null
$ProgressTotalSteps = 2
$ProgressId = $ParentProgressId + 1
function Write-ProgressStep {
    if (!$SkipProgress) {
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
    } else {
        Write-Host -ForegroundColor DarkGreen "[$(1 + $global:ProgressStep) of $ProgressTotalSteps]: $($global:ProgressActivity)"
    }
    $global:ProgressStep += 1
}

# ----------------------------------------------------------------
# BEGIN Setup machine

$global:ProgressActivity = "Setup machine"
Write-ProgressStep

Invoke-Expression -Command "$HereDir\setup-machine.ps1 -ParentProgressId $ProgressId -SkipProgress:`$$SkipProgress -SkipAutoInstallVsBuildTools:`$$SkipAutoInstallVsBuildTools -AllowRunAsAdmin:`$$AllowRunAsAdmin -SilentInstall:`$$SilentInstall"

# END Setup machine
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Setup $env:USERPROFILE

$global:ProgressActivity = "Setup user profile"
Write-ProgressStep

Invoke-Expression -Command "$HereDir\setup-userprofile.ps1 -ParentProgressId $ProgressId -SkipProgress:`$$SkipProgress -AllowRunAsAdmin:`$$AllowRunAsAdmin"

# END Setup $env:USERPROFILE
# ----------------------------------------------------------------

if (-not $SkipProgress) { Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $global:ProgressActivity -Completed }
