Opam Integration
================

Repositories
------------

Each Opam switch created by *Diskuv OCaml* uses the following repositories *in order*:

1. diskuv-1.2.0
2. fdopen-mingw-1.2.0 *only for Windows*
3. default

The ``diskuv-1.2.0`` repository has all the patches required for third-party OCaml packages
to support the Microsoft compiler. Any switch that is created by *Diskuv OCaml* will have
pinned versions for each package in this repository. That means you will always get the
*Diskuv OCaml* patched versions and reproducible behavior.

The ``fdopen-mingw-1.2.0`` repository has all the MinGW patches for _many_ third-party OCaml packages
to work with MinGW (an alternative compiler popular on Linux). Unlike ``diskuv-1.2.0`` the packages
are not pinned, so it is possible that a newer package version is introduced into your switch
that has no MinGW patches.

.. note::

    If you suspect a stale fdopen repository is causing you problems, run ``opam repository list``
    to find where the repository is physically located and then look in its ``packages/`` subdirectory
    to see what versions of your problematic package are supported by the fdopen repository.
    ``opam list`` will tell you which versions you are currently using. An issue can be filed at
    https://gitlab.com/dkml/distributions/dkml/-/issues to move the package into an upcoming
    ``diskuv-*`` repository.

The ``default`` repository is the central Opam repository. Most of your packages are unpatched and
will come directly from this repository.

Switches
--------

``diskuv-boot-DO-NOT-DELETE`` Global Switch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

OCaml IDEs like Visual Studio Code with the OCaml Platform Extension
work best when there is at least one global Opam switch installed and
selected. The installation will install ``diskuv-boot-DO-NOT-DELETE``
with no OCaml packages.

This switch is reserved for future use so do not delete it.

    (Expert Users) The OCaml Platform Extension, for example, will
    execute ``opam var root`` which will fail if no (global) Opam switch
    has been selected. But you won't be able to pick any external (also
    known as 'local') Opam switches because ``opam var root`` failed.
    With a global switch that problem goes away.

``dkml`` Local Switch
~~~~~~~~~~~~~~~~~~~~~

OCaml package directories, C header "include" directories and other
critical locations are hardcoded into essential OCaml executables like
``ocamlc.exe`` during ``opam switch create`` and ``opam install``. If we
move the Opam switch that contains ``ocamlc`` many of your OCaml builds
will break.

``dkml`` is the Opam switch for ``ocamlc`` and other essentials
that is built in its final resting place during installation and never
moved after. If and when we need to deploy new versions of the
essentials we use a new directory and rebuild all of the OCaml packages
from scratch.

The system applications, along with Opam itself, are installed in your User
Profile. Since they are also available on your PATH, you can just type
``dune``, ``utop``, ``ocamlformat``, ``opam``, etc.

Global Variables
----------------

.. note::

    Refer to the `Opam Manual "Variables" documentation <http://opam.ocaml.org/doc/Manual.html#Variables>`_
    if you are not familiar with Opam variables.

The global variables that will be present in a Diskuv OCaml installation are:

.. code-block:: text

    <><> Global opam variables ><><><><><><><><><><><><><><><><><><><><><><><><><><>
    arch              x86_64                                                     # Inferred from system
    exe               .exe                                                       # Suffix needed for executable filenames (Windows)
    jobs              11                                                         # The number of parallel jobs set up in opam configuration
    make              make                                                       # The 'make' command to use
    opam-version      2.1.0                                                      # The currently running opam version
    os                win32                                                      # Inferred from system
    os-distribution   win32                                                      # Inferred from system
    os-family         windows                                                    # Inferred from system
    os-version        10.0.22000                                                 # Inferred from system
    root              C:\Users\you\.opam                                         # The current opam root directory
    switch            C:\Users\you\AppData\Local\Programs\DiskuvOCaml\1\system   # The identifier of the current switch
    sys-ocaml-arch    x86_64                                                     # Target architecture of the OCaml compiler present on your system
    sys-ocaml-cc      msvc                                                       # Host C Compiler type of the OCaml compiler present on your system
    sys-ocaml-libc    msvc                                                       # Host C Runtime Library type of the OCaml compiler present on your system
    sys-ocaml-version 4.12.1                                                     # OCaml version present on your system independently of opam, if any

C Compiler
----------

The Microsoft compiler and linker environment variables must be setup before use. Microsoft provides
a ``vcvarsall.bat`` and ``vsdevcmd.bat`` scripts to set environment variables.

We also want to include vcpkg C headers and C libraries by default, so the following
are adjusted to include vcpkg:

* the Microsoft environment variables ``INCLUDE`` and ``LIBS``
* the GNU GCC environment variables ``COMPILER_PATH`` and ``LIBRARY_PATH``.
  Confer with `GCC Environment Variables <https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables>`_
* the Apple clang environment variables ``CPATH`` and ``LIBRARY_PATH``.
  Confer with `clang Command Guide <https://clang.llvm.org/docs/CommandGuide/clang.html>`_ and
  `LLVM LIBRARY_PATH review <https://reviews.llvm.org/D65880>`_.

In *Diskuv OCaml* most targets (``./makeit shell-dev``, ``./makeit build-dev``, etc.)
have their environment variables automatically set for Microsoft C compilation inside MSYS2 in a manner
similar to the following:

