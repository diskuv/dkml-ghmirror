<#
.Synopsis
    Set up all programs and data folders that are shared across
    all users on the machine.
.Description
    Installs Git for Windows 2.33.0.
    Installs the MSBuild component of Visual Studio.
.Parameter $ParentProgressId
    The PowerShell progress identifier. Optional, defaults to -1.
    Use when embedding this script within another setup program
    that reports its own progress.
.Parameter $SkipAutoInstallVsBuildTools
    Do not automatically install Visual Studio Build Tools.

    Even with this switch is selected a compatibility check is
    performed to make sure there is a version of Visual Studio
    installed that has all the components necessary for Diskuv OCaml.
.Parameter $SilentInstall
    When specified no user interface should be shown.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
.Parameter $AllowRunAsAdmin
    When specified you will be allowed to run this script using
    Run as Administrator.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
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
    $AllowRunAsAdmin
)

$ErrorActionPreference = "Stop"

$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
$DkmlPath = $HereDir.Parent.Parent.FullName
if (!(Test-Path -Path $DkmlPath\.dkmlroot)) {
    throw "Could not locate where this script was in the project. Thought DkmlPath was $DkmlPath"
}

$env:PSModulePath += ";$HereDir"
Import-Module Deployers
Import-Module Project
Import-Module Machine

# Make sure not Run as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ((-not $AllowRunAsAdmin) -and $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
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
function Write-ProgressCurrentOperation {
    param(
        $CurrentOperation
    )
    if (!$global:SkipProgress) {
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -Status $global:ProgressStatus `
            -CurrentOperation $CurrentOperation `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
    }
}

# ----------------------------------------------------------------
# QUICK EXIT if already current version already deployed


# ----------------------------------------------------------------
# BEGIN Start deployment

$global:ProgressActivity = "Starting ..."
$global:ProgressStatus = "Starting ..."

# We use "deployments" for any temporary directory we need since the
# deployment process handles an aborted setup and the necessary cleaning up of disk
# space (eventually).
$TempParentPath = "$Env:temp\diskuvocaml\setupmachine"
$TempPath = Start-BlueGreenDeploy -ParentPath $TempParentPath -DeploymentId $MachineDeploymentId -LogFunction ${function:\Write-ProgressCurrentOperation}

# END Start deployment
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Visual Studio Setup PowerShell Module

$global:ProgressActivity = "Install Visual Studio Setup PowerShell Module"
Write-ProgressStep

# only error if user said $SkipAutoInstallVsBuildTools but there was no visual studio found
Import-VSSetup -TempPath "$TempPath\vssetup"
$CompatibleVisualStudios = Get-CompatibleVisualStudio -ErrorIfNotFound:$SkipAutoInstallVsBuildTools

# END Visual Studio Setup PowerShell Module
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Visual Studio Build Tools

# MSBuild 2015+ is the command line tools of Visual Studio.
#
# > Visual Studio Code is a very different product from Visual Studio 2015+. Do not confuse
# > the products if you need to install it! They can both be installed, but for this section
# > we are talking abobut Visual Studio 2015+ (ex. Visual Studio Community 2019).
#
# > Why MSBuild / Visual Studio 2015+? Because [vcpkg](https://vcpkg.io/en/getting-started.html) needs
# > Visual Studio 2015 Update 3 or newer as of July 2021.
#
# It is generally safe to run multiple MSBuild and Visual Studio installations on the same machine.
# The one in `C:\DiskuvOCaml\BuildTools` is **reserved** for our build system as it has precise
# versions of the tools we need.
#
# You can **also** install Visual Studio 2015+ which is the full GUI.
#
# Much of this section was adapted from `C:\Dockerfile.opam` while running
# `docker run --rm -it ocaml/opam:windows-msvc`.
#
# Key modifications:
# * We do not use C:\BuildTools but $env:SystemDrive\DiskuvOCaml\BuildTools instead
#   because C:\ may not be writable and avoid "BuildTools" since it is a known directory
#   that can create conflicts with other
#   installations (confer https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019)
# * This is meant to be idempotent so we "modify" and not just install.
# * We've added/changed some components especially to get <stddef.h> C header (actually, we should inform
#   ocaml-opam so they can mimic the changes)

$global:ProgressActivity = "Install Visual Studio Build Tools"
Write-ProgressStep

