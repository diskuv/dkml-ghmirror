# Vagrant for Windows Testing

> The Windows password for the Windows VM is [vagrant](https://github.com/gusztavvargadr/packer/blob/ca4c8286786dec7b718613f226da44bc2a54be11/src/u/packer/builders/virtualbox-iso/http/preseed.cfg#L27)

> If all you want is an English installation, just type `vagrant up`

FIRST, to get the language packs needed for non-English Windows testing:

- Download the `Windows 10, version 2004, 20H2 or 21H1 Language Pack ISO`, or whichever Windows version correspnds to
the value of `config.vm.box` in Vagrantfile, from https://docs.microsoft.com/en-us/azure/virtual-desktop/language-packs
- Place it in this directory (`vagrant/win32`) with the new name `CLIENTLANGPACKDVD_OEM_MULTI.iso`

SECOND, to start the Windows virtual machines:

```powershell
# only English (en-US)
vagrant up
# You can only run one of these at a time (as of 2021-11-17) since
# only one Vagrant-controlled VirtualBox machine can attach to the ISO disk at a time
$env:VAGRANT_EXPERIMENTAL = "disks" ; vagrant up fr-FR
$env:VAGRANT_EXPERIMENTAL = "disks" ; vagrant up zh-CN
$env:VAGRANT_EXPERIMENTAL = "disks" ; vagrant up manual
```
