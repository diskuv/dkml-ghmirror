.. _SDKProjects:

SDK Projects
============

.. warning::

    The SDK Projects documentation is not ready for consumption. **Stop here!**

Build Process
-------------

There are a hierarchy of build tools that are used to build an SDK project:

.. graphviz::

   digraph G {
      compound=true;
      make_gen [shape=Mdiamond,label="./makeit generate"];
      make_gen -> select_buildtool;

      subgraph cluster_make {
         label = "GNU Make";
         select_buildtool [shape=diamond,label="Decide Primary build tool"];
         cmake_gen [label="cmake -G"];

         subgraph cluster_buildtool {
            label = "Primary Build Tool\n(Visual Studio, Xcode, Android Studio, ninja, etc.)";
            color=blue;

            build_project [shape=Mdiamond,label="build project"];
            dune_build [label="dune build"];
            target_build [label="ninja/make/msbuild"];
            c_build [label="clang/gcc/cl"];
            ocaml_build [label="ocamlc"];

            build_project -> target_build [label=" **/CMakeLists.txt"]
            build_project -> dune_build [label=" *.opam\n dune-project"];
            target_build -> c_build [label=" *.c"];
            dune_build -> c_build [label=" *_stubs.c"];
            dune_build -> ocaml_build [label=" *.ml"];

            target_exe [shape=Msquare,label=" *.exe"];
            target_lib [shape=Msquare,label=" *.so,*.dll\n *.a,*.lib"];
            ocaml_build -> target_lib [dir=both];
            c_build -> target_lib [dir=both];
            /*target_lib -> ocaml_build;
            target_lib -> c_build;*/
            ocaml_build -> target_exe;
            c_build -> target_exe;
         }

         select_buildtool -> cmake_gen;
         cmake_gen -> build_project [minlen=1,label=" «create»",lhead="cluster_buildtool"];
      }
   }

CMake controls almost all of the build process.

First the script ``./makeit generate-XX-on-YY`` runs a GNU Makefile script that
selects the build tool (Ninja, Visual Studio, xcode, etc.) and then invokes
the *generation* phase of CMake. During this phase CMake will:

* create the build directory
* copy the source code into the build directory
* create configuration files for the chosen build tool

The chosen build tool can then be invoked. For example on Windows the Visual Studio build tool
is used and you can open the "solution" in Visual Studio and then build the project from within
Visual Studio.

Anytime after when you edit the source code one of two things can happen:

1. You edit the project metadata in the ``CMakeLists.txt`` files: CMake will have
   written intelligence into the build tool configuration files so that when any project
   metadata has changed the CMake generation phase
   will be rerun to update the build tool.
2. You edit OCaml or C code, or edit ``dune`` files: The chosen build tool will notice your
   changes and incrementally compile the code if you build the porject.

You can go back and forth from OCaml to C because
`OCaml packages <https://dune.readthedocs.io/en/latest/opam.html#generating-opam-files>`_
are treated as CMake targets, and DKSDK has added logic to CMake to wire together C
and OCaml targets.

Static or Dynamic Linking
-------------------------

For all operating systems we use dynamic linking. There is a
`setup-dkml <https://github.com/diskuv/dkml-workflows#readme>`__
GitHub child workflow available that will create dynamically linked, portable
Linux applications.

There is little benefit to doing static linking on Windows. Windows has
a standard installer (``.msi`` or ``setup*.exe``) that can install any
necessary DLLs. The only benefit for reducing the DLL dependencies are
when distributing a **Windows library** so that library users do not
need to bundle the DLLs. However, it is a terrible idea to stop relying
on the Windows system libraries, especially the C runtime, since two C
runtimes should not co-exist in the same process space.

Android and macOS are similar to Windows in that they have standardized
installers that can bundle any shared libraries.

The OCaml compiler produces static objects and static libraries unless
you give the ``-shared`` option to ocamlopt. However OCaml executables
are dynamically linked with the C libraries of the OCaml package
dependencies unless ``-ccopt static`` is given to ocamlopt.

Build Platforms
---------------

We use Linux based containers (including Windows WSL2 and untested
Docker on macOS) as the build host because:

-  ``wine`` is only available in the `x86 and x86\_64
   architectures <https://pkgs.alpinelinux.org/packages?name=wine&branch=edge>`__
   as of July 2021. We could compile ``wine`` (perhaps most easily for
   macOS) but at the moment it is not worth the effort since Docker (aka
   Linux containers) is available on most platforms including macOS.

Target Platforms
----------------

+------------------+------------------------------------------+
| Platform         | Description                              |
+==================+==========================================+
| windows\_x86\_64 | AMD/Intel 64-bit Windows.                |
+------------------+------------------------------------------+
| linux\_x86\_64   | AMD/Intel 64-bit Linux.                  |
+------------------+------------------------------------------+

.. warning:: 32-bit Windows

      TLDR: 32-bit executables with "install", "setup" or "update" in their filename, when run from MSYS2, will fail.

      These same executables when run from PowerShell or the Command Prompt will pop up the
      "Do you want to allow this app from an unknown publisher to make changes to your device?" User Account Control. However
      this logic does not seem to be available in MSYS2 (or Cygwin), so in MSYS2 you get a Permission Denied.

      Reference:
      https://docs.microsoft.com/en-us/windows/security/identity-protection/user-account-control/how-user-account-control-works#installer-detection-technology

      Solutions:

      1. Change the executable filename if that is possible.
      2. Run as Administrator
      3. Disable the "User Account Control: Detect application installations and prompt for elevation" policy setting and then reboot.
         See https://docs.microsoft.com/en-us/windows/security/identity-protection/user-account-control/user-account-control-security-policy-settings#user-account-control-detect-application-installations-and-prompt-for-elevation

Build Types
-----------

+----------+-----------------------------------------------------------------+
| Build    | Description                                                     |
| Type     |                                                                 |
+==========+=================================================================+
| Debug    | Slightly optimized code with debugging symbols                  |
+----------+-----------------------------------------------------------------+
| Release  | Fully optimized [1] code. Dune builds with analog of            |
|          | ``dune --release``                                              |
+----------+-----------------------------------------------------------------+
| ReleaseC | Mostly optimized [1] [2] code with compatibility for `american  |
| ompatFuz | fuzzy lop (AFL) <https://github.com/google/AFL>`__              |
| z        |                                                                 |
+----------+-----------------------------------------------------------------+
| ReleaseC | Mostly optimized                                                |
| ompatPer | `1 <%60ReleaseCompatPerf%60%20changes%20the%20native%20code%20s |
| f        | o%20it%20uses%20the%20frame%20pointer%20register%20as%20it%20ty |
|          | pical%20for%20C%20code.%20That%20makes%20the%20code>`__         |
|          | code with compatibility for                                     |
|          | `Perf <https://dev.realworldocaml.org/compiler-backend.html#pro |
|          | filing-native-code>`__                                          |
+----------+-----------------------------------------------------------------+

[1]: ``Release``, ``ReleaseCompatFuzz`` and ``ReleaseCompatPerf`` all
use the `Flamba
optimizations <https://ocaml.org/releases/4.12/htmlman/flambda.html>`__
with the highest ``-O3`` optimization level.

[2]: ``ReleaseCompatFuzz`` changes the native code so `it can be tested
with automated security fuzz
testing <https://ocaml.org/releases/4.12/htmlman/afl-fuzz.html>`__.
OCaml will be configured with
`afl-instrument <https://ocaml.org/releases/4.12/htmlman/afl-fuzz.html#s:afl-generate>`__
which will cause all OCaml executables to be instrumented for fuzz
testing.

`a bit slower (~3-5%) but easy to do performance probing with
Perf <https://dev.realworldocaml.org/compiler-backend.html#profiling-native-code>`__.

With CMake the build types are available in the
`CMAKE\_CONFIGURATION\_TYPES <https://cmake.org/cmake/help/latest/variable/CMAKE_CONFIGURATION_TYPES.html>`__
or
`CMAKE\_BUILD\_TYPE <https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_TYPE.html>`__
variables.

Each build type has a corresponding `Visual Studio Code CMake Tools
Variant <https://vector-of-bool.github.io/docs/vscode-cmake-tools/variants.html>`__.

