Command Reference
=================

.. _WithDkml:

with-dkml.exe
-------------

Summary
   Runs a specified command with an appropriate environment for a
   Microsoft/Apple/GNU compiler that includes headers and libraries
   of optionally vcpkg and optionally third-party C packages.

   The environment variable ``DKML_3P_PREFIX_PATH`` can be set
   to a semicolon separated list of third-party directories,
   and any ``bin``, ``include``, ``lib`` and ``lib/pkgconfig`` subdirectories
   will be added to various compiler environment variables (more details below).

   The environment variable ``DKML_3P_PROGRAM_PATH`` can be set
   to a semicolon separated list of third-party directories, and any directory in it
   will be added to the PATH.

   An :ref:`SDK Project <SDKProjects>` automatically sets ``DKML_3P_PREFIX_PATH``
   and ``DKML_3P_PROGRAM_PATH`` to the `CMAKE_PREFIX_PATH <https://cmake.org/cmake/help/latest/variable/CMAKE_PREFIX_PATH.html>`_
   and `CMAKE_PROGRAM_PATH <https://cmake.org/cmake/help/latest/variable/CMAKE_PROGRAM_PATH.html>`_
   variables, respectively.

Usage
   .. code-block:: bash

      # Execute: CMD ARGS
      with-dkml CMD ARGS

Examples
   .. code-block:: bash

      # Enter a Bash session
      with-dkml CMD ARGS

      # Run Opam
      with-dkml opam

Configuration File ``dkmlvars-v2.sexp``
   This file must exist in one of the following directories:

   1. ``$LOCALAPPDATA/Programs/DiskuvOCaml/``
   2. ``$XDG_DATA_HOME/diskuv-ocaml/``
   3. ``$HOME/.local/share/diskuv-ocaml/``

   The directories are checked in order, and the first directory that contains ``dkmlvars-v2.sexp`` is used.

   The value will have been set automatically by the Windows Diskuv OCaml installer or by ``makeit init-dev``
   of :ref:`SDKProjects` for non-Windows OSes.

Configuration File ``vsstudio.dir.txt``
   This file is located using the same directory search as ``dkmlvars-v2.sexp``.
   It only needs to be present when Visual Studio has been detected, and is set automatically by
   the Windows Diskuv OCaml installer.

   The value is the location of the Visual Studio installation.
   Example: ``C:\DiskuvOCaml\BuildTools``

Configuration File ``vsstudio.msvs_preference.txt``
   This file is located using the same directory search as ``dkmlvars-v2.sexp``.
   It only needs to be present when Visual Studio has been detected, and is set automatically by
   the Windows Diskuv OCaml installer.

   The value is the ``MSVS_PREFERENCE`` environment variable that must be set
   to locate the Visual Studio installation when https://github.com/metastack/msvs-tools's or
   Opam's ``msvs-detect`` is invoked. Example: ``VS16.6``

Configuration File ``vsstudio.cmake_generator.txt``
   This file is located using the same directory search as ``dkmlvars-v2.sexp``.
   It only needs to be present when Visual Studio has been detected, and is set automatically by
   the Windows Diskuv OCaml installer.

   The value is a recommendation for which `CMake Generator <https://cmake.org/cmake/help/v3.22/manual/cmake-generators.7.html#visual-studio-generators>`_
   to use when setting up a CMake project initially.

Arguments CMD ARGS
   The name of the command to run, and any optional arguments.
   The command does *not* need to an absolute path if it already part of the existing PATH
   or part of the modified PATH.

   .. note::

      On Windows the command may come from MSYS2. For example, ``bash`` is a valid command.

