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

# ========================
# START Install instructions from https://diskuv.gitlab.io/diskuv-ocaml/index.html

(Test-Path -Path ~\DiskuvOCamlProjects) -or $(New-Item ~\DiskuvOCamlProjects -ItemType Directory)

Invoke-WebRequest `
  "https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/distribution-portable/$DkmlVersion/distribution-portable.zip" `
  -OutFile "$env:TEMP\diskuv-ocaml-distribution.zip"

Expand-Archive `
  -Path "$env:TEMP\diskuv-ocaml-distribution.zip" `
  -DestinationPath ~\DiskuvOCamlProjects `
  -Force

~\DiskuvOCamlProjects\diskuv-ocaml\installtime\windows\install-world.bat -SkipProgress -AllowRunAsAdmin -SilentInstall

# END Install instructions
# ========================

# Refresh the PATH with newly installed User entries
$env:Path = [Environment]::GetEnvironmentVariable('PATH', 'User') + [System.IO.Path]::PathSeparator + $env:Path
# Mimic $DiskuvOCamlHome
$env:DiskuvOCamlHome = "$env:LOCALAPPDATA\Programs\DiskuvOCaml\0"

# Clean, run test for installation and save results
dune clean --root C:\vagrant\test_installation.t
with-dkml dune runtest --root C:\vagrant\test_installation.t
Set-Content -Path "C:\vagrant\test_installation.t\exitcode.$SystemLocale.txt" -Value $LastExitCode -NoNewline -Encoding Ascii

# Run through a simple playground
(Test-Path -Path C:\vagrant\playground) -or $(New-Item C:\vagrant\playground -ItemType Directory)
Set-Location C:\vagrant\playground          # aka. cd playground
$env:OPAMYES = "1"                          # aka. OPAMYES=1 opam dkml init ...
with-dkml "OPAMSWITCH=$env:DiskuvOCamlHome\host-tools" opam dkml init --build-type=Release --yes # `Release` option is present simply to test CLI option handling of opam dkml init
with-dkml opam install graphics --yes       # install something with a low number of dependencies, that sufficienly exercises Opam
