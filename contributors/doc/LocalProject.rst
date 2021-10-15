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
        >>         DKML_BUILD_TRACE=OFF vendor/diskuv-ocaml/runtime/unix/platform-dune-exec -p dev -b Debug \
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
   `Real World OCaml book <https://dev.realworldocaml.org/variants.html>`_ you would type:

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

At this point you should be able to complete the first
`5 chapters of Real World OCaml <https://dev.realworldocaml.org/toc.html>`_.

Finished?

*TODO* Missing a tool to make your own SDK Project.

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
    ├── make.cmd
    ├── Makefile
    ├── README.md
    ├── starter.opam
    ├── test
    │   ├── dune
    │   └── starter.ml
    └── vendor
        └── diskuv-ocaml

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

    # The names of the Opam packages (without the .opam suffix). No platform-specific packages belongs here.
    OPAM_PKGS_CROSSPLATFORM = starter

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
~~~~~~~~~~~~~~~~~~~~

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

CMake
-----

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