Sequence of operations
   #. The environment variable ``DKML_TARGET_ABI`` will be detected through compiler probing and set to one of:

      - ``android_arm64v8a``
      - ``android_arm32v7a``
      - ``android_x86``
      - ``android_x86_64``
      - ``darwin_arm64``
      - ``darwin_x86_64``
      - ``linux_arm64``
      - ``linux_arm32v6``
      - ``linux_arm32v7``
      - ``linux_x86_64``
      - ``windows_x86_64``
      - ``windows_x86``
      - ``windows_arm64``
      - ``windows_arm32``

      The compiler probing is done when with-dkml is compiled. During Diskuv OCaml installation on Windows a
      ``with-dkml`` will be placed on the PATH; that will use the Visual Studio compiler detected at installation time.

      .. note::

         An :ref:`SDK Project <SDKProjects>` supports cross-compilation and can have many ``with-dkml`` binaries. Any
         ``./makeit *-<platform>-<buildtype>`` target like ``./makeit build-windows_x86-Debug`` or ``./makeit build-dev`` will first
         call a ``./makeit init-<platform>`` target; that will compile a ``with-dkml`` binary using a compiler specific to the given
         ``<platform>``. That means that ``DKML_TARGET_ABI`` will be ``<platform>``, except ``DKML_TARGET_ABI`` will
         be the results of probing the system compiler if ``<platform> = "dev"``.

      .. warning::

         Only ``windows_x86_64``, ``darwin_arm64`` and ``darwin_x86_64`` are supported today.

   #. If and only if the configuration file ``vsstudio.msvs_preference.txt`` exists then the ``MSVS_PREFERENCE`` environment variable will be set to its value
   #. If and only if the configuration file ``vsstudio.cmake_generator.txt`` exists then the ``CMAKE_GENERATOR_RECOMMENDED`` environment variable will be set to its value
   #. If and only if the configuration file ``vsstudio.dir.txt`` exists then the ``CMAKE_GENERATOR_INSTANCE_RECOMMENDED`` environment variable will be set to its value
   #. The existing environment variable PATH is:

      - (MSYS2) Stripped of all path entries that end with ``\MSYS2\usr\bin``. For example, if the existing PATH is

        .. code-block:: doscon

           C:\Program Files\Miniconda3\Scripts;C:\MSYS2\usr\bin;C:\WINDOWS\system32;C:\WINDOWS

        the stripped PATH will be

        .. code-block:: doscon

           C:\Program Files\Miniconda3\Scripts;C:\WINDOWS\system32;C:\WINDOWS

      - (MSVC) Stripped of all path entries that end with ``\Common7\IDE`` or ``\Common7\Tools`` or ``\MSBuild\Current\Bin``
      - (MSVC) Stripped of all path entries that contain ``\VC\Tools\MSVC\``, ``\Windows Kits\10\bin\``, ``\Microsoft.NET\Framework64\`` or ``\MSBuild\Current\bin\``

   #. If and only if there is a ``DiskuvOCamlMSYS2Dir`` configuration value in ``dkmlvars-v2.sexp``, the ``VsDevCmd.bat``
      Microsoft batch script is run. The following environment variables are
      captured and passed to the ``CMD ARGS``:

      * ``PATH``
      * ``DevEnvDir``
      * ``ExtensionSdkDir``
      * ``Framework40Version``
      * ``FrameworkDir``
      * ``Framework64``
      * ``FrameworkVersion``
      * ``FrameworkVersion64``
      * ``INCLUDE``
      * ``LIB``
      * ``LIBPATH``
      * ``UCRTVersion``
      * ``UniversalCRTSdkDir``
      * ``VCIDEInstallDir``
      * ``VCINSTALLDIR``
      * ``VCToolsInstallDir``
      * ``VCToolsRedistDir``
      * ``VCToolsVersion``
      * ``VisualStudioVersion``
      * ``VS140COMNTOOLS``
      * ``VS150COMNTOOLS``
      * ``VS160COMNTOOLS``
      * ``VSINSTALLDIR``
      * ``WindowsLibPath``
      * ``WindowsSdkBinPath``
      * ``WindowsSdkDir``
      * ``WindowsSDKLibVersion``
      * ``WindowsSdkVerBinPath``
      * ``WindowsSDKVersion``

   #. The PATH is stripped of all directories in the semicolon separated environment variable ``DKML_3P_PROGRAM_PATH``.
      For example, on Windows if the existing ``PATH`` is

      .. code-block:: doscon

         C:\Project\tools\local\bin;C:\Temp\share;C:\WINDOWS\system32;C:\WINDOWS

      and the environment variable ``DKML_3P_PROGRAM_PATH`` is ``C:\Project\tools\local;C:\Temp\share``, the stripped ``PATH`` will be

      .. code-block:: doscon

         C:\Project\tools\local\bin;C:\WINDOWS\system32;C:\WINDOWS

   #. Each directory in ``DKML_3P_PROGRAM_PATH`` is added to the ``PATH`` environment variable

   #. The following environment variables:

      * INCLUDE
      * CPATH
      * COMPILER_PATH
      * LIB
      * LIBRARY_PATH
      * PKG_CONFIG_PATH
      * PATH

      are:

      a. Stripped of all directories in the semicolon separated environment variable ``DKML_3P_PREFIX_PATH`` or any of its subdirectories.
         For example, on Windows if the existing ``INCLUDE`` is

         .. code-block:: doscon

            C:\Project\tools\local\include;C:\Temp\share;C:\WINDOWS\system32;C:\WINDOWS

         and the environment variable ``DKML_3P_PREFIX_PATH`` is ``C:\Project\tools\local;C:\Temp\share``, the stripped ``INCLUDE`` will be

         .. code-block:: doscon

            C:\WINDOWS\system32;C:\WINDOWS

      b. For each directory ``$DIR`` in ``DKML_3P_PREFIX_PATH``:

         * ``$DIR/include`` is added to the ``INCLUDE`` environment variable which is used
           `as system header paths by Microsoft's 'cl.exe' compiler <https://docs.microsoft.com/en-us/cpp/build/reference/cl-environment-variables?view=msvc-160>`_
         * ``$DIR/include`` is added to the ``CPATH`` environment variable which is used
           `as system header paths by Apple's 'clang' compiler <https://clang.llvm.org/docs/CommandGuide/clang.html>`_
         * ``$DIR/include`` is added to the ``COMPILER_PATH`` environment variable which is used
           `as system header paths by GNU's 'gcc' compiler <https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables>`_
         * ``$DIR/lib`` is added to the ``LIB`` environment variable which is used
           `as system library paths by Microsoft's 'link.exe' linker <https://docs.microsoft.com/en-us/cpp/build/reference/linking?view=msvc-160#link-environment-variables>`_
         * ``$DIR/lib`` is added to the ``LIBRARY_PATH`` environment variable which is used
           as system library paths by `GNU's 'gcc' compiler <https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables>`_
           and `Apple's 'clang' compiler <https://clang.llvm.org/docs/CommandGuide/clang.html>`_
         * ``$DIR/lib/pkgconfig`` is added to the ``PKG_CONFIG_PATH`` environment variable which is used
           to locate package header and library information by
           `pkg-config <https://linux.die.net/man/1/pkg-config>`_ and
           `pkgconf <https://github.com/pkgconf/pkgconf#readme>`_
         * ``$DIR/bin`` is added to the ``PATH`` environment variable

