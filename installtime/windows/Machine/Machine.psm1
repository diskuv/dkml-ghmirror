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
$VsVerMin = "14.0.25420.10"       # KEEP IN SYNC with WindowsAdministrator.rst and reproducible-compile-opam-2-build.sh's MSVS_PREFERENCE
$VsSetupVer = "2.2.14-87a8a69eef"

# Consolidate the magic constants into a single deployment id
$MachineDeploymentId = "winsdk-$Windows10SdkVer;vsver-$VsVerMin;vssetup-$VsSetupVer"

Export-ModuleMember -Variable MachineDeploymentId
Export-ModuleMember -Variable Windows10SdkVer
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

function Get-CompatibleVisualStudio {
    [CmdletBinding()]
    param (
        [switch]
        $ErrorIfNotFound
    )
    # Some examples of the related `vswhere` product: https://github.com/Microsoft/vswhere/wiki/Examples
    $instances = Get-VSSetupInstance | Select-VSSetupInstance `
        -Product * `
        -Require @( "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "Microsoft.VisualStudio.Component.Windows10SDK.$Windows10SdkVer" ) `
        -Version "[$VsVerMin,)" `
        -Latest
    if ($ErrorIfNotFound -and ($instances | Measure-Object).Count -eq 0) {
        $err = ("There is no Visual Studio 2015 Update 3 or later with both " +
            "a) VS C++ x64/x86 build tools (Microsoft.VisualStudio.Component.VC.Tools.x86.x64) " +
            "B) Windows 10 SDK 18362 (Microsoft.VisualStudio.Component.Windows10SDK.18362)"
        )
        Write-Error $err
        exit 1
    }
    $instances
}
Export-ModuleMember -Function Get-CompatibleVisualStudio
