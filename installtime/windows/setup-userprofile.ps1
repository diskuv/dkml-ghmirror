<#
.Synopsis
    Set up all programs and data folders in $env:USERPROFILE.
.Description
    Blue Green Deployments
    ----------------------

    OCaml package directories, C header "include" directories and other critical locations are hardcoded
    into essential OCaml executables like `ocamlc.exe` during `opam switch create` and `opam install`.
    We are forced to create the Opam switch in its final resting place. But now we have a problem since
    we can never install a new Opam switch; it would have to be on top of the existing "final" Opam switch, right?
    Wrong, as long as we have two locations ... one to compile any new Opam switch and another to run
    user software; once the compilation is done we can change the PATH, OPAMSWITCH, etc. to use the new Opam switch.
    That old Opam switch can still be used; in fact OCaml applications like the OCaml Language Server may still
    be running. But once you logout all new OCaml applications will be launched using the new PATH environment
    variables, and it is safe to use that old location for the next compile.
    The technique above where we swap locations is called Blue Green deployments.

    We would use Blue Green deployments even if we didn't have that hard requirement because it is
    safe for you (the system is treated as one atomic whole).

    A side benefit is that the new system can be compiled while you are still working. Since
    new systems can take hours to build this is an important benefit.

    One last complication. Opam global switches are subdirectories of the Opam root; we cannot change their location
    use the swapping Blue Green deployment technique. So we _do not_ use an Opam global switch for `diskuv-system`.
    We use external (aka local) Opam switches instead.

    MSYS2
    -----

    After the script completes, you can launch MSYS2 directly with:

    & $env:DiskuvOCamlHome\tools\MSYS2\msys2_shell.cmd

    `.\makeit.cmd` from a local project is way better though.
.Parameter $ParentProgressId
    The PowerShell progress identifier. Optional, defaults to -1.
    Use when embedding this script within another setup program
    that reports its own progress.
.Parameter $SkipAutoUpgradeGitWhenOld
    Ordinarily if Git for Windows is installed on the machine but
    it is less than version 1.7.2 then Git for Windows 2.33.0 is
    installed which will replace the old version.

    Git 1.7.2 includes supports for git submodules that are necessary
    for Diskuv OCaml to work.

    Git for Windows is detected by running `git --version` from the
    PATH and checking to see if the version contains ".windows."
    like "git version 2.32.0.windows.2". Without this switch
    this script may detect a Git installation that is not Git for
    Windows, and you will end up installing an extra Git for Windows
    2.33.0 installation instead of upgrading the existing Git for
    Windows to 2.33.0.

    Even with this switch is selected, Git 2.33.0 will be installed
    if there is no Git available on the PATH.
.Parameter $AllowRunAsAdmin
    When specified you will be allowed to run this script using
    Run as Administrator.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
.Parameter $SkipProgress
    Do not use the progress user interface.
.Parameter $OnlyOutputCacheKey
    Only output the userprofile cache key. The cache key is 1-to-1 with
    the version of the Diskuv OCaml distribution.
.Parameter $ForceDeploymentSlot0
    Forces the blue-green deployer to use slot 0. Useful in CI situations.

.Example
    PS> vendor\diskuv-ocaml\installtime\windows\setup-userprofile.ps1

.Example
    PS> $global:SkipMSYS2Setup = $true ; $global:SkipCygwinSetup = $true; $global:SkipMSYS2Update = $true ; $global:SkipMobyDownload = $true ; $global:SkipMobyFixup = $true ; $global:SkipOpamSetup = $true
    PS> $global:IncrementalDiskuvOcamlDeployment = $true; $global:RedeployIfExists = $true
    PS> vendor\diskuv-ocaml\installtime\windows\setup-userprofile.ps1
#>

# Cygwin Rough Edges
# ------------------
#
# ALWAYS ALWAYS use Cygwin to create directories if they are _ever_ read from Cygwin.
# That is because Cygwin uses Windows ACLs attached to files and directories that
# native Windows executables and MSYS2 do not use. (See the 'BEGIN Remove extended ACL' script block)
#
# ONLY USE CYGWIN WITHIN THIS SCRIPT. See the above point about file permissions. If we limit
# the blast radius of launching Cygwin to this Powershell script, then we make auditing where
# file permissions are going wrong to one place (here!). AND we remove any possibility
# of Cygwin invoking MSYS which simply does not work by stipulating that Cygwin must only be used here.
#
# Troubleshooting: In Cygwin we can do 'setfacl -b ...' to remove extended ACL entries. (See https://cygwin.com/cygwin-ug-net/ov-new.html#ov-new2.4s)
# So `find build/ -print0 | xargs -0 --no-run-if-empty setfacl --remove-all --remove-default` would just leave ordinary
# POSIX permissions in the build/ directory (typically what we want!)

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification='Conditional block based on Windows 32 vs 64-bit',
    Target="CygwinPackagesArch")]
[CmdletBinding()]
param (
    [Parameter()]
    [int]
    $ParentProgressId = -1,
    [switch]
    $SkipAutoUpgradeGitWhenOld,
    [switch]
    $AllowRunAsAdmin,
    [switch]
    $SkipProgress,
    [switch]
    $OnlyOutputCacheKey,
    [switch]
    $ForceDeploymentSlot0,
    [switch]
    $StopBeforeCreateSystemSwitch
)

$ErrorActionPreference = "Stop"

$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
$DkmlPath = $HereDir.Parent.Parent.FullName
if (!(Test-Path -Path $DkmlPath\.dkmlroot)) {
    throw "Could not locate where this script was in the project. Thought DkmlPath was $DkmlPath"
}
$DkmlProps = ConvertFrom-StringData (Get-Content $DkmlPath\.dkmlroot -Raw)
$dkml_root_version = $DkmlProps.dkml_root_version

$PSDefaultParameterValues = @{'Out-File:Encoding' = 'utf8'} # for Tee-Object. https://stackoverflow.com/a/58920518

$env:PSModulePath += ";$HereDir"
Import-Module Deployers
Import-Module Project
Import-Module UnixInvokers
Import-Module Machine
Import-Module DeploymentVersion

# Make sure not Run as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ((-not $AllowRunAsAdmin) -and $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error -Category SecurityError `
        -Message "You are in an PowerShell Run as Administrator session. Please run $HereScript from a non-Administrator PowerShell session."
    exit 1
}

# We will use the same standard established by C:\Users\<user>\AppData\Local\Programs\Microsoft VS Code
$ProgramParentPath = "$env:LOCALAPPDATA\Programs\DiskuvOCaml"
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
if (!(Test-Path -Path $ProgramParentPath)) { New-Item -Path $ProgramParentPath -ItemType Directory | Out-Null }

# ----------------------------------------------------------------
# Prerequisite Check

# A. 64-bit check
if (!$global:Skip64BitCheck -and ![Environment]::Is64BitOperatingSystem) {
    # This might work on 32-bit Windows, but that hasn't been tested.
    # One missing item is whether there are 32-bit Windows ocaml/opam Docker images
    throw "DiskuvOCaml is only supported on 64-bit Windows"
}


# ----------------------------------------------------------------
# QUICK EXIT if already current version already deployed, or if -OnlyOutputCacheKey switch

# Magic constants that will identify new and existing deployments:
# * Immutable git tags
$NinjaVersion = "1.10.2"
$CMakeVersion = "3.21.1"
$JqVersion = "1.6"
$InotifyTag = "36d18f3dfe042b21d7136a1479f08f0d8e30e2f9"
$CygwinPackages = @("curl",
    "diff",
    "diffutils",
    "git",
    "m4",
    "make",
    "patch",
    "unzip",
    "python",
    "python3",
    "cmake",
    "cmake-gui",
    "ninja",
    "wget",
    # needed by this script (install-world.ps1)
    "dos2unix",
    # needed by Moby scripted Docker downloads (download-frozen-image-v2.sh)
    "jq")