OCaml
-----

Opam Packages
~~~~~~~~~~~~~

We use `Opam <https://opam.ocaml.org/>`__ as the package manager for
OCaml code.

IDE Support
~~~~~~~~~~~

An IDE with type introspection is critical to develop OCaml source code.
IDEs like Visual Studio Code detect the presence of a Dune-based project
(likely just checking for a ``dune`` file) and expect Dune to provide
`Merlin <https://github.com/ocaml/merlin#readme>`__ based type
introspection and auto-completion.

1. Dune is able to provide
   `Merlin <https://github.com/ocaml/merlin#readme>`__ based type
   introspection and auto-completion.

``dune printenv --verbose`` can be used to tell if the current Dune
context is providing Merlin introspection and which Opam switch will be
introspected:

.. code-block:: text

   Dune context:
    { name = "default"
    ; kind = "default"
    ; profile = User_defined "Release"
    ; merlin = true
    ; ...
    ; findlib_path =       [ External           "/home/user/source/example/build/dev/Release/_opam/lib"       ]
    ; ...
    }

`Querying Merlin
configuration <https://dune.readthedocs.io/en/stable/usage.html#querying-merlin-configuration>`__
has more details. 2. The VS Code OCaml extension queries the default
Opam root ``~/.opam`` to present to the developer which Opam switches
are available (ie. run ``env - HOME=$HOME opam switch``). The VS Code
selected Opam switch (which can be saved in ``~/.vscode/settings.json``
as the ``"ocaml.sandbox":{"kind": "opam","switch": "..."}`` property) is
expected to contain the `the ocaml-lsp-server IDE Language
Server <https://github.com/ocaml/ocaml-lsp#readme>`__.

C Code
------

CMake
~~~~~

    CMake is a build tool, primarily for C/C++ cross-platform builds

Much of the best practices and structure come from
https://cliutils.gitlab.io/modern-cmake/ and
https://gitlab.com/CLIUtils/modern-cmake/tree/master/examples/extended-project.

Visual Studio Code can use the `CMake
Tools <https://vector-of-bool.github.io/docs/vscode-cmake-tools/index.html>`__
extension.

The build directory is ``build/TARGET_PLATFORM/BUILD_TYPE`` where:

-  ``TARGET_PLATFORM`` is the name of the kit in
   ``.vscode/cmake-kits.json`` which corresponds to the `target
   platform <#target-platforms>`__
-  ``BUILD_TYPE}`` is the name of the `variant like Debug or
   Release <https://vector-of-bool.github.io/docs/vscode-cmake-tools/variants.html>`__
   which corresponds to the `build type <#build-types>`__

.. note::

    "Win32" refers to executables that can be installed using a .MSI or
    a .EXE. More formally they are "PE32/PE32+ executables". "UWP" is
    the Universal Windows Platform, which are executables that can be
    downloaded from the Windows Store. To complicate things further,
    in 2021 the Windows Store started accepting regular Win32 (not UWP) games
    in the Windows Store.

For 32 bit Intel/AMD Win32 builds:

.. code:: powershell

    $BuildDir = "build\x86-windows-msvc\Debug"
    cmake -S . -B $BuildDir -A Win32
    cmake --build $BuildDir

For 64 bit Intel/AMD Win32 builds:

.. code:: powershell

    $BuildDir = "build\x64-windows-msvc\Debug"
    cmake -S . -B $BuildDir -A x64
    cmake --build $BuildDir

For 32 bit ARM Win32 builds:

.. code:: powershell

    $BuildDir = "build\arm-windows-msvc\Debug"
    cmake -S . -B $BuildDir -A arm
    cmake --build $BuildDir

For 64 bit ARM Win32 builds:

.. code:: powershell

    $BuildDir = "build\arm64-windows-msvc\Debug"
    cmake -S . -B $BuildDir -A arm64
    cmake --build $BuildDir

*Doesn't produce UWP*. For 32 bit Intel/AMD UWP builds:

.. code:: powershell

    $BuildDir = "build\x86-uwp-msvc\Debug"
    cmake -S . -B $BuildDir -DVCPKG_TARGET_TRIPLET="x86-uwp"
    cmake --build $BuildDir

