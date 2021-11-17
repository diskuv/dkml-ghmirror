$ErrorActionPreference = "Stop"

# Get the system language
$SystemLocale = (Get-WinSystemLocale).Name
Get-WinSystemLocale # display locale
chcp.com # display code page

# Get the version which can't be embedded in this UTF-16 BE file (encoding not supported by bumpversion)
$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
if (!(Test-Path -Path $HereDir\dkmlversion.txt)) {
    throw "Could not locate dkmlversion.txt in $HereDir"
}
$DkmlVersion = (Get-Content $HereDir\dkmlversion.txt -TotalCount 1).Trim()

# Install instructions from https://diskuv.gitlab.io/diskuv-ocaml/index.html

(Test-Path -Path ~\DiskuvOCamlProjects) -or $(New-Item ~\DiskuvOCamlProjects -ItemType Directory)

Invoke-WebRequest `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/$DkmlVersion/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip"

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force

# Patch version 0.2.5
if ("0.2.5" -eq "$DkmlVersion") {
  # Need 4319ddd67ed3dd211ad5042cf9ec4ba9058d636a: Remove wrong --installChannelUri
  Copy-Item -Force -Verbose C:\vagrant\patches\0_2_5_fixed_setup-machine.ps1 ~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\setup-machine.ps1
}

# This deviates slightly from the real instructions ...
# 0.2.6: ~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat -SkipProgress -AllowRunAsAdmin -SilentInstall
~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\setup-machine.bat -SkipProgress -AllowRunAsAdmin -SilentInstall
~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\setup-userprofile.bat -SkipProgress -AllowRunAsAdmin

# Refresh the PATH with newly installed User entries
$env:Path = [Environment]::GetEnvironmentVariable('PATH', 'User') + [System.IO.Path]::PathSeparator + $env:Path

# Clean, run test and save results
dune clean --root C:\vagrant\test_installation.t
with-dkml dune runtest --root C:\vagrant\test_installation.t
Set-Content -Path "C:\vagrant\test_installation.t\exitcode.$SystemLocale.txt" -Value $LastExitCode -Encoding Ascii