.. code-block:: bash

    ENV_ARGS=()
    source vendor/diskuv-ocaml/vendor/drc/unix/crossplatform-functions.sh
    autodetect_compiler /tmp/launcher.sh

    /tmp/launcher.sh bash

The choice of Microsoft compiler is configured during *Diskuv OCaml* installation and made
available at ``$env:LOCALAPPDATA\Programs\DiskuvOCaml\vsstudio.dir.txt`` (full details at
``$env:LOCALAPPDATA\Programs\DiskuvOCaml\vsstudio.json``).

There are two typical methods used to detect the C compiler during the installation of
an OCaml package (ex. ``opam install``):

* Many packages use `autoconf <https://www.gnu.org/software/autoconf/>`_ to generate a ``./configure``
  script that will automatically detect the presence of Microsoft environment variables. Those will
  have been set by ``autodetect_compiler``.
* Some packages, especially core OCaml packages like the OCaml compiler and Opam, will use
  `msvs-tools <https://github.com/metastack/msvs-tools>`_. Recent versions of msvs-tools can detect
  an *Diskuv OCaml* auto-installed Visual Studio Build Tools but they will not add vcpkg
  installed packages to the INCLUDE and LIBPATH; msvs-tools may also select a more recent compiler.
  *TODO: Fixme. In progress*

OCaml Compiler
--------------

The compiler is built with Microsoft's CL.EXE. Typically OCaml packages re-use the same C compiler flags as was used by the OCaml Compiler.

This comes from ``ocamlc -config`` (yours will vary slightly):

.. code-block:: c-objdump

    version: 4.12.0
    standard_library_default: C:/Users/User/AppData/Local/Programs/DiskuvOCaml/0/dkml/_opam/lib/ocaml
    standard_library: C:/Users/User/AppData/Local/Programs/DiskuvOCaml/0/dkml/_opam/lib/ocaml
    ccomp_type: msvc
    c_compiler: cl
    ocamlc_cflags: -nologo -O2 -Gy- -MD
    ocamlc_cppflags: -D_CRT_SECURE_NO_DEPRECATE
    ocamlopt_cflags: -nologo -O2 -Gy- -MD
    ocamlopt_cppflags: -D_CRT_SECURE_NO_DEPRECATE
    bytecomp_c_compiler: cl -nologo -O2 -Gy- -MD -D_CRT_SECURE_NO_DEPRECATE
    native_c_compiler: cl -nologo -O2 -Gy- -MD -D_CRT_SECURE_NO_DEPRECATE
    bytecomp_c_libraries: advapi32.lib ws2_32.lib version.lib
    native_c_libraries: advapi32.lib ws2_32.lib version.lib
    native_pack_linker: link -lib -nologo -machine:AMD64  -out:
    ranlib:
    architecture: amd64
    model: default
    systhread_supported: true
    host: x86_64-pc-windows
    target: x86_64-pc-windows
    flambda: false
    safe_string: true
    default_safe_string: true
    flat_float_array: true
    function_sections: false
    afl_instrument: false
    windows_unicode: true
    supports_shared_libraries: true
    exec_magic_number: Caml1999X029
    cmi_magic_number: Caml1999I029
    cmo_magic_number: Caml1999O029
    cma_magic_number: Caml1999A029
    cmx_magic_number: Caml1999Y029
    cmxa_magic_number: Caml1999Z029
    ast_impl_magic_number: Caml1999M029
    ast_intf_magic_number: Caml1999N029
    cmxs_magic_number: Caml1999D029
    cmt_magic_number: Caml1999T029
    linear_magic_number: Caml1999L029

.. note::

    `voodoos@'s <https://github.com/voodoos>`_ diagram at https://github.com/ocaml/dune/issues/3718 is one of the best pictures
    of how Dune built packages get their compiler flags:

    .. image:: https://user-images.githubusercontent.com/5031221/90496703-7aa7d080-e146-11ea-91e5-1dbed72a5b87.png
        :width: 400

Working with Native Windows
---------------------------

.. note::

    This section of the documentation is for OCaml package maintainers (anyone who creates an OCaml package
    for public consumption).

As an OCaml package maintainer you may want to customize the way your package builds if you are on native
Windows. Native Windows installations differ from Cygwin Windows installations because Cygwin is a reasonably
complete POSIX environment. You may need a few tweaks including but not limited to:

* translating Windows paths into Unix paths (usually only a problem if you are using absolute paths)
* use Windows libraries rather than Unix libraries
* use ``LOCALAPPDATA`` rather than ``HOME`` to locate the user's home directory

Typically you will customize your package build behavior with either
`Opam Filters <https://opam.ocaml.org/doc/Manual.html#Filters>`_ (the topic of this section)
or with `Dune Configuration <https://dune.readthedocs.io/en/stable/dune-libs.html>`_.

In this section we try to be distribution-agnostic. That means we will present
techniques you can use even if your native Windows users are not using *Diskuv OCaml*.

Use the following Opam filter in your ``*.opam`` files to detect **native Windows** installations:

.. code-block:: text

    { os-family = "win32" & sys-ocaml-cc = "msvc" }