*Doesn't produce UWP*. For 64 bit Intel/AMD UWP builds:

.. code:: powershell

    $BuildDir = "build\x64-uwp-msvc\Debug"
    cmake -S . -B $BuildDir -DVCPKG_TARGET_TRIPLET="x64-uwp"
    cmake --build $BuildDir

*Doesn't produce UWP*. For 32 bit ARM UWP builds:

.. code:: powershell

    $BuildDir = "build\arm-uwp-msvc\Debug"
    cmake -S . -B $BuildDir -DVCPKG_TARGET_TRIPLET="arm-uwp"
    cmake --build $BuildDir

*Doesn't produce UWP*. For 64 bit ARM UWP builds:

.. code:: powershell

    $BuildDir = "build\arm64-uwp-msvc\Debug"
    cmake -S . -B $BuildDir -DVCPKG_TARGET_TRIPLET="arm64-uwp"
    cmake --build $BuildDir

    The build systems are defined at
    https://github.com/microsoft/vcpkg/tree/master/triplets and
    https://github.com/microsoft/vcpkg/tree/master/triplets/community.

Installing is:

.. code:: powershell

    cmake --install $BuildDir

vcpkg
~~~~~

    vcpkg is a C/C++ package manager (think ``pip`` for Python or
    ``Gradle`` for Java)

`vcpkg <https://vcpkg.io/en/index.html>`__ is automatically built as
part of the `Building <#Building>`__ steps using the
``scripts/setup/PLATFORM/install-tools.(sh|ps1)`` script.

There are two ways to install vcpkg packages: classic and manifest mode.
We use the newer `manifest
mode <https://vcpkg.io/en/docs/users/manifests.html>`__.

You can run ``vcpkg`` with the following on Unix:

.. code:: bash

    ./src/build-tools/vendor/vcpkg/vcpkg --version

or the following on Windows:

.. code:: powershell

    .\src\build-tools\vendor\vcpkg\vcpkg --version

The ``vcpkg search`` command is useful to find the exact name of a new
package you may install with ``vcpkg install`` and then `include the
package in
vcpkg.json <https://vcpkg.io/en/docs/examples/manifest-mode-cmake.html#converting-to-manifest-mode>`__
and then `include the package in
CMakeLists.txt <https://vcpkg.io/en/docs/examples/installing-and-using-packages.html#cmake-toolchain-file>`__.

To get updates to existing packages:

1. Get a newer tag of ``src/build-tools/vendor/vcpkg`` (ex.
   ``cd src/build-tools/vendor/vcpkg; git fetch --tags; git checkout SOME_NEW_TAG``).
2. Run ``vcpkg upgrade`` to rebuild all outdated packages.

Linux
-----

C Runtime Library
~~~~~~~~~~~~~~~~~

We use the alternative C runtime library ``musl`` for Linux. It is:

-  can be statically linked. This is extremely important for Linux so we
   don't have a nightmare distributing many different executables
   matching the specific GNU libc and related libraries in
   Ubuntu18/Ubuntu20/RHEL5/ad infinimum. Static linking is not much of a
   problem for Windows or macOS since they have stable system C
   libraries.
-  liberally licensed
-  builds on a huge number of target platforms (especially embedded
   platforms)
-  avoids glibc incompatibility problems with Qemu (which creates a red
   herring by complaining about old kernel versions); more details at
   https://github.com/dockcross/dockcross/issues/274

Hardware Architectures
~~~~~~~~~~~~~~~~~~~~~~

We can use Qemu to emulate hardware. Emulation is very important so that
test code that is created alongside the build is actually executed and
validated.

https://dbhi.github.io/qus/ has a like-minded detailed description of
this type of approach. We use the ``qus`` Docker images to register
transparent Qemu userland emulation in the host kernel (Microsoft Linux
Kernel for WSL2; the desktop kernel for Linux; etc.) so that running
something like an ARM compiled ``hello_arm`` will delegate to Qemu for
CPU emulation.

Userland
~~~~~~~~

