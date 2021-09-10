[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification='Some variables are simply for export',
    Target="VsAddComponents")]
[CmdletBinding()]
param ()

Import-Module Deployers # for Get-Sha256Hex16OfText

# -----------------------------------
# Magic constants

# Magic constants that will identify new and existing deployments:
# * Microsoft build numbers
# * Semver numbers
$Windows10SdkVer = "18362"        # KEEP IN SYNC with WindowsAdministrator.rst

# Visual Studio minimum version
# Why MSBuild / Visual Studio 2015+? Because [vcpkg](https://vcpkg.io/en/getting-started.html) needs
#   Visual Studio 2015 Update 3 or newer as of July 2021.
# 14.0.25431.01 == Visual Studio 2015 Update 3 (newest patch; older is 14.0.25420.10)
$VsVerMin = "14.0.25420.10"       # KEEP IN SYNC with WindowsAdministrator.rst and reproducible-compile-opam-(1-setup|2-build).sh's OPT_MSVS_PREFERENCE
$VsDescribeVerMin = "Visual Studio 2015 Update 3 or later"

$VsSetupVer = "2.2.14-87a8a69eef"

# Version Years
# -------------
#
# We install VS 2019 although it may be better for a compatibility matrix to do VS 2015 as well.
#
# If you need an older vs_buildtools.exe installer, see either:
# * https://docs.microsoft.com/en-us/visualstudio/releases/2019/history#release-dates-and-build-numbers
# * https://github.com/jberezanski/ChocolateyPackages/commits/master/visualstudio2017buildtools/tools/ChocolateyInstall.ps1
#
# However VS 2017 + VS 2019 Build Tools can install the 2015 compiler component;
# confer https://devblogs.microsoft.com/cppblog/announcing-visual-c-build-tools-2015-standalone-c-tools-for-build-environments/.
#
# Below is
#   >> VS 2019 Build Tools 16.11.2 <<
$VsBuildToolsMajorVer = "16" # Either 16 for Visual Studio 2019 or 15 for Visual Studio 2017 Build Tools
$VsBuildToolsInstaller = "https://download.visualstudio.microsoft.com/download/pr/bacf7555-1a20-4bf4-ae4d-1003bbc25da8/e6cfafe7eb84fe7f6cfbb10ff239902951f131363231ba0cfcd1b7f0677e6398/vs_BuildTools.exe"
$VsBuildToolsInstallChannel = "https://aka.ms/vs/16/release/channel" # use 'installChannelUri' from: & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -all -products *

# Components
# ----------
#
# The official list is at:
# https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2019
#
# BUT THAT LIST ISN'T COMPLETE. You can use the vs_buildtools.exe installer and "Export configuration"
# and it will produce a file like in `vsconfig.json` in this folder. That will have exact component ids to
# use, and most importantly you can pick older versions like `Microsoft.VisualStudio.Component.VC.14.26.x86.x64`
# if the version of Build Tools supports it.
# HAVING SAID THAT, it is safest to use generic component names `Microsoft.VisualStudio.Component.VC.Tools.x86.x64`
# and install the fixed-release Build Tools that corresponds to the compiler version you want.
#
# We chose the following to work around the bugs listed below:
#
# * Microsoft.VisualStudio.Component.VC.Tools.x86.x64
#   - VS 2019 C++ x64/x86 build tools (Latest)
# * Microsoft.VisualStudio.Component.Windows10SDK.18362
#   - Windows 10 SDK (10.0.18362.0)
#   - Same version in ocaml-opam Docker image as of 2021-10-10
#
# VISUAL STUDIO BUG 1
# -------------------
#     ../../ocamlopt.opt.exe -nostdlib -I ../../stdlib -I ../../otherlibs/win32unix -c -w +33..39 -warn-error A -g -bin-annot -safe-string  semaphore.ml
#     ../../ocamlopt.opt.exe -nostdlib -I ../../stdlib -I ../../otherlibs/win32unix -linkall -a -cclib -lthreadsnat  -o threads.cmxa thread.cmx mutex.cmx condition.cmx event.cmx threadUnix.cmx semaphore.cmx
#     OCAML_FLEXLINK="../../boot/ocamlrun ../../flexdll/flexlink.exe" ../../boot/ocamlrun.exe ../../tools/ocamlmklib.exe -o threadsnat st_stubs.n.obj
#     dyndll09d83a.obj : fatal error LNK1400: section 0x13 contains invalid volatile metadata
#     ** Fatal error: Error during linking
#
#     make[3]: *** [Makefile:74: libthreadsnat.lib] Error 2
#     make[3]: Leaving directory '/c/DiskuvOCaml/OpamSys/32/src/opam/bootstrap/ocaml-4.12.0/otherlibs/systhreads'
#     make[2]: *** [Makefile:35: allopt] Error 2
#     make[2]: Leaving directory '/c/DiskuvOCaml/OpamSys/32/src/opam/bootstrap/ocaml-4.12.0/otherlibs'
#     make[1]: *** [Makefile:896: otherlibrariesopt] Error 2
#     make[1]: Leaving directory '/c/DiskuvOCaml/OpamSys/32/src/opam/bootstrap/ocaml-4.12.0'
#     make: *** [Makefile:219: opt.opt] Error 2
#
# Happens with Microsoft.VisualStudio.Component.VC.Tools.x86.x64,version=16.11.31317.239 (aka
# "MSVC v142 - VS 2019 C++ x64/x86 build tools (Latest)" as of September 2021) when compiling
# both native 32-bit (x86) and cross-compiled 64-bit host for 32-bit target (x64_x86).
#
# Does _not_ happen with Microsoft.VisualStudio.Component.VC.Tools.x86.x64,version=16.6.30013.169
# which had been installed in Microsoft.VisualStudio.Product.BuildTools,version=16.6.30309.148
# (aka version 14.26.28806 with VC\Tools\MSVC\14.26.28801 directory) of
# VisualStudio/16.6.4+30309.148 in the GitLab CI Windows container
# (https://gitlab.com/gitlab-org/ci-cd/shared-runners/images/gcp/windows-containers/-/tree/main/cookbooks/preinstalled-software)
# by:
#  visualstudio2019buildtools 16.6.5.0 (no version 16.6.4!) (https://chocolatey.org/packages/visualstudio2019buildtools)
#  visualstudio2019-workload-vctools 1.0.0 (https://chocolatey.org/packages/visualstudio2019-workload-vctools)
$VcVarsVer = "14.26"
$VsComponents = @(
    # Verbatim (except variable replacement) from vsconfig.json that was "Export configuration" from the
    # correctly versioned vs_buildtools.exe installer, but removed all transitive dependencies.
    "Microsoft.VisualStudio.Component.VC.$VcVarsVer.x86.x64",
    "Microsoft.VisualStudio.Component.Windows10SDK.$Windows10SdkVer"
)
$VsAddComponents = $VsComponents | ForEach-Object { $i = 0 }{ @( "--add", $VsComponents[$i] ); $i++ }
$VsDescribeComponents = (
    "`ta) MSVC v142 - VS 2019 C++ x64/x86 build tools (v$VcVarsVer)`n" +
    "`tb) Windows 10 SDK (10.0.$Windows10SdkVer.0)`n")

