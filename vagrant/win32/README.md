# Vagrant for Windows Testing

> The Windows password for the Windows VM is [vagrant](https://github.com/gusztavvargadr/packer/blob/ca4c8286786dec7b718613f226da44bc2a54be11/src/u/packer/builders/virtualbox-iso/http/preseed.cfg#L27)

> If all you want is an English installation, just type `vagrant up`

FIRST, to get the language packs needed for non-English Windows testing:

- Download the `Windows 10, version 2004, 20H2 or 21H1 Language Pack ISO`, or whichever Windows version correspnds to
the value of `config.vm.box` in Vagrantfile, from https://docs.microsoft.com/en-us/azure/virtual-desktop/language-packs
- Place it in this directory (`vagrant/win32`) with the new name `CLIENTLANGPACKDVD_OEM_MULTI.iso`

SECOND, to start the Windows virtual machines:

```powershell
# Only English (en-US)
vagrant up

# You can only bring "up" one of these at a time (as of 2021-11-17) since
# only one Vagrant-controlled VirtualBox machine can attach to the language ISO disk at a time.
#
# Mitigation 1 (doesn't work)
# ---------------------------
# So we eject the CD from each machine after it has been brought up with the correct language (+ DKML has been installed).
# Note: DKML installation is a separate step that does not need the CD; can optimize to run
# the C:\vagrant\test-language.ps1 script in parallel.
#
# Mitigation 2
# ------------
# Suspend each machine.
function EjectAllCds {
    param( [Parameter(Mandatory=$true)] [string] $SystemLocale )
    vagrant winrm --shell powershell --command '$cds = (New-Object -com "WMPlayer.OCX.7").cdromcollection; 1..($cds.count) | % { $cds.item($_ - 1).eject() ; Start-Sleep -Seconds 3 } ' $SystemLocale
}
$env:VAGRANT_EXPERIMENTAL = "disks" ; vagrant up fr-FR  ; EjectAllCds -SystemLocale fr-FR  ; vagrant suspend fr-FR
$env:VAGRANT_EXPERIMENTAL = "disks" ; vagrant up zh-CN  ; EjectAllCds -SystemLocale zh-CN  ; vagrant suspend zh-CN
$env:VAGRANT_EXPERIMENTAL = "disks" ; vagrant up manual ; EjectAllCds -SystemLocale manual ; vagrant suspend manual
```