if ([Environment]::Is64BitOperatingSystem) {
    $CygwinPackagesArch = $CygwinPackages + @("mingw64-x86_64-gcc-core",
    "mingw64-x86_64-gcc-g++",
    "mingw64-x86_64-headers",
    "mingw64-x86_64-runtime",
    "mingw64-x86_64-winpthreads")
}
else {
    $CygwinPackagesArch = $CygwinPackages + @("mingw64-i686-gcc-core",
        "mingw64-i686-gcc-g++",
        "mingw64-i686-headers",
        "mingw64-i686-runtime",
        "mingw64-i686-winpthreads")
}
$MSYS2Packages = @(
    # Hints:
    #  1. Use `MSYS2\msys2_shell.cmd -here` to launch MSYS2 and then `pacman -Ss diff` to
    #     search for example for 'diff' packages.
    #     You can also browse https://packages.msys2.org
    #  2. Instead of `pacman -Ss [search term]` you can use something like `pacman -Fy && pacman -F x86_64-w64-mingw32-as.exe`
    #     to find which package installs for example the `x86_64-w64-mingw32-as.exe` file.

    # ----
    # Needed to create native Opam executable in `opam-bootstrap`
    # ----

    # "mingw-w64-i686-openssl", "mingw-w64-x86_64-openssl",
    # "mingw-w64-i686-gcc", "mingw-w64-x86_64-gcc",
    # "mingw-w64-cross-binutils", "mingw-w64-cross-gcc"

    # ----
    # Needed by the Local Project's `Makefile`
    # ----

    "make",
    "diffutils",
    "dos2unix",

    # ----
    # Needed by Opam
    # ----

    "patch",
    "rsync",
    # We don't use C:\WINDOWS\System32\tar.exe even if it is available in all Windows SKUs since build
    # 17063 (https://docs.microsoft.com/en-us/virtualization/community/team-blog/2017/20171219-tar-and-curl-come-to-windows)
    # because get:
    #   ocamlbuild-0.14.0/examples/07-dependent-projects/libdemo: Can't create `..long path with too many backslashes..`# tar.exe: Error exit delayed from previous errors.
    #   MSYS2 seems to be able to deal with excessive backslashes
    "tar",
    "unzip",

    # ----
    # Needed by many OCaml packages during builds
    # ----

    # ----
    # Needed by OCaml package `feather`
    # ----

    "procps", # provides `pgrep`

    # ----
    # Needed for our own sanity!
    # ----

    "psmisc", # process management tools: `pstree`
    "rlwrap", # command line history for executables without builtin command line history support
    "tree" # directory structure viewer
)
if ([Environment]::Is64BitOperatingSystem) {
    $MSYS2PackagesArch = $MSYS2Packages + @(
        # ----
        # Needed for our own sanity!
        # ----

        "mingw-w64-x86_64-ag" # search tool called Silver Surfer
    )
} else {
    $MSYS2PackagesArch = $MSYS2Packages + @(
        # ----
        # Needed for our own sanity!
        # ----

        "mingw-w64-i686-ag" # search tool called Silver Surfer
    )
}
$DistributionPackages = @(
    "dune.2.9.0",
    # Really only for dkml_templatizer; may be used for creating local projects as well.
    # Would have used `shexp.0.14.0` but wasn't compiling on Windows because of Opam's complaint
    # that `posixat` had 'os != "win32"'
    "feather.0.3.0",
    # Really only for dkml_templatizer; may be used for creating local projects as well.
    "jingoo.1.4.3",
    "ocaml-lsp-server.1.7.0",
    "ocamlfind.1.9.1",
    "ocamlformat.0.19.0",
    "ocamlformat-rpc.0.19.0",
    "utop.2.8.0"
)
$DistributionBinaries = @(
    "dune.exe",
    "flexlink.exe",
    "ocaml.exe",
    "ocamlc.byte.exe",
    "ocamlc.exe",
    "ocamlc.opt.exe",
    "ocamlcmt.exe",
    "ocamlcp.byte.exe",
    "ocamlcp.exe",
    "ocamlcp.opt.exe",
    "ocamldebug.exe",
    "ocamldep.byte.exe",
    "ocamldep.exe",
    "ocamldep.opt.exe",
    "ocamldoc.exe",
    "ocamldoc.opt.exe",
    "ocamlfind.exe",
    "ocamlformat.exe",
    "ocamllex.byte.exe",
    "ocamllex.exe",
    "ocamllex.opt.exe",
    "ocamllsp.exe",
    "ocamlmklib.byte.exe",
    "ocamlmklib.exe",
    "ocamlmklib.opt.exe",
    "ocamlmktop.byte.exe",
    "ocamlmktop.exe",
    "ocamlmktop.opt.exe",
    "ocamlobjinfo.byte.exe",
    "ocamlobjinfo.exe",
    "ocamlobjinfo.opt.exe",
    "ocamlopt.byte.exe",
    "ocamlopt.exe",
    "ocamlopt.opt.exe",
    "ocamloptp.byte.exe",
    "ocamloptp.exe",
    "ocamloptp.opt.exe",
    "ocamlprof.byte.exe",
    "ocamlprof.exe",
    "ocamlprof.opt.exe",
    "ocamlrun.exe",
    "ocamlrund.exe",
    "ocamlruni.exe",
    "ocamlyacc.exe",
    "ocp-indent.exe",
    "utop.exe",
    "utop-full.exe")

# Consolidate the magic constants into a single deployment id
$CygwinHash = Get-Sha256Hex16OfText -Text ($CygwinPackagesArch -join ',')
$MSYS2Hash = Get-Sha256Hex16OfText -Text ($MSYS2PackagesArch -join ',')
$DockerHash = Get-Sha256Hex16OfText -Text "$DV_WindowsMsvcDockerImage"
$PackagesHash = Get-Sha256Hex16OfText -Text ($DistributionPackages -join ',')
$BinariesHash = Get-Sha256Hex16OfText -Text ($DistributionBinaries -join ',')
$DeploymentId = "opam-$DV_AvailableOpamVersion;ninja-$NinjaVersion;cmake-$CMakeVersion;jq-$JqVersion;inotify-$InotifyTag;cygwin-$CygwinHash;msys2-$MSYS2Hash;docker-$DockerHash;pkgs-$PackagesHash;bins-$BinariesHash"

if ($OnlyOutputCacheKey) {
    Write-Output $DeploymentId
    return
}

# Check if already deployed
$finished = Get-BlueGreenDeployIsFinished -ParentPath $ProgramParentPath -DeploymentId $DeploymentId
# Advanced. Skip check with ... $global:RedeployIfExists = $true ... remove it with ... Remove-Variable RedeployIfExists
if (!$global:RedeployIfExists -and $finished) {
    Write-Host "$DeploymentId already deployed."
    Write-Host "Enjoy Diskuv OCaml!"
    return
}

# ----------------------------------------------------------------
# Utilities

function Import-DiskuvOCamlAsset {
    param (
        [Parameter(Mandatory)]
        $PackageName,
        [Parameter(Mandatory)]
        $ZipFile,
        [Parameter(Mandatory)]
        $TmpPath,
        [Parameter(Mandatory)]
        $DestinationPath
    )
    try {
        $uri = "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/$PackageName/v$dkml_root_version/$ZipFile"
        Write-ProgressCurrentOperation -CurrentOperation "Downloading asset $uri"
        Invoke-WebRequest `
            -Uri "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/$PackageName/v$dkml_root_version/$ZipFile" `
            -OutFile "$TmpPath\$ZipFile"
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        Write-ProgressCurrentOperation -CurrentOperation "HTTP ${StatusCode}: $uri"
        if ($StatusCode -eq 404) {
            # 404 Not Found
            return $false
        }
        throw
    }
    Expand-Archive -Path "$TmpPath\$ZipFile" -DestinationPath $DestinationPath -Force
    $true
}

