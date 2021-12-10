Troubleshooting
===============

Problem 32-bit executable - ...installer.exe: Permission denied
---------------------------------------------------------------

TLDR: 32-bit executables with "install", "setup" or "update" in their filename, when run from MSYS2 or Cygwin, will fail.

These same executables when run from PowerShell or the Command Prompt will pop up the
"Do you want to allow this app from an unknown publisher to make changes to your device?" User Account Control. However
this logic does not seem to be available in MSYS2/Cygwin, so in MSYS2/Cygwin you get a Permission Denied.

Reference:
https://docs.microsoft.com/en-us/windows/security/identity-protection/user-account-control/how-user-account-control-works#installer-detection-technology

Solutions:

1. Change the executable filename if that is possible.
2. Run as Administrator
3. Disable the "User Account Control: Detect application installations and prompt for elevation" policy setting.
   See https://docs.microsoft.com/en-us/windows/security/identity-protection/user-account-control/user-account-control-security-policy-settings#user-account-control-detect-application-installations-and-prompt-for-elevation

Problem - Sys_error("...\\_opam\\lib\\...: Permission denied")
--------------------------------------------------------------

Partial Root Cause
~~~~~~~~~~~~~~~~~~

TLDR: This is a known issue although it is not known what is triggering the problem.

.. code-block:: text

    #=== ERROR while installing dune-configurator.2.9.0 ===========================#
    Sys_error("Z:\\source\\diskuv-ocaml-starter\\build\\dev\\Debug\\_opam\\lib\\dune-configurator\\.private\\configurator__Dune_lang.cmi: Permission denied")

The extended file access control lists ("ACLs") are set incorrectly on your build directory
(``Z:\\source\\diskuv-ocaml-starter\\build\\dev\\Debug`` in the example) or one of its subdirectories.

This can be seen using a Cygwin session:

.. code-block:: ps1con

    PS Z:\source\diskuv-ocaml-starter> & $env:DiskuvOCamlHome\tools\cygwin\bin\mintty.exe -

.. code-block:: shell-session
    :linenos:
    :emphasize-lines: 16-18

    [DESKTOP-A ~]$ getfacl $(cygpath -au 'Z:\\source\\diskuv-ocaml-starter\\build\\dev\\Debug\\_opam\\lib\\dune-configurator\\.private\\configurator__Dune_lang.cmi')
    > # file: /cygdrive/z/source/diskuv-ocaml-starter/build/dev/Debug/_opam/lib/dune-configurator/.private/configurator__Dune_lang.cmi
    > # owner: you
    > # group: you
    > user::rwx
    > group::rwx
    > other::rwx
    
    [DESKTOP-A ~]$ getfacl $(cygpath -au 'Z:\\source\\diskuv-ocaml-starter\\build\\dev\\Debug\\_opam\\lib\\dune-configurator\\.private')
    > # file: /cygdrive/z/source/diskuv-ocaml-starter/build/dev/Debug/_opam/lib/dune-configurator/.private
    > # owner: you
    > # group: you
    > user::rwx
    > group::rwx
    > other::rwx
    > default:user::---
    > default:group::---
    > default:other::rwx

The highlighted extended ACLs, in particular the ``default:user::---`` entry, are removing permissions
during OCaml builds.

*A full root cause would say which Windows executable or script is inserting the extended ACLs. Cygwin is
famous/notorious for adjusting the ACLs, but it may be anything including anti-malware software.*

Solution
~~~~~~~~

Launch a Cygwin session:

.. code-block:: ps1con

    PS Z:\source\diskuv-ocaml-starter> & $env:DiskuvOCamlHome\tools\cygwin\bin\mintty.exe -

and then type the following (replacing the build directory with your own):

.. code-block:: shell-session

    [DESKTOP-A ~]$ find "$(cygpath -au 'Z:\\source\\diskuv-ocaml-starter\\build\\dev\\Debug')" -print0 | xargs -0 --no-run-if-empty setfacl --remove-all --remove-default

Problem - vendor/diskuv-ocaml/runtime/unix/standard.mk: No such file or directory
---------------------------------------------------------------------------------

Root Cause
~~~~~~~~~~

This is typically an indication that your git repository was not cloned with
the recursive flag, as in:

.. code-block:: bash

    git clone https://github.com/diskuv/diskuv-ocaml-starter

instead of the correct:

.. code-block:: bash

    git clone --recursive https://github.com/diskuv/diskuv-ocaml-starter

When you leave out the ``--recursive`` option then Git will not fetch any
of the submodules. Diskuv OCaml requires that you load it as a Git submodule.

Solution
~~~~~~~~

Run:

.. code-block:: bash

    git submodule update --init --recursive