if ((-not $SkipAutoInstallVsBuildTools) -and ($CompatibleVisualStudios | Measure-Object).Count -eq 0) {
    $VsInstallTempPath = "$TempPath\vsinstall"

    # Download tools we need to install MSBuild
    if ([Environment]::Is64BitOperatingSystem) {
        $VsArch = "x64"
    } else {
        $VsArch = "x86"
    }
    if (!(Test-Path -Path $VsInstallTempPath)) { New-Item -Path $VsInstallTempPath -ItemType Directory | Out-Null }
    if (!(Test-Path -Path $VsInstallTempPath\vc_redist.$VsArch.exe)) { Invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.$VsArch.exe -OutFile $VsInstallTempPath\vc_redist.$VsArch.exe }
    if (!(Test-Path -Path $VsInstallTempPath\collect.exe)) { Invoke-WebRequest -Uri https://aka.ms/vscollect.exe                   -OutFile $VsInstallTempPath\collect.exe }
    if (!(Test-Path -Path $VsInstallTempPath\VisualStudio.chman)) { Invoke-WebRequest -Uri https://aka.ms/vs/16/release/channel           -OutFile $VsInstallTempPath\VisualStudio.chman }
    if (!(Test-Path -Path $VsInstallTempPath\vs_buildtools.exe)) { Invoke-WebRequest -Uri https://aka.ms/vs/16/release/vs_buildtools.exe -OutFile $VsInstallTempPath\vs_buildtools.exe }

    if (!(Test-Path -Path $VsInstallTempPath\Install.orig.cmd)) { Invoke-WebRequest -Uri https://raw.githubusercontent.com/MisterDA/Windows-OCaml-Docker/d3a107132f24c05140ad84f85f187e74e83e819b/Install.cmd -OutFile $VsInstallTempPath\Install.orig.cmd }
    if (!(Test-Path -Path $VsInstallTempPath\Install.cmd) -or
        (Test-Path -Path $VsInstallTempPath\Install.orig.cmd -NewerThan (Get-Item $VsInstallTempPath\Install.cmd).LastWriteTime)) {
        $content = Get-Content -Path $VsInstallTempPath\Install.orig.cmd
        $content = $content -replace "C:\\TEMP", "$VsInstallTempPath"
        $content = $content -replace "C:\\vslogs.zip", "$VsInstallTempPath\vslogs.zip"
        $content | Set-Content -Path $VsInstallTempPath\Install.cmd
    }

    # Create destination directory
    if (!(Test-Path -Path $env:SystemDrive\DiskuvOCaml)) { New-Item -Path $env:SystemDrive\DiskuvOCaml -ItemType Directory | Out-Null }

    # See how to use vs_buildtools.exe at
    # https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019

    # Components:
    # https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2019
    #
    # * Microsoft.VisualStudio.Component.VC.Tools.x86.x64
    #   - VS 2019 C++ x64/x86 build tools (Latest)
    # * Microsoft.VisualStudio.Component.Windows10SDK.18362
    #   - Windows 10 SDK (10.0.18362.0)
    #   - Same version in ocaml-opam Docker image as of 2021-10-10
    $CommonArgs = @(
        "--wait",
        "--nocache",
        "--installPath", "$env:SystemDrive\DiskuvOCaml\BuildTools",
        "--channelUri", "$VsInstallTempPath\VisualStudio.chman",
        "--installChannelUri", "$VsInstallTempPath\VisualStudio.chman",
        "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "--add", "Microsoft.VisualStudio.Component.Windows10SDK.$Windows10SdkVer"
    )
    if ($SilentInstall) {
        $CommonArgs += @("--quiet")
    } else {
        $CommonArgs += @("--passive", "--norestart")
    }
    if (Test-Path -Path $env:SystemDrive\DiskuvOCaml\BuildTools\MSBuild\Current\Bin\MSBuild.exe) {
        $proc = Start-Process -FilePath $VsInstallTempPath\Install.cmd -NoNewWindow -Wait -PassThru `
            -ArgumentList (@("$VsInstallTempPath\vs_buildtools.exe", "modify") + $CommonArgs)
    }
    else {
        $proc = Start-Process -FilePath $VsInstallTempPath\Install.cmd -NoNewWindow -Wait -PassThru `
            -ArgumentList (@("$VsInstallTempPath\vs_buildtools.exe") + $CommonArgs)
    }
    $exitCode = $proc.ExitCode
    if ($exitCode -eq 3010) {
        Write-Warning "Microsoft Visual Studio Build Tools installation succeeded but a reboot is required!"
        Start-Sleep 5
        Write-Host ''
        Write-Host 'Press any key to exit this script... You must reboot!';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        throw
    }
    elseif ($exitCode -ne 0) {
        Write-Error "Microsoft Visual Studio Build Tools installation failed! Exited with $exitCode."
        throw
    }

    # Reconfirm the install was detected
    $CompatibleVisualStudios = Get-CompatibleVisualStudio -ErrorIfNotFound:$false
    if (($CompatibleVisualStudios | Measure-Object).Count -eq 0) {
        $ErrorActionPreference = "Continue"
        & $VsInstallTempPath\collect.exe "-zip:$VsInstallTempPath\vslogs.zip"
        Write-Error (
            "No compatible Visual Studio installation detected after the Visual Studio installation! " +
            "Often this is because a reboot is required or your system has a component that needs upgrading.`n`n" +
            "FIRST you should reboot and try again.`n`n"+
            "SECOND you can run $VsInstallTempPath\vs_buildtools.exe to manually install Visual Studio Build Tools.`n"+
            "You will need the following components:`n"+
            "`ta) VS 2019 C++ x64/x86 build tools (Latest)`n" +
            "`tb) Windows 10 SDK (10.0.$Windows10SdkVer.0)`n`n" +
            "THIRD, if everything else failed, you can file a Bug Report at https://gitlab.com/diskuv/diskuv-ocaml/-/issues and attach $VsInstallTempPath\vslogs.zip`n"
        )
        exit 1
    }
}

# END Visual Studio Build Tools
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Stop deployment

Stop-BlueGreenDeploy -ParentPath $TempParentPath -DeploymentId $MachineDeploymentId # no -Success so always delete the temp directory

# END Stop deployment
# ----------------------------------------------------------------

Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $global:ProgressActivity -Completed