# ----------------------------------------------------------------
# Progress declarations

$global:ProgressStep = 0
$global:ProgressActivity = $null
$ProgressTotalSteps = 18
$ProgressId = $ParentProgressId + 1
$global:ProgressStatus = $null

function Get-CurrentTimestamp {
    (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffK")
}
function Write-ProgressStep {
    if (-not $SkipProgress) {
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
    } else {
        Write-Host -ForegroundColor DarkGreen "[$(1 + $global:ProgressStep) of $ProgressTotalSteps]: $(Get-CurrentTimestamp) $($global:ProgressActivity)"
    }
    $global:ProgressStep += 1
}
function Write-ProgressCurrentOperation {
    param(
        $CurrentOperation
    )
    if ($SkipProgress) {
        Write-Host "$(Get-CurrentTimestamp) $CurrentOperation"
    } else {
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -Status $global:ProgressStatus `
            -CurrentOperation $CurrentOperation `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
    }
}

# ----------------------------------------------------------------
# BEGIN Visual Studio Setup PowerShell Module

$global:ProgressActivity = "Install Visual Studio Setup PowerShell Module"
Write-ProgressStep

Import-VSSetup -TempPath "$env:TEMP\vssetup"
$CompatibleVisualStudios = Get-CompatibleVisualStudios -ErrorIfNotFound
$ChosenVisualStudio = ($CompatibleVisualStudios | Select-Object -First 1)
$VisualStudioProps = Get-VisualStudioProperties -VisualStudioInstallation $ChosenVisualStudio
$VisualStudioDirPath = "$ProgramParentPath\vsstudio.dir.txt"
$VisualStudioJsonPath = "$ProgramParentPath\vsstudio.json"
$VisualStudioVcVarsVerPath = "$ProgramParentPath\vsstudio.vcvars_ver.txt"
$VisualStudioMsvsPreferencePath = "$ProgramParentPath\vsstudio.msvs_preference.txt"
[System.IO.File]::WriteAllText($VisualStudioDirPath, "$($VisualStudioProps.InstallPath)", $Utf8NoBomEncoding)
[System.IO.File]::WriteAllText($VisualStudioJsonPath, ($CompatibleVisualStudios | ConvertTo-Json), $Utf8NoBomEncoding)
[System.IO.File]::WriteAllText($VisualStudioVcVarsVerPath, "$($VisualStudioProps.VcVarsVer)", $Utf8NoBomEncoding)
[System.IO.File]::WriteAllText($VisualStudioMsvsPreferencePath, "$($VisualStudioProps.MsvsPreference)", $Utf8NoBomEncoding)

# END Visual Studio Setup PowerShell Module
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Git for Windows

# Git is _not_ part of the Diskuv OCaml distribution per se; it is
# is a prerequisite that gets auto-installed. Said another way,
# it does not get a versioned installation like the rest of Diskuv
# OCaml. So we explicitly do version checks during the installation of
# Git.

$global:ProgressActivity = "Install Git for Windows"
Write-ProgressStep

$GitWindowsSetupAbsPath = "$env:TEMP\gitwindows"

$GitOriginalVersion = @(0, 0, 0)
$SkipGitForWindowsInstallBecauseNonGitForWindowsDetected = $false
$GitExists = $false

$oldeap = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
$GitExe = & where.exe git 2> $null
$ErrorActionPreference = oldeap

if ($LastExitCode -eq 0) {
    $GitExists = $true
    $GitResponse = & $GitExe --version
    if ($LastExitCode -eq 0) {
        # git version 2.32.0.windows.2 -> 2.32.0.windows.2
        $GitResponseLast = $GitResponse.Split(" ")[-1]
        # 2.32.0.windows.2 -> 2 32 0
        $GitOriginalVersion = $GitResponseLast.Split(".")[0, 1, 2]
        # check for '.windows.'
        $SkipGitForWindowsInstallBecauseNonGitForWindowsDetected = $GitResponse -notlike "*.windows.*"
    }
}
if (-not $SkipGitForWindowsInstallBecauseNonGitForWindowsDetected) {
    # Less than 1.7.2?
    $GitTooOld = ($GitOriginalVersion[0] -lt 1 -or
        ($GitOriginalVersion[0] -eq 1 -and $GitOriginalVersion[1] -lt 7) -or
        ($GitOriginalVersion[0] -eq 1 -and $GitOriginalVersion[1] -eq 7 -and $GitOriginalVersion[2] -lt 2))
    if ((-not $GitExists) -or ($GitTooOld -and -not $SkipAutoUpgradeGitWhenOld)) {
        # Install Git for Windows 2.33.0

        if ([Environment]::Is64BitOperatingSystem) {
            $GitWindowsBits = "64"
        } else {
            $GitWindowsBits = "32"
        }
        if (!(Test-Path -Path $GitWindowsSetupAbsPath)) { New-Item -Path $GitWindowsSetupAbsPath -ItemType Directory | Out-Null }
        if (!(Test-Path -Path $GitWindowsSetupAbsPath\Git-2.33.0-$GitWindowsBits-bit.exe)) { Invoke-WebRequest -Uri https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.1/Git-2.33.0-$GitWindowsBits-bit.exe -OutFile $GitWindowsSetupAbsPath\Git-2.33.0-$GitWindowsBits-bit.exe }

        # You can see the arguments if you run: Git-2.33.0-$GitWindowsArch-bit.exe /?
        # https://jrsoftware.org/ishelp/index.php?topic=setupcmdline has command line options.
        # https://github.com/git-for-windows/build-extra/tree/main/installer has installer source code.
        $proc = Start-Process -FilePath "$GitWindowsSetupAbsPath\Git-2.33.0-$GitWindowsBits-bit.exe" -NoNewWindow -Wait -PassThru `
            -ArgumentList @("/SP-", "/SILENT", "/SUPPRESSMSGBOXES", "/CURRENTUSER", "/NORESTART")
        $exitCode = $proc.ExitCode
        if ($exitCode -ne 0) {
            Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $global:ProgressActivity -Completed
            $ErrorActionPreference = "Continue"
            Write-Error "Git installer failed"
            Remove-Item "$GitWindowsSetupAbsPath" -Recurse -Force
            Start-Sleep 5
            Write-Host ''
            Write-Host 'One reason why the Git installer will fail is because you did not'
            Write-Host 'click "Yes" when it asks you to allow the installation.'
            Write-Host 'You can try to rerun the script.'
            Write-Host ''
            Write-Host 'Press any key to exit this script...';
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            throw
        }

        # Get new PATH so we can locate the new Git
        $OldPath = $env:PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $oldeap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $GitExe = & where.exe git
        $ErrorActionPreference = $oldeap
        if ($LastExitCode -ne 0) {
            throw "DiskuvOCaml requires that Git is installed in the PATH. The Git installer failed to do so. Please install it manually from https://gitforwindows.org/"
        }
        $env:PATH = $OldPath
    }
}
if (Test-Path -Path "$GitWindowsSetupAbsPath") {
    Remove-Item -Path "$GitWindowsSetupAbsPath" -Recurse -Force
}

$GitPath = (get-item "$GitExe").Directory.FullName

# END Git for Windows
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Start deployment

# We do support incremental deployments but for user safety we don't enable it by default;
# it is really here to help the maintainers of DiskuvOcaml rapidly develop new deployment ids.
# Use `$global:IncrementalDiskuvOcamlDeployment = $true` to enable incremental deployments.
# Use `Remove-Variable IncrementalDiskuvOcamlDeployment` to remove the override.
$EnableIncrementalDeployment = $global:IncrementalDiskuvOcamlDeployment -and $true

$global:ProgressStatus = "Starting Deployment"
if ($ForceDeploymentSlot0) { $FixedSlotIdx = 0 } else { $FixedSlotIdx = $null }
$ProgramPath = Start-BlueGreenDeploy -ParentPath $ProgramParentPath `
    -DeploymentId $DeploymentId `
    -FixedSlotIdx:$FixedSlotIdx `
    -KeepOldDeploymentWhenSameDeploymentId:$EnableIncrementalDeployment `
    -LogFunction ${function:\Write-ProgressCurrentOperation}
$DeploymentMark = "[$DeploymentId]"

# We also use "deployments" for any temporary directory we need since the
# deployment process handles an aborted setup and the necessary cleaning up of disk
# space (eventually).
$TempParentPath = "$Env:temp\diskuvocaml\setupuserprofile"
$TempPath = Start-BlueGreenDeploy -ParentPath $TempParentPath `
    -DeploymentId $DeploymentId `
    -KeepOldDeploymentWhenSameDeploymentId:$EnableIncrementalDeployment `
    -LogFunction ${function:\Write-ProgressCurrentOperation}

# END Start deployment
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Enhanced Progress Reporting

$AuditLog = Join-Path -Path $ProgramPath -ChildPath "setup-userprofile.full.log"
if (Test-Path -Path $AuditLog) {
    # backup the original
    Rename-Item -Path $AuditLog -NewName "setup-userprofile.backup.log"
}

function Invoke-Win32CommandWithProgress {
    param (
        [Parameter(Mandatory=$true)]
        $FilePath,
        $ArgumentList
    )
    if ($null -eq $ArgumentList) {  $ArgumentList = @() }
    # Append what we will do into $AuditLog
    $Command = "$FilePath $($ArgumentList -join ' ')"
    $what = "[Win32] $Command"
    Add-Content -Path $AuditLog -Value "$(Get-CurrentTimestamp) $what" -Encoding UTF8

    if ($SkipProgress) {
        Write-ProgressCurrentOperation -CurrentOperation $what
        $oldeap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        # `ForEach-Object ToString` so that System.Management.Automation.ErrorRecord are sent to Tee-Object as well
        & $FilePath @ArgumentList 2>&1 | ForEach-Object ToString | Tee-Object -FilePath $AuditLog -Append
        $ErrorActionPreference = $oldeap
        if ($LastExitCode -ne 0) {
            throw "Win32 command failed! Exited with $LastExitCode. Command was: $Command."
        }
    } else {
        $global:ProgressStatus = $what
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -Status $what `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))

        $RedirectStandardOutput = New-TemporaryFile
        $RedirectStandardError = New-TemporaryFile
        try {
            $proc = Start-Process -FilePath $FilePath `
                -NoNewWindow `
                -RedirectStandardOutput $RedirectStandardOutput `
                -RedirectStandardError $RedirectStandardError `
                -ArgumentList $ArgumentList `
                -PassThru
            $handle = $proc.Handle # cache proc.Handle https://stackoverflow.com/a/23797762/1479211
            while (-not $proc.HasExited) {
                if (-not $SkipProgress) {
                    $tail = Get-Content -Path $RedirectStandardOutput -Tail $InvokerTailLines
                    Write-ProgressCurrentOperation $tail
                }
                Start-Sleep -Seconds $InvokerTailRefreshSeconds
            }
            $proc.WaitForExit()
            $exitCode = $proc.ExitCode
            if ($exitCode -ne 0) {
                $err = Get-Content -Path $RedirectStandardError
                throw "Win32 command failed! Exited with $exitCode. Command was: $Command.`nError was: $err"
            }
        }
        finally {
            if ($null -ne $RedirectStandardOutput -and (Test-Path $RedirectStandardOutput)) {
                if ($AuditLog) { Add-Content -Path $AuditLog -Value (Get-Content -Path $RedirectStandardOutput) -Encoding UTF8 }
                Remove-Item $RedirectStandardOutput -Force -ErrorAction Continue
            }
            if ($null -ne $RedirectStandardError -and (Test-Path $RedirectStandardError)) {
                if ($AuditLog) { Add-Content -Path $AuditLog -Value (Get-Content -Path $RedirectStandardError) -Encoding UTF8 }
                Remove-Item $RedirectStandardError -Force -ErrorAction Continue
            }
        }
    }
}
function Invoke-CygwinCommandWithProgress {
    param (
        [Parameter(Mandatory=$true)]
        $Command,
        [Parameter(Mandatory=$true)]
        $CygwinDir,
        $CygwinName = "cygwin"
    )
    # Append what we will do into $AuditLog
    $what = "[$CygwinName] $Command"
    Add-Content -Path $AuditLog -Value "$(Get-CurrentTimestamp) $what" -Encoding UTF8

    if ($SkipProgress) {
        Write-ProgressCurrentOperation -CurrentOperation "$what"
        Invoke-CygwinCommand -Command $Command -CygwinDir $CygwinDir `
            -AuditLog $AuditLog
    } else {
        $global:ProgressStatus = $what
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -Status $what `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
        Invoke-CygwinCommand -Command $Command -CygwinDir $CygwinDir `
            -AuditLog $AuditLog `
            -TailFunction ${function:\Write-ProgressCurrentOperation}
    }
}
function Invoke-MSYS2CommandWithProgress {
    param (
        [Parameter(Mandatory=$true)]
        $Command,
        [Parameter(Mandatory=$true)]
        $MSYS2Dir,
        [switch]
        $ForceConsole,
        [switch]
        $IgnoreErrors
    )
    # Add Git to path
    $GitMSYS2AbsPath = & $MSYS2Dir\usr\bin\cygpath.exe -au "$GitPath"
    $Command = "export PATH='$($GitMSYS2AbsPath)':`"`$PATH`" && $Command"

    # Append what we will do into $AuditLog
    $what = "[MSYS2] $Command"
    Add-Content -Path $AuditLog -Value "$(Get-CurrentTimestamp) $what" -Encoding UTF8

    if ($ForceConsole) {
        if (-not $SkipProgress) {
            Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $global:ProgressActivity -Completed
        }
        Invoke-MSYS2Command -Command $Command -MSYS2Dir $MSYS2Dir -IgnoreErrors:$IgnoreErrors
    } elseif ($SkipProgress) {
        Write-ProgressCurrentOperation -CurrentOperation "$what"
        Invoke-MSYS2Command -Command $Command -MSYS2Dir $MSYS2Dir -IgnoreErrors:$IgnoreErrors `
            -AuditLog $AuditLog
    } else {
        $global:ProgressStatus = $what
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -Status $global:ProgressStatus `
            -CurrentOperation $Command `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
        Invoke-MSYS2Command -Command $Command -MSYS2Dir $MSYS2Dir `
            -AuditLog $AuditLog `
            -IgnoreErrors:$IgnoreErrors `
            -TailFunction ${function:\Write-ProgressCurrentOperation}
    }
}

# From here on we need to stuff $ProgramPath with all the binaries for the distribution
# VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV

# Notes:
# * Include lots of `TestPath` existence tests to speed up incremental deployments.

$global:AdditionalDiagnostics = "`n`n"
try {

    # ----------------------------------------------------------------
    # BEGIN inotify-win

    $global:ProgressActivity = "Install inotify-win"
    Write-ProgressStep

    $Vcvars = "$($VisualStudioProps.InstallPath)\Common7\Tools\vsdevcmd.bat"
    $InotifyCacheParentPath = "$TempPath"
    $InotifyCachePath = "$InotifyCacheParentPath\inotify-win"
    $InotifyExeBasename = "inotifywait.exe"
    $InotifyToolDir = "$ProgramPath\tools\inotify-win"
    $InotifyExe = "$InotifyToolDir\$InotifyExeBasename"
    if (!(Test-Path -Path $InotifyExe)) {
        if (!(Test-Path -Path $InotifyToolDir)) { New-Item -Path $InotifyToolDir -ItemType Directory | Out-Null }
        if (Test-Path -Path $InotifyCachePath) { Remove-Item -Path $InotifyCachePath -Recurse -Force }
        Invoke-Win32CommandWithProgress -FilePath "$GitExe" -ArgumentList @("-C", "$InotifyCacheParentPath", "clone", "https://github.com/thekid/inotify-win.git")
        Invoke-Win32CommandWithProgress -FilePath "$GitExe" -ArgumentList @("-C", "$InotifyCachePath", "-c", "advice.detachedHead=false", "checkout", "$InotifyTag")
        Invoke-Win32CommandWithProgress -FilePath cmd.exe -ArgumentList @("/c", "`"$Vcvars`" -no_logo -vcvars_ver=$($VisualStudioProps.VcVarsVer) && csc.exe /nologo /target:exe `"/out:$InotifyCachePath\inotifywait.exe`" `"$InotifyCachePath\src\*.cs`"")
        Copy-Item -Path "$InotifyCachePath\$InotifyExeBasename" -Destination "$InotifyExe"
        # if (-not $SkipProgress) { Clear-Host }
    }

    # END inotify-win
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN Ninja

    $global:ProgressActivity = "Install Ninja"
    Write-ProgressStep

    $NinjaCachePath = "$TempPath\ninja"
    $NinjaZip = "$NinjaCachePath\ninja-win.zip"
    $NinjaExeBasename = "ninja.exe"
    $NinjaToolDir = "$ProgramPath\tools\ninja"
    $NinjaExe = "$NinjaToolDir\$NinjaExeBasename"
    if (!(Test-Path -Path $NinjaExe)) {
        if (!(Test-Path -Path $NinjaToolDir)) { New-Item -Path $NinjaToolDir -ItemType Directory | Out-Null }
        if (!(Test-Path -Path $NinjaCachePath)) { New-Item -Path $NinjaCachePath -ItemType Directory | Out-Null }
        Invoke-WebRequest -Uri "https://github.com/ninja-build/ninja/releases/download/v$NinjaVersion/ninja-win.zip" -OutFile "$NinjaZip"
        Expand-Archive -Path $NinjaZip -DestinationPath $NinjaCachePath
        Remove-Item -Path $NinjaZip
        Copy-Item -Path "$NinjaCachePath\$NinjaExeBasename" -Destination "$NinjaExe"
    }

    # END Ninja
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN CMake

    $global:ProgressActivity = "Install CMake"
    Write-ProgressStep

    $CMakeCachePath = "$TempPath\cmake"
    $CMakeZip = "$CMakeCachePath\cmake.zip"
    $CMakeToolDir = "$ProgramPath\tools\cmake"
    if (!(Test-Path -Path "$CMakeToolDir\bin\cmake.exe")) {
        if (!(Test-Path -Path $CMakeToolDir)) { New-Item -Path $CMakeToolDir -ItemType Directory | Out-Null }
        if (!(Test-Path -Path $CMakeCachePath)) { New-Item -Path $CMakeCachePath -ItemType Directory | Out-Null }
        if ([Environment]::Is64BitOperatingSystem) {
            $CMakeDistType = "x86_64"
        } else {
            $CMakeDistType = "i386"
        }
        Invoke-WebRequest -Uri "https://github.com/Kitware/CMake/releases/download/v$CMakeVersion/cmake-$CMakeVersion-windows-$CMakeDistType.zip" -OutFile "$CMakeZip"
        Expand-Archive -Path $CMakeZip -DestinationPath $CMakeCachePath
        Remove-Item -Path $CMakeZip
        Copy-Item -Path "$CMakeCachePath\cmake-$CMakeVersion-windows-$CMakeDistType\*" `
            -Recurse `
            -Destination $CMakeToolDir
    }


    # END CMake
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN jq

    $global:ProgressActivity = "Install jq"
    Write-ProgressStep

    $JqExeBasename = "jq.exe"
    $JqToolDir = "$ProgramPath\tools\jq"
    $JqExe = "$JqToolDir\$JqExeBasename"
    if (!(Test-Path -Path $JqExe)) {
        if (!(Test-Path -Path $JqToolDir)) { New-Item -Path $JqToolDir -ItemType Directory | Out-Null }
        if ([Environment]::Is64BitOperatingSystem) {
            $JqDistType = "win64"
        } else {
            $JqDistType = "win32"
        }
        Invoke-WebRequest -Uri "https://github.com/stedolan/jq/releases/download/jq-$JqVersion/jq-$JqDistType.exe" -OutFile "$JqExe.tmp"
        Rename-Item -Path "$JqExe.tmp" -NewName "$JqExeBasename"
    }

    # END jq
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN Cygwin

    $CygwinRootPath = "$ProgramPath\tools\cygwin"

    function Invoke-CygwinSyncScript {
        param (
            $CygwinDir = $CygwinRootPath
        )

        # Create /opt/diskuv-ocaml/installtime/ which is specific to Cygwin with common pieces from UNIX.
        $cygwinAbsPath = & $CygwinDir\bin\cygpath.exe -au "$DkmlPath"
        Invoke-CygwinCommandWithProgress -CygwinDir $CygwinDir -Command "/usr/bin/install -d /opt/diskuv-ocaml/installtime && /usr/bin/rsync -a --delete '$cygwinAbsPath'/installtime/cygwin/ '$cygwinAbsPath'/installtime/unix/ /opt/diskuv-ocaml/installtime/ && /usr/bin/find /opt/diskuv-ocaml/installtime/ -type f | /usr/bin/xargs /usr/bin/chmod +x"

        # Run through dos2unix which is only installed in $CygwinRootPath
        $dkmlSetupCygwinAbsMixedPath = & $CygwinDir\bin\cygpath.exe -am "/opt/diskuv-ocaml/installtime/"
        Invoke-CygwinCommandWithProgress -CygwinDir $CygwinRootPath -Command "/usr/bin/find '$dkmlSetupCygwinAbsMixedPath' -type f | /usr/bin/xargs /usr/bin/dos2unix --quiet"
    }

    function Invoke-CygwinInitialization {
        $global:ProgressActivity = "Install Cygwin"
        Write-ProgressStep
    }

    function Install-Cygwin {
        Invoke-CygwinInitialization

        # Much of the remainder of the 'Cygwin' section is modified from
        # https://github.com/esy/esy-bash/blob/master/build-cygwin.js

        $CygwinCachePath = "$TempPath\cygwin"
        if ([Environment]::Is64BitOperatingSystem) {
            $CygwinSetupExeBasename = "setup-x86_64.exe"
            $CygwinDistType = "x86_64"
        } else {
            $CygwinSetupExeBasename = "setup-x86.exe"
            $CygwinDistType = "x86"
        }
        $CygwinSetupExe = "$CygwinCachePath\$CygwinSetupExeBasename"
        if (!(Test-Path -Path $CygwinCachePath)) { New-Item -Path $CygwinCachePath -ItemType Directory | Out-Null }
        if (!(Test-Path -Path $CygwinSetupExe)) {
            Invoke-WebRequest -Uri "https://cygwin.com/$CygwinSetupExeBasename" -OutFile "$CygwinSetupExe.tmp"
            Rename-Item -Path "$CygwinSetupExe.tmp" "$CygwinSetupExeBasename"
        }

        $CygwinSetupCachePath = "$CygwinRootPath\var\cache\setup"
        if (!(Test-Path -Path $CygwinSetupCachePath)) { New-Item -Path $CygwinSetupCachePath -ItemType Directory | Out-Null }

        $CygwinMirror = "http://cygwin.mirror.constant.com"

        # Skip with ... $global:SkipCygwinSetup = $true ... remove it with ... Remove-Variable SkipCygwinSetup
        if (!$global:SkipCygwinSetup -or (-not (Test-Path "$CygwinRootPath\bin\mintty.exe"))) {
            # https://cygwin.com/faq/faq.html#faq.setup.cli
            $CommonCygwinMSYSOpts = "-qWnNdOfgoB"
            Invoke-Win32CommandWithProgress -FilePath $CygwinSetupExe `
                -ArgumentList $CommonCygwinMSYSOpts, "-a", $CygwinDistType, "-R", $CygwinRootPath, "-s", $CygwinMirror, "-l", $CygwinSetupCachePath, "-P", ($CygwinPackagesArch -join ",")
        }

        $global:AdditionalDiagnostics += "[Advanced] DiskuvOCaml Cygwin commands can be run with: $CygwinRootPath\bin\mintty.exe -`n"

        # Create home directories
        Invoke-CygwinCommandWithProgress -CygwinDir $CygwinRootPath -Command "exit 0"

        # Create /opt/diskuv-ocaml/installtime/ which is specific to Cygwin with common pieces from UNIX
        Invoke-CygwinSyncScript
    }

    # END Cygwin
    # ----------------------------------------------------------------

    if (Test-Path -Path "$ProgramPath\share\diskuv-ocaml\ocaml-opam-repo\repo") {
        Invoke-CygwinInitialization
    } elseif (Import-DiskuvOCamlAsset `
            -PackageName "ocaml_opam_repo-reproducible" `
            -ZipFile "ocaml-opam-repo.zip" `
            -TmpPath "$TempPath" `
            -DestinationPath "$ProgramPath\share\diskuv-ocaml\ocaml-opam-repo") {
        Invoke-CygwinInitialization
    } else {
        Install-Cygwin

        # ----------------------------------------------------------------
        # BEGIN Define temporary dkmlvars for Cygwin only

        # dkmlvars.* (DiskuvOCaml variables) are scripts that set variables about the deployment.
        $ProgramCygwinAbsPath = & $CygwinRootPath\bin\cygpath.exe -au "$ProgramPath"
        $CygwinVarsArray = @(
            "DiskuvOCamlVarsVersion=1",
            "DiskuvOCamlHome='$ProgramCygwinAbsPath'",
            "DiskuvOCamlBinaryPaths='$ProgramCygwinAbsPath/bin'"
        )
        $CygwinVarsContents = $CygwinVarsArray -join [environment]::NewLine
        $CygwinVarsContentsOnOneLine = $CygwinVarsArray -join " "

        # END Define temporary dkmlvars for Cygwin only
        # ----------------------------------------------------------------

        # ----------------------------------------------------------------
        # BEGIN Fetch/install fdopen-based ocaml/opam repository

        $global:ProgressActivity = "Install fdopen-based ocaml/opam repository"
        Write-ProgressStep

        $DkmlCygwinAbsPath = & $CygwinRootPath\bin\cygpath.exe -au "$DkmlPath"

        $OcamlOpamRootPath = "$ProgramPath\tools\ocaml-opam"
        $MobyPath = "$TempPath\moby"
        $OcamlOpamRootCygwinAbsPath = & $CygwinRootPath\bin\cygpath.exe -au "$OcamlOpamRootPath"
        $MobyCygwinAbsPath = & $CygwinRootPath\bin\cygpath.exe -au "$MobyPath"

        # Q: Why download with Cygwin rather than MSYS? Ans: The Moby script uses `jq` which has shell quoting failures when run with MSYS `jq`.
        #
        if (!$global:SkipMobyDownload) {
            Invoke-CygwinCommandWithProgress -CygwinDir $CygwinRootPath `
                -Command "env $CygwinVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps /opt/diskuv-ocaml/installtime/private/install-ocaml-opam-repo.sh '$DkmlCygwinAbsPath' '$DV_WindowsMsvcDockerImage' '$ProgramCygwinAbsPath'"
        }

        # END Fetch/install fdopen-based ocaml/opam repository
        # ----------------------------------------------------------------
    }

    # ----------------------------------------------------------------
    # BEGIN MSYS2

    $global:ProgressActivity = "Install MSYS2"
    Write-ProgressStep

    $MSYS2ParentDir = "$ProgramPath\tools"
    $MSYS2Dir = "$MSYS2ParentDir\MSYS2"
    $MSYS2CachePath = "$TempPath\MSYS2"
    if ([Environment]::Is64BitOperatingSystem) {
        # The "base" installer is friendly for CI (ex. GitLab CI).
        # The non-base installer will not work in CI. Will get exit code -1073741515 (0xFFFFFFFFC0000135)
        # which is STATUS_DLL_NOT_FOUND; likely a graphical DLL is linked that is not present in headless
        # Windows Server based CI systems.
        $MSYS2SetupExeBasename = "msys2-base-x86_64-20210725.sfx.exe"
        $MSYS2UrlPath = "2021-07-25/msys2-base-x86_64-20210725.sfx.exe"
        $MSYS2Sha256 = "43c09824def2b626ff187c5b8a0c3e68c1063e7f7053cf20854137dc58f08592"
        $MSYS2BaseSubdir = "msys64"
        $MSYS2IsBase = $true
    } else {
        # There is no 32-bit base installer, so have to use the automated but graphical installer.
        $MSYS2SetupExeBasename = "msys2-i686-20200517.exe"
        $MSYS2UrlPath = "2020-05-17/msys2-i686-20200517.exe"
        $MSYS2Sha256 = "e478c521d4849c0e96cf6b4a0e59fe512b6a96aa2eb00388e77f8f4bc8886794"
        $MSYS2IsBase = $false
    }
    $MSYS2SetupExe = "$MSYS2CachePath\$MSYS2SetupExeBasename"

    # Skip with ... $global:SkipMSYS2Setup = $true ... remove it with ... Remove-Variable SkipMSYS2Setup
    if (!$global:SkipMSYS2Setup) {
        # https://github.com/msys2/msys2-installer#cli-usage-examples
        if (!(Test-Path "$MSYS2Dir\msys2.exe")) {
            # download and verify installer
            if (!(Test-Path -Path $MSYS2CachePath)) { New-Item -Path $MSYS2CachePath -ItemType Directory | Out-Null }
            if (!(Test-Path -Path $MSYS2SetupExe)) {
                Invoke-WebRequest -Uri "https://github.com/msys2/msys2-installer/releases/download/$MSYS2UrlPath" -OutFile "$MSYS2SetupExe.tmp"
                $MSYS2ActualHash = (Get-FileHash -Algorithm SHA256 "$MSYS2SetupExe.tmp").Hash
                if ("$MSYS2Sha256" -ne "$MSYS2ActualHash") {
                    throw "The MSYS2 installer was corrupted. You will need to retry the installation. If this repeatedly occurs, please send an email to support@diskuv.com"
                }
                Rename-Item -Path "$MSYS2SetupExe.tmp" "$MSYS2SetupExeBasename"
            }

            # remove directory, especially important so possible subsequent Rename-Item to work
            if (Test-Path -Path $MSYS2Dir) { Remove-Item -Path $MSYS2Dir -Recurse -Force }

            if ($MSYS2IsBase) {
                # extract
                if ($null -eq $MSYS2BaseSubdir) { throw "check_state MSYS2BaseSubdir is not null"}
                if (Test-Path -Path "$MSYS2ParentDir\$MSYS2BaseSubdir") { Remove-Item -Path "$MSYS2ParentDir\$MSYS2BaseSubdir" -Recurse -Force }
                Invoke-Win32CommandWithProgress -FilePath $MSYS2SetupExe -ArgumentList "-y", "-o$MSYS2ParentDir"

                # rename to MSYS2
                Rename-Item -Path "$MSYS2ParentDir\$MSYS2BaseSubdir" -NewName "MSYS2"
            } else {
                if (!(Test-Path -Path $MSYS2Dir)) { New-Item -Path $MSYS2Dir -ItemType Directory | Out-Null }
                Invoke-Win32CommandWithProgress -FilePath $MSYS2SetupExe -ArgumentList "in", "--confirm-command", "--accept-messages", "--root", $MSYS2Dir
            }
        }
    }

    $global:AdditionalDiagnostics += "[Advanced] MSYS2 commands can be run with: $MSYS2Dir\msys2_shell.cmd`n"

    # Create home directories and other files and settings
    # A: Use patches from https://patchew.org/QEMU/20210709075218.1796207-1-thuth@redhat.com/
    ((Get-Content -path $MSYS2Dir\etc\post-install\07-pacman-key.post -Raw) -replace '--refresh-keys', '--version') |
        Set-Content -Path $MSYS2Dir\etc\post-install\07-pacman-key.post # A
    Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir -IgnoreErrors `
        -Command ("true") # the first time will exit with `mkdir: cannot change permissions of /dev/shm` but will otherwise set all the directories correctly
    Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
        -Command ("sed -i 's/^CheckSpace/#CheckSpace/g' /etc/pacman.conf") # A

    # Synchronize packages
    #
    # Skip with ... $global:SkipMSYS2Update = $true ... remove it with ... Remove-Variable SkipMSYS2Update
    if (!$global:SkipMSYS2Update) {
        # Pacman does not update individual packages but rather the full system is upgraded. We _must_
        # upgrade the system before installing packages. Confer:
        # https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported
        # One more edge case ...
        #   :: Processing package changes...
        #   upgrading msys2-runtime...
        #   upgrading pacman...
        #   :: To complete this update all MSYS2 processes including this terminal will be closed. Confirm to proceed [Y/n] SUCCESS: The process with PID XXXXX has been terminated.
        # ... when pacman decides to upgrade itself, it kills all the MSYS2 processes. So we need to run at least
        # once and ignore any errors from forcible termination.
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir -IgnoreErrors `
            -Command ("pacman -Syu --noconfirm")
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
            -Command ("pacman -Syu --noconfirm")

        # Install new packages and/or full system if any were not installed ("--needed")
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
            -Command ("pacman -S --needed --noconfirm " + ($MSYS2PackagesArch -join " "))
    }

    # Create /opt/diskuv-ocaml/installtime/ which is specific to MSYS2 with common pieces from UNIX.
    # Run through dos2unix.
    $DkmlMSYS2AbsPath = & $MSYS2Dir\usr\bin\cygpath.exe -au "$DkmlPath"
    Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
        -Command ("/usr/bin/install -d /opt/diskuv-ocaml/installtime && " +
        "/usr/bin/rsync -a --delete '$DkmlMSYS2AbsPath'/installtime/msys2/ '$DkmlMSYS2AbsPath'/installtime/unix/ /opt/diskuv-ocaml/installtime/ && " +
        "/usr/bin/find /opt/diskuv-ocaml/installtime/ -type f | /usr/bin/xargs /usr/bin/dos2unix --quiet && " +
        "/usr/bin/find /opt/diskuv-ocaml/installtime/ -type f | /usr/bin/xargs /usr/bin/chmod +x")


    # END MSYS2
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN Define dkmlvars

    # dkmlvars.* (DiskuvOCaml variables) are scripts that set variables about the deployment.
    $ProgramParentMSYS2AbsPath = & $MSYS2Dir\usr\bin\cygpath.exe -au "$ProgramParentPath"
    $ProgramMSYS2AbsPath = & $MSYS2Dir\usr\bin\cygpath.exe -au "$ProgramPath"
    $UnixVarsArray = @(
        "DiskuvOCamlVarsVersion=1",
        "DiskuvOCamlHome='$ProgramMSYS2AbsPath'",
        "DiskuvOCamlBinaryPaths='$ProgramMSYS2AbsPath/bin'"
    )
    $UnixVarsContents = $UnixVarsArray -join [environment]::NewLine
    $UnixVarsContentsOnOneLine = $UnixVarsArray -join " "
    $PowershellVarsContents = @"
`$env:DiskuvOCamlVarsVersion = 1
`$env:DiskuvOCamlHome = '$ProgramPath'
`$env:DiskuvOCamlBinaryPaths = '$ProgramPath\bin'
"@

    # END Define dkmlvars
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN Compile/install opam.exe

    $global:ProgressActivity = "Install Native Windows OPAM.EXE"
    Write-ProgressStep

    # Skip with ... $global:SkipOpamSetup = $true ... remove it with ... Remove-Variable SkipOpamSetup
    if (!$global:SkipOpamSetup) {
        if ([Environment]::Is64BitOperatingSystem) {
            $OpamBasenameArch = "win64"
        } else {
            $OpamBasenameArch = "win32"
        }
        if (Test-Path -Path "$ProgramPath\bin\opam.exe") {
            # okay. already installed
        } elseif (Import-DiskuvOCamlAsset `
                -PackageName "opam-reproducible" `
                -ZipFile "opam-$OpamBasenameArch.zip" `
                -TmpPath "$TempPath" `
                -DestinationPath "$ProgramPath") {
            # okay. just imported
        } else {
            Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
                -Command "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps /opt/diskuv-ocaml/installtime/private/install-opam.sh '$DkmlMSYS2AbsPath' $DV_AvailableOpamVersion '$ProgramMSYS2AbsPath'"
        }
    }

    # END Compile/install opam.exe
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN opam init

    $global:ProgressActivity = "Initialize Opam Package Manager"
    Write-ProgressStep

    $OpamInitTempPath = "$TempPath\opaminit"
    $OpamInitTempMSYS2AbsPath = & $MSYS2Dir\usr\bin\cygpath.exe -au "$OpamInitTempPath"

    # Upgrades. Possibly ask questions to delete things, so no progress indicator
    Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
        -ForceConsole `
        -Command "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps '$DkmlPath\installtime\unix\deinit-opam-root.sh' dev"

    # Skip with ... $global:SkipOpamSetup = $true ... remove it with ... Remove-Variable SkipOpamSetup
    if (!$global:SkipOpamSetup) {
        if (!(Test-Path -Path $OpamInitTempPath)) { New-Item -Path $OpamInitTempPath -ItemType Directory | Out-Null }
        # The first time vcpkg installs can stall on Windows (on a Windows VM set to Paris Locale). So we execute the problematic
        # portion in Command Prompt since running from the command line always seems to work.
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
            -Command "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps '$DkmlPath\installtime\unix\init-opam-root.sh' -p dev -o '$OpamInitTempMSYS2AbsPath'/run.cmd"
        Invoke-Win32CommandWithProgress -FilePath "$OpamInitTempPath\run.cmd"
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
            -Command "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps '$DkmlPath\installtime\unix\init-opam-root.sh' -p dev"
    }

    # END opam init
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN opam switch create diskuv-boot-DO-NOT-DELETE

    $global:ProgressActivity = "Create diskuv-boot-DO-NOT-DELETE Opam Switch"
    Write-ProgressStep

    # Skip with ... $global:SkipOpamSetup = $true ... remove it with ... Remove-Variable SkipOpamSetup
    if (!$global:SkipOpamSetup) {
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
            -Command "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps '$DkmlPath\installtime\unix\create-diskuv-boot-DO-NOT-DELETE-switch.sh'"
        }

    # END opam switch create diskuv-boot-DO-NOT-DELETE
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN opam switch create diskuv-system

    if ($StopBeforeCreateSystemSwitch) {
        Write-Host "Stopping before being completed finished due to -StopBeforeCreateSystemSwitch switch"
        exit 0
    }

    $global:ProgressActivity = "Create diskuv-system local Opam switch"
    Write-ProgressStep

    # Skip with ... $global:SkipOpamSetup = $true ... remove it with ... Remove-Variable SkipOpamSetup
    if (!$global:SkipOpamSetup) {
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
            -Command "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps '$DkmlPath\installtime\unix\create-opam-switch.sh' -y -s -b Release"
    }

    # END opam switch create diskuv-system
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN opam install required `diskuv-system` packages

    $global:ProgressActivity = "Install packages in diskuv-system local Opam Switch"
    Write-ProgressStep

    # Note: flexlink.exe is already installed because it is part of the OCaml system compiler (ocaml-variants).

    # Skip with ... $global:SkipOpamSetup = $true ... remove it with ... Remove-Variable SkipOpamSetup
    if (!$global:SkipOpamSetup) {
        Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
            -Command (
            "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps '$DkmlPath\runtime\unix\platform-opam-exec' -s install --yes " +
            "$($DistributionPackages -join ' ')"
        )
    }

    # END opam install required `diskuv-system` packages
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN compile apps

    $global:ProgressActivity = "Compile apps"
    Write-ProgressStep

    $AppsCachePath = "$TempPath\apps"
    $AppsBinDir = "$ProgramPath\tools\apps"

    Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
        -Command ("set -x && " +
            "cd /opt/diskuv-ocaml/installtime/apps/ && " +
            "env $UnixVarsContentsOnOneLine TOPDIR=/opt/diskuv-ocaml/installtime/apps '$DkmlPath\runtime\unix\platform-opam-exec' -s exec -- dune build --build-dir '$AppsCachePath' @all")

    # Only apps, not bootstrap-apps, are installed
    if (!(Test-Path -Path $AppsBinDir)) { New-Item -Path $AppsBinDir -ItemType Directory | Out-Null }
    Copy-Item "$AppsCachePath\default\fswatch_on_inotifywin\fswatch.exe" -Destination $AppsBinDir
    Copy-Item "$AppsCachePath\default\findup\findup.exe" -Destination $AppsBinDir\dkml-findup.exe
    Copy-Item "$AppsCachePath\default\dkml-templatizer\dkml_templatizer.exe" -Destination $AppsBinDir\dkml-templatizer.exe

    # END compile apps
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN install `diskuv-system` to Programs

    $global:ProgressActivity = "Install diskuv-system binaries"
    Write-ProgressStep

    $ProgramRelBinDir = "bin"
    $ProgramBinDir = "$ProgramPath\$ProgramRelBinDir"
    $DiskuvSystemDir = "$ProgramPath\system\_opam"

    if (!(Test-Path -Path $ProgramBinDir)) { New-Item -Path $ProgramBinDir -ItemType Directory | Out-Null }
    foreach ($binary in $DistributionBinaries) {
        if (!(Test-Path -Path "$ProgramBinDir\$binary")) {
            Copy-Item -Path "$DiskuvSystemDir\bin\$binary" -Destination $ProgramBinDir
        }
    }

    # END opam install `diskuv-system` to Programs
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN Stop deployment. Write deployment vars.

    $global:ProgressActivity = "Finalize deployment"
    Write-ProgressStep

    Stop-BlueGreenDeploy -ParentPath $ProgramParentPath -DeploymentId $DeploymentId -Success
    if ($global:RedeployIfExists) {
        Stop-BlueGreenDeploy -ParentPath $TempParentPath -DeploymentId $DeploymentId -Success # don't delete the temp directory
    } else {
        Stop-BlueGreenDeploy -ParentPath $TempParentPath -DeploymentId $DeploymentId # no -Success so always delete the temp directory
    }

    # dkmlvars.* (DiskuvOCaml variables)
    #
    # Since for Unix we should be writing BOM-less UTF-8 shell scripts, and PowerShell 5.1 (the default on Windows 10) writes
    # UTF-8 with BOM (cf. https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-content?view=powershell-5.1)
    # we write to standard Windows encoding `Unicode` (UTF-16 LE with BOM) and then use dos2unix to convert it to UTF-8 with no BOM.
    Set-Content -Path "$ProgramParentPath\dkmlvars.utf16le-bom.sh" -Value $UnixVarsContents -Encoding Unicode
    Set-Content -Path "$ProgramParentPath\dkmlvars.ps1" -Value $PowershellVarsContents -Encoding Unicode

    Invoke-MSYS2CommandWithProgress -MSYS2Dir $MSYS2Dir `
        -Command (
            "set -x && dos2unix --newfile '$ProgramParentMSYS2AbsPath/dkmlvars.utf16le-bom.sh' '$ProgramParentMSYS2AbsPath/dkmlvars.tmp.sh' && " +
            "rm -f '$ProgramParentMSYS2AbsPath/dkmlvars.utf16le-bom.sh' && " +
            "mv '$ProgramParentMSYS2AbsPath/dkmlvars.tmp.sh' '$ProgramParentMSYS2AbsPath/dkmlvars.sh'"
        )


    # END Stop deployment. Write deployment vars.
    # ----------------------------------------------------------------

    # ----------------------------------------------------------------
    # BEGIN Modify User's environment variables

    $global:ProgressActivity = "Modify environment variables"
    Write-ProgressStep

    $splitter = [System.IO.Path]::PathSeparator # should be ';' if we are running on Windows (yes, you can run Powershell on other operating systems)

    $userpath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $userpathentries = $userpath -split $splitter # all of the User's PATH in a collection
    $PathModified = $false

    # DiskuvOCamlHome
    [Environment]::SetEnvironmentVariable("DiskuvOCamlHome", "$ProgramPath", 'User')

    # Add bin\ to the User's PATH if it isn't already
    if (!($userpathentries -contains $ProgramBinDir)) {
        # remove any old deployments
        $PossibleDirs = Get-PossibleSlotPaths -ParentPath $ProgramParentPath -SubPath $ProgramRelBinDir
        foreach ($possibleDir in $PossibleDirs) {
            $userpathentries = $userpathentries | Where-Object {$_ -ne $possibleDir}
        }
        # add new PATH entry
        $userpathentries = @( $ProgramBinDir ) + $userpathentries
        $PathModified = $true
    }

    # Remove legacy tools\opam\ from the User's PATH
    $ProgramRelToolDir = "tools\opam"
    $ProgramToolOpamDir = "$ProgramPath\$ProgramRelToolDir"
    if ($userpathentries -contains $ProgramToolOpamDir) {
        # remove any old deployments
        $PossibleDirs = Get-PossibleSlotPaths -ParentPath $ProgramParentPath -SubPath $ProgramRelToolDir
        foreach ($possibleDir in $PossibleDirs) {
            $userpathentries = $userpathentries | Where-Object {$_ -ne $possibleDir}
        }
        $PathModified = $true
    }

    if ($PathModified) {
        # modify PATH
        [Environment]::SetEnvironmentVariable("PATH", ($userpathentries -join $splitter), 'User')
    }

    # END Modify User's environment variables
    # ----------------------------------------------------------------
}
catch {
    $ErrorActionPreference = 'Continue'
    Write-Error (
        "Setup did not complete because an error occurred.`n$_`n`n$($_.ScriptStackTrace)`n`n" +
        "$global:AdditionalDiagnostics`n`nLog files available at`n  $AuditLog")
    exit 1
}

Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $global:ProgressActivity -Completed

Clear-Host
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Setup is complete. Congratulations!"
Write-Host "Enjoy Diskuv OCaml! Documentation can be found at https://diskuv.gitlab.io/diskuv-ocaml/"
Write-Host ""
Write-Host ""
Write-Host ""
if ($PathModified) {
    Write-Warning "Your User PATH was modified."
    Write-Warning "You will need to log out and log back in"
    Write-Warning "-OR- (for advanced users) exit all of your Command Prompts, Windows Terminals,"
    Write-Warning "PowerShells and IDEs like Visual Studio Code"
}
