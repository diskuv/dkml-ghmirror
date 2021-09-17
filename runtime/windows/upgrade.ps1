# ==========================
# upgrade.ps1
#
# Upgrade the `diskuv-ocaml` vendored directory
#
# ==========================

[CmdletBinding()]
param (
    [Parameter()]
    [int]
    $ParentProgressId = -1
)

$ErrorActionPreference = "Stop"

$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
$DkmlPath = $HereDir.Parent.Parent.FullName
if (!(Test-Path -Path $DkmlPath\.dkmlroot)) {
    throw "Could not locate where this script was in the project. Thought DkmlPath was $DkmlPath"
}

$env:PSModulePath += "$([System.IO.Path]::PathSeparator)$DkmlPath\installtime\windows"
Import-Module Project

function Invoke-Git {
    param (
        [Parameter(Mandatory = $true)]
        $Path,
        $ArgumentList
    )
    & git -C "$Path" $ArgumentList
    if ($LastExitCode -ne 0) { throw "FAILED: git -C '$Path' $ArgumentList" }
}

function Invoke-GitQuietlyAndGiveExitStatus {
    param (
        [Parameter(Mandatory = $true)]
        $Path,
        $ArgumentList
    )
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & git -C "$Path" $ArgumentList 2>&1 | Out-Null
    Write-Output ($LastExitCode -eq 0)
    $ErrorActionPreference = $eap
}

# Find which git commit we are in the vendored submodule
$DkmlCommitId = Invoke-Git -Path "$DkmlPath" -ArgumentList @("rev-parse", "HEAD")
Write-Host ("{0,35}: {1}" -f "Diskuv OCaml existing commit id", $DkmlCommitId)

# Do not proceed if the project directory has not been committed to git
$ProjectPath = (Get-ProjectDir -Path $HereDir).FullName
Write-Host ("{0,35}: {1}" -f "Project path", $ProjectPath)
$ProjectGitStatus = Invoke-Git -Path "$ProjectPath" -ArgumentList @("status", "--porcelain")
if ($null -ne $ProjectGitStatus -and $ProjectGitStatus.Trim() -ne "") {
    Write-Error -Message "The working directory $ProjectPath must be clean! Instead you have: $ProjectGitStatus" `
        -RecommendedAction "Either commit all changes to git (ex. `git add -A; git commit`) or stash them (`git add -A; git stash`) or remove any unnecessary files."
}

# Pull in the latest code from the `diskuv-ocaml` repository in our vendored submodule
Invoke-Git -Path "$DkmlPath" -ArgumentList @("fetch", "origin", "--verbose")

# Find which commit we should upgrade to, if any
if (-not (Invoke-GitQuietlyAndGiveExitStatus -Path "$DkmlPath" -ArgumentList @("show", "origin/upgrade:up-$DkmlCommitId.json"))) {
    Write-Host "You are already up-to-date with the latest available upgrades!"
    return
}
$DkmlUpgradeJson = Invoke-Git -Path "$DkmlPath" -ArgumentList @("show", "origin/upgrade:up-$DkmlCommitId.json")
$DkmlUpgradeJson = ConvertFrom-Json $DkmlUpgradeJson
$DkmlUpgradeCommitId = $DkmlUpgradeJson.upgradeCommitId
Write-Host ("{0,35}: {1}" -f "Diskuv OCaml upgrade commit id", $DkmlUpgradeCommitId)

# Reset forcibly since the `diskuv-ocaml` repository may have had its git history
# rewritten to keep `git submodule add` download times low. We don't use a
# gentle `git pull --ff-only`!
Invoke-Git -Path "$DkmlPath" -ArgumentList @("reset", "--hard", "$DkmlUpgradeCommitId")

# Save the upgraded submodule in the project repository
Invoke-Git -Path "$ProjectPath" -ArgumentList @("commit", "-m", "Upgrade diskuv-ocaml`n`nFrom $DkmlCommitId to $DkmlUpgradeCommitId", "$DkmlPath")
$ProjectCommitId = Invoke-Git -Path "$ProjectPath" -ArgumentList @("rev-parse", "HEAD")

Write-Host "Successfully upgraded! If you experience any problems, use the following to rollback:`n`tgit -C '$ProjectPath' revert $ProjectCommitId`n`tgit -C '$ProjectPath' submodule update --init --recursive"