The userland is the executables and libraries that live outside the
kernel. To make the build process work without cross-compiling, we need
all of the userland including ``bash``, the C Runtime library and
Node.js to be available in the host architecture or the target
architecture. More importantly when the C compiler generates code it
must think that the architecture is the target architecture so that any
executables we want to distribute are built for the target architecture.
One important consequence is that any static libraries that are included
as part of the distribution executables must be compiled in the target
architecture; the libraries cannot be the host architecture because the
transparent Qemu translation is for executables not libraries.

https://ownyourbits.com/2018/06/13/transparently-running-binaries-from-any-architecture-in-linux-with-qemu-and-binfmt_misc/
has a technique we will use to fetch the entire userland in the target
architecture we want.

    After implementing the solution, I came across
    https://github.com/alpinelinux/alpine-chroot-install. It does not do
    `QEMU for various hardware
    architectures <#hardware-architectures>`__ but is a great reference
    nonetheless. It is especially important to look at if we use GitHub
    Actions or Travis CI.

So inside the AMD64 Docker container we build a chroot sandbox called
the **Build Sandbox** with a musl-based filesystem **from the target
architecture**.

Limitations on Hardware Architecture
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Be aware** that:

1. Using Alpine as the source for our musl-based chroot sandbox limits
   our hardware architecture choices to what Alpine officially supports.
   See http://mirror.csclub.uwaterloo.ca/alpine/latest-stable/releases/
   for the list of supported architectures. An alternative would be to
   use OpenWRT Linux which supports even more architectures, but we
   stick to Alpine since it has way more packages.
2. OCaml native code compilation limits choices as well. We *could* use
   OCaml bytecode for non-native architectures but we haven't done that
   work. The list of supported platforms is at
   https://ocaml.org/learn/portability.html with releases (like
   https://ocaml.org/releases/4.12.0.html) listing new platform support.

In practice Alpine is the limiting factor.

C Code
~~~~~~

``musl`` is built locally (this can take hours) by
``vendor/musl-cross-make`` and configured by
``scripts/unix/musl-cross-make.config.mak``. Some of the configuration,
for example, is used to detect that an ARM machine should use the target
triplet ``arm-linux-muslabihf`` to produce correct machine code with
`FPU-specific floating point calling
conventions <https://github.com/richfelker/musl-cross-make/blob/3398364d6e3251cd097024182a8cb9f667c23bda/litecross/Makefile#L46>`__.

``make -f scripts/unix/musl-cross-make.config.mak print-TARGET`` shows
the detected target triplet. Let's assume the target triplet is
``x86_64-linux-musl``. Then by setting ``VCPKG_TARGET_TRIPLET`` we use
the vcpkg triplet file ``etc/vcpkg/triplets/x86_64-linux-musl.cmake`` to
make sure all vcpkg packages use the locally built ``musl`` compilers
and are statically linked.

Finally, we need our own C code (not the vcpkg packages) to use the
``musl`` compilers. We use the `multiple toolchain files feature of
vcpkg <https://vcpkg.io/en/docs/users/integration.html#using-multiple-toolchain-files>`__
by setting ``VCPKG_CHAINLOAD_TOOLCHAIN_FILE`` to a musl toolchain in
``cmake/toolchains/``.

OCaml
~~~~~

We use an OPAM variant that already includes ``musl``. In Esy's
``package.json``/``esy.json`` we can use a resolution like:

.. code:: json

    {
      "resolutions": {
        "ocaml": "4.12.0-musl.static.flambda"
      }
    }

Building
--------

Command Line
~~~~~~~~~~~~

.. code:: bash

    BUILDDIR=build/dev/Debug
    TARGETTRIPLET=$(make -f scripts/unix/musl-cross-make.config.mak print-TARGET)
    PATH="$PWD/vendor/musl-cross-make/output/bin:$PATH"
    build/_tools/cmake/bin/cmake -S . -B $BUILDDIR -DVCPKG_TARGET_TRIPLET=$TARGETTRIPLET -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$PWD/cmake/toolchains/of-vcpkg-target-triplet.cmake
    cmake --build $BUILDDIR

Installing is:

.. code:: bash

    cmake --build $BUILDDIR --target install
