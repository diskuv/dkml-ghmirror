.. _Advanced - Windows Administrator:

Windows Administrator Installation
==================================

The *Diskuv OCaml* distribution includes a `setup-machine.ps1 <https://gitlab.com/diskuv/diskuv-ocaml/blob/main/installtime/windows/setup-machine.ps1>`_
PowerShell script that will ask for elevated
Administrator permissions to install the Microsoft C compiler (the "MSBuild" components of Visual Studio).
As an Administrator you can run the following commands in PowerShell with ``Run as Administrator``, and
the non-Administrator users on your PCs will be able to read and complete the same *Diskuv OCaml* instructions
as everybody else.

.. code-block:: ps1con

    PS> installtime\windows\setup-machine.bat -AllowRunAsAdmin

.. note::

    You can use the ``-SilentInstall`` switch if you need to automate the installation.

The Administrator portion takes 2GB of disk space while each user can take up to 25GB of disk space in their User
Profiles (``$env:LOCALAPPDATA\Programs\DiskuvOCaml`` and ``$env:LOCALAPPDATA\opam``) just for the basic *Diskuv OCaml*
distribution. Please plan accordingly.

Using an existing Visual Studio Installation
--------------------------------------------

If you have **all** four (4) of the following:

1. Visual Studio 2015 Update 3 or later for any of the following products:

   * Visual Studio Community
   * Visual Studio Professional
   * Visual Studio Enterprise
   * Visual Studio Build Tools (the compilers without the IDE)

2. The [English language pack](https://docs.microsoft.com/en-us/visualstudio/install/install-visual-studio?view=vs-2019#step-6---install-language-packs-optional)

3. Either of the following:

   * MSVC v142 - VS 2019 C++ x64/x86 build tools (Latest) (``Microsoft.VisualStudio.Component.VC.Tools.x86.x64``) installed with `Visual Studio 2019 version 16.6 <https://docs.microsoft.com/en-us/visualstudio/releases/2019/release-notes-v16.6>`_
   * MSVC v142 - VS 2019 C++ x64/x86 build tools (v14.26) (``Microsoft.VisualStudio.Component.VC.14.26.x86.x64``) installed with any Visual Studio 2022/2019/2017/2015 version

4. Windows 10 SDK 18362 (``Microsoft.VisualStudio.Component.Windows10SDK.18362``)
   which is also known as the 19H1 SDK or May 2019 Update SDK.

then the *Diskuv OCaml* distribution will not automatically try to install its own Visual Studio Build Tools.
That means when your users run `install-world.ps1 <https://gitlab.com/diskuv/diskuv-ocaml/blob/main/installtime/windows/install-world.ps1>`_
or `setup-machine.ps1 <https://gitlab.com/diskuv/diskuv-ocaml/blob/main/installtime/windows/setup-machine.ps1>`_
they will not need Administrator privileges.

.. note::

    If you use `Chocolatey <https://chocolatey.org/>`_ to manage Windows software on your machines or in your CI build, then one of the following
    code blocks will satisfy all the requirements:

    .. code-block:: powershell

        # Any 16.6.x.x will work. This code block is recommended if you do not already install Visual Studio on your machines
        choco install visualstudio2019buildtools --version=16.6.5.0 --package-parameters "--addProductLang en-US --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.18362"

        # This will also work, and is recommended if you already install the latest Visual Studio 2019
        choco install visualstudio2019buildtools
        choco install visualstudio2019-workload-vctools --package-parameters "--addProductLang en-US --add Microsoft.VisualStudio.Component.VC.14.26.x86.x64"

        # This will also work, and is recommended if you already install the latest Visual Studio 2017
        choco install visualstudio2017buildtools
        choco install visualstudio2017-workload-vctools --package-parameters "--addProductLang en-US --add Microsoft.VisualStudio.Component.VC.14.26.x86.x64"

        # This will also work with any 16.6.x.x version, although it will install more packages than are strictly required.
        # This code block is not recommended, although GitLab CI, as of September 2021, already includes the first line in its shared GitLab Windows Runners.
        # But the shared GitLab CI may update the version at any time.
        choco install visualstudio2019buildtools --version=16.6.5.0
        choco install visualstudio2019-workload-vctools

The following installers allow you to add several
`optional components <https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools>`_
including the correct Windows 10 SDK:

* `Visual Studio Community, Professional and Enterprise <https://docs.microsoft.com/en-us/visualstudio/install/install-visual-studio>`_
* `Visual Studio Build Tools <https://docs.microsoft.com/en-us/visualstudio/releases/2019/history#release-dates-and-build-numbers>`_

.. note::

    It is common to have **multiple versions** of Windows 10 SDK installed. Don't be afraid
    to install the older Windows 10 SDK 18362.

After you have installed all the required components of Visual Studio, you can run
`setup-machine.ps1 <https://gitlab.com/diskuv/diskuv-ocaml/blob/main/installtime/windows/setup-machine.ps1>`_
with the switch ``-SkipAutoInstallVsBuildTools`` to verify you have a correct Visual Studio installation:

.. code-block:: ps1con

    PS> Set-ExecutionPolicy `
        -ExecutionPolicy Unrestricted `
        -Scope Process `
        -Force

    PS> installtime\windows\setup-machine.ps1 -SkipAutoInstallVsBuildTools

The ``setup-machine.ps1`` script will error out if you are missing any required components.