Windows - Inside MSYS2 Shell
----------------------------

The MSYS2 Shell is available when you run ``./makeit shell`` or one of its
flavors (ex. ``./makeit shell-dev``) within a Local Project.

.. warning::

    Most commands you see in ``/opt/diskuv-ocaml/installtime`` are for internal
    use and may change at any time. Only the ones that are documented here
    are for your use.

.. _Command-create-opam-switch:

``/opt/diskuv-ocaml/installtime/create-opam-switch.sh``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Summary
    Creates an Opam switch.

Usage
    .. code-block:: bash

        # Help
        create-opam-switch.sh -h

        # Create the Opam switch in target directory.
        # Opam packages will be placed in `OPAMSWITCH/_opam`
        create-opam-switch.sh [-y] -p DKMLABI -b BUILDTYPE -d OPAMSWITCH

        # [Expert] Create the dkml switch
        create-opam-switch.sh [-y] -p DKMLABI [-b BUILDTYPE] -s

Option -y
    Say yes to all questions.

Argument OPAMSWITCH
    The target Opam switch directory ``OPAMSWITCH`` or one of its ancestors must contain
    a ``dune-project`` file. When the switch is created, a subdirectory ``_opam``
    of ``OPAMSWITCH`` will be created that will contain your Opam switch packages.
    No other files or subdirectories of ``OPAMSWITCH`` will be modified.

Argument DKMLABI
    An ABI like ``windows_x86_64``.

Argument BUILDTYPE
    Controls how executables and libraries are created with compiler and linker flags.
    Must be one of the following values:

    Debug
        For day to day development. Unoptimized code which is the quickest to build.

    Release
        Highly optimized code.

    ReleaseCompatPerf
        Mostly optimized code. Slightly less optimized than ``Release`` but compatible
        with the Linux tool `perf <https://perf.wiki.kernel.org/index.php/Main_Page>`_.
        On non-Linux systems this build type is the same as Release.

        Expert: Enables the `frame pointer <https://dev.realworldocaml.org/compiler-backend.html#using-the-frame-pointer-to-get-more-accurate-traces>`_
        which gets more accurate traces.

    ReleaseCompatFuzz
        Mostly optimized code. Slightly less optimized than ``Release`` but compatible
        with the `afl-fuzz tool <https://ocaml.org/manual/afl-fuzz.html>`_.

Complements
    ``opam switch create``
        If you use ``opam switch create`` directly, you will be missing several
        `Opam pinned versions <https://opam.ocaml.org/doc/Usage.html#opam-pin>`_
        which lock your OCaml packages to Diskuv OCaml supported versions.
