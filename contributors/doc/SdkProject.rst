.. _SDKProjects:

SDK Projects
============

Starter
-------

By now you have entered some OCaml code into ``utop`` but some key features
were missing that you can get by creating/using a local project.

A local project is a folder that contains your source code, one or more sets
of packages (other people's code) and one or more build directories to store
your compiled code and applications.

By using a local project you will be able to:

* Install other people's code packages
* Edit your source code in an IDE
* Build your source code into applications or libraries

This is easiest to see with an example.

1. Open PowerShell (press the Windows key ⊞, type "PowerShell" and then Open ``Windows PowerShell``).
2. Run the following in PowerShell:

   .. code-block:: ps1con

      PS1> cd ~\DiskuvOCamlProjects

      PS1> git clone --recursive https://gitlab.com/diskuv/diskuv-ocaml-starter.git

You now have a local project in ``~\DiskuvOCamlProjects\diskuv-ocaml-starter``!

We can initialize an Opam repository, assemble an Opam
switch and compile the source code all by running the single ``build-dev`` target:

.. code-block:: ps1con

    PS1> cd ~\DiskuvOCamlProjects\diskuv-ocaml-starter

    PS1> ./makeit build-dev DKML_BUILD_TRACE=ON

We turned on tracing (``DKML_BUILD_TRACE=ON``) so you could see what is happening;
the three steps of ``build-dev`` are:

1. Initialize an Opam repository. This takes **several minutes** but only needs to be
   done once per user (you!) per machine.
2. Assemble (create) an Opam switch by compiling all the third-party packages you
   need. Any new packages you add to ``.opam`` files will be added to your Opam switch.
   This can take **tens of minutes** but only needs to be done once per Local
   Project.
3. Compile your source code. This is usually in the **0-5 seconds** range unless your
   project is large or uses C code. There is a special Makefile target called
   ``quickbuild-dev`` that skips the first two steps and only compiles your source code.

The starter application is the `Complete Program <https://dev.realworldocaml.org/guided-tour.html>`_
example from the `Real World OCaml book <https://dev.realworldocaml.org/toc.html>`_. Let us run it.
You will enter the numbers ``1``, ``2``, ``3`` and ``94.5``, and then stop the program by
typing Ctrl-C or Enter + Ctrl-Z:

.. code-block:: ps1con

    PS1> _build/default/bin/main.exe
    > 1
    > 2
    > 3
    > 94.5
    > Total: 100.5

Recap: You fetched a SDK Project, built its code and all of its dependencies, and then ran
the resulting application!

In your own projects you will likely be making edits, and then building, and then repeating
the edit and build steps over and over again. Since you already did ``build-dev`` once, use the
following to "quickly" build your SDK Project:

.. code-block:: ps1con

    PS1> ./makeit quickbuild-dev

The next section `Integrated Development Environment (IDE)` will go over how
to automatically and almost instantaneously build your code whenever you make an edit.

Visual Studio Code Development
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. Launch Visual Studio Code
2. Open the folder (File > Open Folder; or Ctrl+K Ctrl+O) ``%USERPROFILE%\DiskuvOCamlProjects\diskuv-ocaml-starter``
3. Open a Terminal (Terminal > New Terminal; or Ctrl+Shift+`). In the terminal type:

   .. code-block:: ps1con

        [diskuv-ocaml-starter]$ ./makeit dkml-devmode
        >> while true; do \
        >>         DKML_BUILD_TRACE=OFF vendor/diskuv-ocaml/runtime/unix/platform-dune-exec.sh -p dev -b Debug \
        >>                 build --watch --terminal-persistence=clear-on-rebuild \
        >>                 bin lib   test ; \
        >>         sleep 5 || exit 0; \
        >> done
        >> Scanned 0 directories
        >> fswatch args = (recursive=true; event=[Removed; Updated; Created];
        >>                 include=[];
        >>                 exclude=[4913; /#[^#]*#$; ~$; /\..+; /_esy; /_opam; /_build];
        >>                 exclude_auto_added=[\\#[^#]*#$; \\\..+; \\_esy; \\_opam; \\_build; \\\.git; \\_tmp];
        >>                 paths=[.])
        >> inotifywait loc = C:\Users\beckf\AppData\Local\Programs\DiskuvOCaml\1\tools\inotify-win\inotifywait.exe
        >> inotifywait args = [--monitor; --format; %w\%f; --recursive; --event; delete,modify,create; --excludei; 4913|/#[^#]*#$|~$|/\..+|/_esy|/_opam|/_build|\\#[^#]*#$|\\\..+|\\_esy|\\_opam|\\_build|\\\.git|\\_tmp; .]
        >> Done: 0/0 (jobs: 0)===> Monitoring Z:\source\diskuv-ocaml-starter -r*.* for delete, modify, create
        >> Success, waiting for filesystem changes...

   Keep this Terminal open for as long as you have the local project (in this case ``diskuv-ocaml-starter``) open.
   It will watch your local project for any changes you make and then automatically build them.

   The automatic building uses
   `Dune's watch mode <https://dune.readthedocs.io/en/stable/usage.html#watch-mode>`_;
   its change detection and compile times should be almost instantaneous for most
   projects.

4. Open another Terminal. In this terminal you can quickly test some pieces of your code.
   To test ``lib/dune`` and ``lib/terminal_color.ml`` which come directly from the
   `Variants chapter of the Real World OCaml book <https://dev.realworldocaml.org/variants.html>`_ you would type:

   .. code-block:: ps1con

        PS Z:\source\diskuv-ocaml-starter> ./makeit shell-dev
        >> diskuv-ocaml-starter$

   .. code-block:: shell-session

        [diskuv-ocaml-starter]$ dune utop
        > ──────────┬─────────────────────────────────────────────────────────────┬──────────
        >           │ Welcome to utop version 2.8.0 (using OCaml version 4.12.0)! │
        >           └─────────────────────────────────────────────────────────────┘
        >
        > Type #utop_help for help about using utop.
        >
        > ─( 06:26:11 )─< command 0 >─────────────────────────────────────────{ counter: 0 }─
        > utop #
   .. code-block:: tcshcon

        utop #> #show Starter;;
        > module Starter : sig module Terminal_color = Starter.Terminal_color end
        utop #> #show Starter.Terminal_color;;
        > module Terminal_color = Starter.Terminal_colormodule Terminal_color :
        > sig
        >   type basic_color =
        >       Black
        >     | Red
        >     | Green
        >     | Yellow
        >     | Blue
        >     | Magenta
        >     | Cyan
        >     | White
        >   val basic_color_to_int : basic_color -> int
        >   val color_by_number : int -> string -> string
        >   val blue : string
        > end
        utop #> open Stdio;;
        utop #> open Starter.Terminal_color;;
        utop #> printf "Hello %s World!\n" blue;;
        > Hello Blue World!
        > - : unit = ()
        utop #> #quit;;
5. Open the source code ``bin/main.ml`` and ``lib/terminal_color.ml`` in the editor.
   When you hover over the text you should see type information popup.
6. Change the indentation of ``bin/main.ml`` and ``lib/terminal_color.ml``. Then
   press Shift + Alt + F (or go to View > Command Palette and type "Format Document").
   You should see your code reformatted.

Finished?

.. warning::

    The remainder of the SDK Projects documentation is not ready for consumption.
    And we are missing a tool to make your own SDK Project. **Stop here!**

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

Directory Layout
----------------

``diskuv-ocaml-starter`` is an example of the standard layout which looks like:

::

    .
    ├── bin
    │   ├── dune
    │   └── main.ml
    ├── build
    │   ├── _tools
    │   │   └── dev
    │   └── dev
    │       └── Debug
    ├── buildconfig
    │   └── dune
    │       ├── .gitignore
    │       ├── dune.env.workspace.inc
    │       ├── executable
    │       └── workspace
    ├── dune
    ├── dune-project
    ├── dune-workspace
    ├── lib
    │   ├── dune
    │   └── terminal_color.ml
    ├── LICENSE.txt
    ├── makeit
    ├── makeit.cmd
    ├── Makefile
    ├── README.md
    ├── opam
    ├── test
    │   ├── dune
    │   └── starter.ml
    └── vendor
        ├── diskuv-ocaml
        └── diskuv-sdk

*TODO* Explanation of each directory and file.

``Makefile``
~~~~~~~~~~~~

Configuration
^^^^^^^^^^^^^

The *Diskuv OCaml* specific configuration for your local project is at the top of your
``Makefile``.

Here is an example from the ``diskuv-ocaml-starter`` local project:

.. code-block:: make

    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    #                      RESERVED FOR DISKUV OCAML                        #
    #                         BEGIN CONFIGURATION                           #
    #                                                                       #
    #     Place this section before the first target (typically 'all:')     #
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

    # The subdirectory for the 'diskuv-ocaml' git submodule
    DKML_DIR = vendor/diskuv-ocaml

    # Verbose tracing of each command. Either ON or OFF
    DKML_BUILD_TRACE = OFF

    # The source directories. No platform-specific source code belongs here.
    OCAML_SRC_CROSSPLATFORM = bin lib

    # The test directories. No platform-specific source code belongs here.
    OCAML_TEST_CROSSPLATFORM = test

    # The names of the Windows-specific Opam packages (without the .opam suffix), if any.
    OPAM_PKGS_WINDOWS =

    # The source directories containing Windows-only source code, if any.
    OCAML_SRC_WINDOWS =

    # The test directories for Windows source code, if any.
    OCAML_TEST_WINDOWS =

    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    #                          END CONFIGURATION                            #
    #                      RESERVED FOR DISKUV OCAML                        #
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#


Targets
^^^^^^^

The *Diskuv OCaml* specific targets for your local project are at the bottom of your
``Makefile``.

Here is an example from the ``diskuv-ocaml-starter`` local project:

.. code-block:: make

    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    #                      RESERVED FOR DISKUV OCAML                        #
    #                            BEGIN TARGETS                              #
    #                                                                       #
    #         Place this section anywhere after the `all` target            #
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

    include $(DKML_DIR)/runtime/unix/standard.mk

    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    #                             END TARGETS                               #
    #                      RESERVED FOR DISKUV OCAML                        #
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

``buildconfig/dune/``
~~~~~~~~~~~~~~~~~~~~~

::

    .
    └── buildconfig
        └── dune
            ├── .gitignore
            ├── dune.env.workspace.inc
            ├── executable
            │   ├── 1-base.link_flags.sexp
            │   ├── 2-dev-all.link_flags.sexp
            │   ├── 3-all-Debug.link_flags.sexp
            │   ├── 3-all-Release.link_flags.sexp
            │   ├── 3-all-ReleaseCompatFuzz.link_flags.sexp
            │   ├── 3-all-ReleaseCompatPerf.link_flags.sexp
            │   ├── 4-dev-Debug.link_flags.sexp
            │   ├── 4-dev-Release.link_flags.sexp
            │   ├── 4-dev-ReleaseCompatFuzz.link_flags.sexp
            │   └── 4-dev-ReleaseCompatPerf.link_flags.sexp
            └── workspace
                ├── 1-base.ocamlopt_flags.sexp
                ├── 2-dev-all.ocamlopt_flags.sexp
                ├── 3-all-Debug.ocamlopt_flags.sexp
                ├── 3-all-Release.ocamlopt_flags.sexp
                ├── 3-all-ReleaseCompatFuzz.ocamlopt_flags.sexp
                ├── 3-all-ReleaseCompatPerf.ocamlopt_flags.sexp
                ├── 4-dev-Debug.ocamlopt_flags.sexp
                ├── 4-dev-Release.ocamlopt_flags.sexp
                ├── 4-dev-ReleaseCompatFuzz.ocamlopt_flags.sexp
                └── 4-dev-ReleaseCompatPerf.ocamlopt_flags.sexp

Setting Up An Existing Git Repository As a SDK Project
--------------------------------------------------------

The directory structure does _not_ need to look like the standard layout.

The requirements are:

1.  Use ``diskuv-ocaml`` as a submodule, as in:

    .. code-block:: ps1con

        PS1> git submodule add `
                https://gitlab.com/diskuv/diskuv-ocaml.git `
                vendor/diskuv-ocaml


    You can place the submodule in any directory (not just ``vendor``) but the basename
    should be ``diskuv-ocaml``.

2. There must be a ``dune-project`` in an ancestor directory of the ``diskuv-ocaml`` Git submodule.
   For example, it is fine to have:

   ::

        .git/
        .gitmodules
        a/
            b/
                dune-project
                src/
                    c/
                        d/
                            diskuv-ocaml/

*TODO* Complete.

Upgrading
---------

Run:

.. code-block:: ps1con

    PS1> .\vendor\diskuv-ocaml\runtime\windows\upgrade.ps1

If there is an upgrade of ``Diskuv OCaml`` available it will automate as much as possible,
and if necessary give you further instructions to complete the upgrade.

Static or Dynamic Linking
-------------------------

For Linux we use static linking, with no dependency on even the system C
runtime library.

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

Dev and Target Platforms
------------------------

All platforms except ``dev`` are **target** platforms. Target platforms
are built in a Docker sandbox and may have CPU emulation to get
different CPU architectures to work.

    If you have continuous integration hardware, use the target
    platforms!

The ``dev`` platform is your own development machine. There are key
differences from the target platforms:

-  When the dev platform is initialized through ``make init-dev`` extra
   software is downloaded to support IDEs.
-  We do our best to avoid *any* need for running Docker. Why? Docker,
   especially on Windows (and probably Apple M1s), has some difficult to
   work around limitations like having to switch between Windows and
   Linux containers, not having critical packages available for
   non-Linux containers, and oftentimes being incompatible with other
   virtualization (most of the Hyper-V incompatibilites have been fixed
   on Windows).

+------------------+------------------------------------------+
| Platform         | Description                              |
+==================+==========================================+
| dev              | Your own dev machine.                    |
+------------------+------------------------------------------+
| linux\_x86\_64   | AMD/Intel 64-bit Linux. Static linking   |
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

Makefile Targets
----------------

We use Makefile targets to help you keep track of everything.

    In Windows you use the command ``.\make`` rather than ``make``.
    Wherever you see ``make`` in this document you should replace it
    with ``.\make``.

For example to clean up builds:

-  ``make clean`` cleans all builds from all target platforms (including
   the dev platform) and cleans all tools (*use with caution!*)
-  ``make clean-dev-all`` cleans all builds from the dev platform and
   tools specific to the dev platform
-  ``make clean-all-Release`` cleans the Release build from all the
   target platforms (including the dev platform)
-  ``make clean-linux_x86_64-all`` cleans all builds from the
   linux\_x86\_64 target platform and tools specific to the target
   platform
-  ``make clean-linux_x86_64-Release`` clean the Release build from the
   linux\_x86\_64 target platform

There are many variations of ``make build`` all of which default to the
Debug build unless you explicitly specify:

-  ``make build`` builds all target platforms and all build types (but
   since you will *likely never* want to do this as a safeguard you must
   run ``make build FORCE_CRAZY_BUILD=ON``)
-  ``make build-all`` builds the Debug build for all target platforms
-  ``make build-dev`` builds the Debug build for the dev platform
-  ``make build-linux_x86_64`` builds the Debug build for the
   linux\_x86\_64 target platform
-  ``make build-dev-Release`` builds the Release build for the dev
   platform
-  ``make build-all-Release`` builds the Release build for all the
   target platforms
-  ``make build-linux_x86_64-Release`` build the Release build for the
   linux\_x86\_64 target platform

When you don't edit any of the Docker files and you have done at least
one ``make build-*`` you can subsequently use ``make quickbuild-*``
(which skips Docker building and installing tools and Opam dependencies)
for rapid development.

Building will install any new dependencies you list in your ``.opam``
files *as long as you commit those files* before running any
``make build-*``.

Building should be performed before testing. You can do:

-  ``make build-XXX`` followed by a ``make test-XXX`` (ex.
   ``make build-dev`` then ``make test-dev``)
-  ``make build-XXX test-XXX`` (ex. ``make build-dev test-dev``)
-  ``make test`` which will test everything that has already been built
   (useful when you are doing agile points burn-down development)

Use ``make report`` to see what has been built and all of its compiler
flags. If you need to send in a bug report **include the output of
``make report``**.

Build Directories
-----------------

The directory structure is the same regardless whether Windows or Linux
is used as the development platform, unless noted otherwise.

-  ``_build``
-  ``build``
-  ``_tools``

   -  ``common`` - Tools shared across all platforms, if any
   -  ``local`` - Shared platform local installation folder

      -  ``bin`` - Executables and scripts here are added to the build
         PATH

   -  ``opam-bootstrap`` - Native Windows version of Opam, on Windows
      build machines only

      -  ``bin`` - Install location containing Opam executable and
         shared DLLs

   -  ``dev`` - Tools for the dev platform
   -  ``local`` - Dev platform local installation folder

      -  ``bin`` - Executables and scripts here are added to the build
         PATH if the build is for the dev platform
      -  ``dune`` - Drop-in replacement for ``dune``
      -  ``opam`` - Drop-in replacement for ``opam``

   -  ``PLATFORM`` - Tools for a specific `target
      platform <#target-platforms>`__
   -  ``local`` - Target platform local installation folder

      -  ``bin`` - Executables and scripts here are added to the build
         PATH if the build is for the specific target platform
      -  ``dune`` - Drop-in replacement for ``dune``
      -  ``opam`` - Drop-in replacement for ``opam``

*Build PATH manipulation is done in ``.\scripts\unix\within-dev.sh`` and
``contexts\linux-build\sandbox-entrypoint.sh``*

OCaml
-----

Opam Packages
~~~~~~~~~~~~~

We use `Opam <https://opam.ocaml.org/>`__ as the package manager for
OCaml code.

Each `target platform <#target-platforms>`__ has its own Opam root
located at ``build/_tools/TARGET_PLATFORM/opam-root`` except the dev
platform which uses the default Opam root ``~/.opam``.

Each combination of `target platform <#target-platforms>`__ and `build
type <#build-types>`__ has its own Opam switch located at
``build/TARGET_PLATFORM/BUILD_TYPE/_opam``.

Dune Builds
~~~~~~~~~~~

OCaml code is built with `Dune <https://dune.readthedocs.io/>`__.

When using ``make build-dev``, which is the target used by the `IDE
Support <#ide-support>`__, or ``make build-dev-*`` *all* Dune build
artifacts are built. However all other ``make build-*`` targets will
build only the public artifacts that will be installed. This corresponds
to the ```all`` alias for the dev platform and the ``install`` alias for
the reproducible container
platforms <https://dune.readthedocs.io/en/stable/usage.html#built-in-aliases>`__.
We expect a development lifecycle that looks like:

-  You develop new executables and new libraries, build it and test it
   from your IDE and from the command line with
   ``make build-dev test-dev``
-  When the new executables and libraries are ready to be cross-platform
   tested, you can add a ``(public_name ...)`` to your `executable
   stanza <https://dune.readthedocs.io/en/stable/dune-files.html#executable>`__
   and/or your `library
   stanza <https://dune.readthedocs.io/en/stable/dune-files.html#library>`__.
   Any support files they need at runtime should be present with a
   `install
   stanza <https://dune.readthedocs.io/en/stable/dune-files.html#install>`__
   or by `defining a
   site <https://dune.readthedocs.io/en/stable/sites.html>`__.

The ``scripts/unix/platform-dune-exec.sh`` script is used to launch all
Dune builds:

-  It sets the Dune profile to ``TARGET_PLATFORM-BUILD_TYPE`` (ex.
   ``dune --profile linux_x86_64-Release ...``) so that Makefile, CMake
   and Dune can share the `target platform <#target-platforms>`__ and
   `build type <#build-types>`__. By default the profile is
   ``dev-Debug`` which is the "profile" setting in ``dune-workspace`` so
   that when you or and IDE runs ``dune ...`` *without*
   platform-dune-exec.sh Dune will use the Debug settings.
-  It sets the build directory (ex. ``dune --build-dir XXX ...``) to
   place the Dune build files in:
-  the standard ``_build`` directory for the ``dev-Debug`` platform.
-  ``build/dev/BUILD_TYPE/_dune`` for all non-\ ``Debug`` dev platforms
-  ``build/TARGET_PLATFORM/BUILD_TYPE/_dune`` for a reproducible
   container platform

    Typing ``dune clean`` from the command line will only clean the
    ``dev-Debug`` target! Since it can be insanely expensive to rebuild
    other CPU architectures through CPU emulation and compile with the
    Release optimizations, this is a good side-effect we intend to keep.
    Instead use one of several ``make clean-*`` targets described in the
    `Makefile Targets sections <#makefile-targets>`__

dune.env.workspace.inc
^^^^^^^^^^^^^^^^^^^^^^

We provide Dune our `target platform <#target-platforms>`__ and `build
type <#build-types>`__ specific compiler settings by including
``dune.env.workspace.inc`` in our ``dune`` files. For example the
``ocamlopt`` native code compiler will use the ``-O3`` flag when the
build type is `Release <#build-types>`__. ``dune.env.workspace.inc`` is
an autogenerated file produced by ``make dune.env.workspace.inc`` and
which gets generated automatically for any ``make init-dev``,
``make build-dev`` or ``make build-dev-Debug``.

``make dune.env.workspace.inc`` is responsible for generating an empty
compiler setting file in ``cmake/dune/*/*.sexp`` if there is a
permutation of `target platform <#target-platforms>`__ and `build
type <#build-types>`__ missing. **But** ultimately CMake is responsible
for placing it own C compiler settings into some critical .sexp files
(in particular the ``*all*.sexp``) files.

You are welcome to tweak any compiler setting file that does *not* have
a warning that it is autogenerated by CMake. For your and others sanity
please include a comment and a date on a separate line for any tweak in
a ``.sexp`` file. An example:

.. code:: lisp

    (-ccopt -static) ; Used in dune.env.workspace.inc.
    ; 2021-08-04: yourname@ - Static compilation makes executables portable across Linux.

That will make it easy to search for any tweaks (ex.
``grep -C10 '^[^(]' buildconfig/dune/*/*.sexp``).

    The compiler setting ``.sexp`` files are numbered in order of
    precedence. So ``1-*.ocamlopt_flags.sexp`` are included before
    ``2-*.ocamlopt_flags.sexp`` when Dune creates the flags for the
    ``ocamlopt`` native code compiler.

    In VS Code you can set the Language Mode to ``dune (dune)`` for
    syntax highlighting. Scheme and Lisp syntax highlighting should also
    work in other IDEs.

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

``text   Dune context:   { name = "default"   ; kind = "default"   ; profile = User_defined "Release"   ; merlin = true   ...   ; findlib_path =       [ External           "/home/user/source/diskuv-net-api/build/dev/Release/_opam/lib"       ]``

`Querying Merlin
configuration <https://dune.readthedocs.io/en/stable/usage.html#querying-merlin-configuration>`__
has more details. 2. The VS Code OCaml extension queries the default
Opam root ``~/.opam`` to present to the developer which Opam switches
are available (ie. run ``env - HOME=$HOME opam switch``). The VS Code
selected Opam switch (which can be saved in ``~/.vscode/settings.json``
as the ``"ocaml.sandbox":{"kind": "opam","switch": "..."}`` property) is
expected to contain the `the ocaml-lsp-server IDE Language
Server <https://github.com/ocaml/ocaml-lsp#readme>`__.

We provide IDE support by doing the following:

-  All the ``dev`` and ``dev-*`` targets (ie. run
   ``make build-dev-Release``) are accessible to VS Code (see point [2]
   above) by using the default Opam root ``~/.opam`` to register the
   Opam switches.
-  The ``dev`` target (an alias to the ``dev-Debug`` which you can run
   with ``make build-dev`` or ``make build-dev-Debug``) uses the default
   Dune ``_build/`` subdirectory of the project folder
   (``${workspaceFolder}`` in VS Code). This isn't strictly required for
   the VS Code OCaml extension but may help other IDEs and other VS Code
   extensions.
-  We do **not** define a ``./dune-workspace`` file containing "(context
   ...)" because doing so would require us to list *all* valid contexts.
   That is because if even one "(context ...)" is defined then
   ``dune build`` will ignore the Opam switch in the environment
   variable OPAMSWITCH we set based on the build type. So we do not
   define entries like the following:

``lisp   (context   (opam     (switch build/dev/Release)     (name dev-Release)     (merlin)     (profile Release)   ))``

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

Build Sandbox
~~~~~~~~~~~~~

The Build Sandbox is a musl-based chroot sandbox is simply an Alpine
distribution `which comes with simple instructions to create an
architecture specific
sandbox <https://wiki.alpinelinux.org/wiki/Alpine_Linux_in_a_chroot>`__.

See the `last section <#userland>`__ for how the Build Sandbox is carved
out of the container's userland.

We add Alpine packages that we need that include the executables:

-  being able to install new packages (ex. ``apk`` or ``apt-get``)
-  ``bash`` and ``make`` which are required for Opam
-  ``gcc`` / ``g++`` which is required for CMake and OCaml native
   compilation (ocamlopt)

Opam will need to be configured to *not* do sandboxing which would `fail
because nested sandboxes are poorly
supported <https://github.com/ocaml/opam/issues/4120>`__.

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

Inspecting a build sandbox is (you can change the PLATFORM and BUILDTYPE
arguments):

.. code:: bash

    scripts/unix/within-sandbox.sh -p linux_arm64 -b Debug