# Consolidate the magic constants into a single deployment id
$VsComponentsHash = Get-Sha256Hex16OfText -Text ($CygwinPackagesArch -join ',')
$MachineDeploymentId = "winsdk-$Windows10SdkVer;vsvermin-$VsVerMin;vssetup-$VsSetupVer;vscomp-$VsComponentsHash"

Export-ModuleMember -Variable MachineDeploymentId
Export-ModuleMember -Variable Windows10SdkVer
Export-ModuleMember -Variable VsBuildToolsMajorVer
Export-ModuleMember -Variable VsBuildToolsInstaller
Export-ModuleMember -Variable VsBuildToolsInstallChannel
Export-ModuleMember -Variable VsDescribeVerMin
Export-ModuleMember -Variable VsComponents
Export-ModuleMember -Variable VsAddComponents
Export-ModuleMember -Variable VsRemoveComponents
Export-ModuleMember -Variable VsDescribeComponents
# -----------------------------------

$MachineDeploymentHash = Get-Sha256Hex16OfText -Text $MachineDeploymentId
$DkmlPowerShellModules = "$env:SystemDrive\DiskuvOCaml\PowerShell\$MachineDeploymentHash\Modules"
$env:PSModulePath += ";$DkmlPowerShellModules"

function Import-VSSetup {
    param (
        [Parameter(Mandatory = $true)]
        $TempPath
    )

    $VsSetupModules = "$DkmlPowerShellModules\VSSetup"

    if (!(Test-Path -Path $VsSetupModules\VSSetup.psm1)) {
        if (!(Test-Path -Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory | Out-Null }
        Invoke-WebRequest -Uri https://github.com/microsoft/vssetup.powershell/releases/download/$VsSetupVer/VSSetup.zip -OutFile $TempPath\VSSetup.zip
        if (!(Test-Path -Path $VsSetupModules)) { New-Item -Path $VsSetupModules -ItemType Directory | Out-Null }
        Expand-Archive $TempPath\VSSetup.zip $VsSetupModules
    }

    Import-Module VSSetup
}
Export-ModuleMember -Function Import-VSSetup

# Get zero or more Visual Studio installations that are compatible with Diskuv OCaml.
# The "latest" is chosen so theoretically should be zero or one installations returned,
# but for safety you should pick only the first given back (ex. Select-Object -First 1)
# and for troubleshooting you should dump what is given back (ex. Get-CompatibleVisualStudios | ConvertTo-Json)
function Get-CompatibleVisualStudios {
    [CmdletBinding()]
    param (
        [switch]
        $ErrorIfNotFound
    )
    # Some examples of the related `vswhere` product: https://github.com/Microsoft/vswhere/wiki/Examples
    $allinstances = Get-VSSetupInstance
    $instances = $allinstances | Select-VSSetupInstance `
        -Product * `
        -Require $VsComponents `
        -Version "[$VsVerMin,)" `
        -Latest
    if ($ErrorIfNotFound -and ($instances | Measure-Object).Count -eq 0) {
        $ErrorActionPreference = "Continue"
        Write-Warning "`n`nBEGIN Dump all incompatible Visual Studio(s)"
        if ($null -ne $allinstance) { Write-Warning ($allinstances | ConvertTo-Json) }
        Write-Warning "END Dump all incompatible Visual Studio(s)`n`n"
        $err = "There is no $VsDescribeVerMin with the following:`n$VsDescribeComponents"
        Write-Error $err
        exit 1
    }
    $instances
}
Export-ModuleMember -Function Get-CompatibleVisualStudios

function Get-VisualStudioProperties {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]        
        $VisualStudioInstallation
    )
    $MsvsPreference = ("" + $VisualStudioInstallation.InstallationVersion.Major + "." + $VisualStudioInstallation.InstallationVersion.Minor)
    @{
        InstallPath = $VisualStudioInstallation.InstallationPath;
        MsvsPreference = "VS$MsvsPreference";
        VcVarsVer = $VcVarsVer
    }
}
Export-ModuleMember -Function Get-VisualStudioProperties
