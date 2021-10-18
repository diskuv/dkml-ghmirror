Command Reference
=================

with-dkml.exe
-------------

Summary
    Runs a specified command with an appropriate environment for a
    Microsoft/Apple/GNU compiler that includes headers and libraries
    of optionally vcpkg and optionally an :ref:`SDK Project <SDKProjects>`.

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

Argument CMD
    The name of the command to run. On Windows the command may come from MSYS2 (ex. ``bash``).
    The command does *not* need to an absolute path if it already part of the existing PATH
    or part of the modified PATH.

Sequence of operations
    #. The existing environment variable PATH is:

       - (MSYS2) Stripped of all path entries that end with ``\MSYS2\usr\bin``. For example, if the existing PATH is

         .. code-block:: doscon

            C:\Program Files\Miniconda3\Scripts;C:\MSYS2\usr\bin;C:\WINDOWS\system32;C:\WINDOWS

         the stripped PATH will be

         .. code-block:: doscon

            C:\Program Files\Miniconda3\Scripts;C:\WINDOWS\system32;C:\WINDOWS

       - (MSVC) Stripped of all path entries that end with ``\Common7\IDE`` or ``\Common7\Tools`` or ``\MSBuild\Current\Bin``
       - (MSVC) Stripped of all path entries that contain ``\VC\Tools\MSVC\``, ``\Windows Kits\10\bin\``, ``\Microsoft.NET\Framework64\`` or ``\MSBuild\Current\bin\``

    #. If and only if there is a configured MSYS2 environment, the ``VsDevCmd.bat``
       Microsoft batch script is run. The following environment variables are
       captured and passed to the ``CMD``:

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

    #. The following environment variables:

       * INCLUDE
       * CPATH
       * COMPILER_PATH
       * LIB
       * LIBRARY_PATH
       * PKG_CONFIG_PATH
       * PATH

       are:

       a. Stripped of all entries that contain a subdirectory ``vcpkg_installed``. For example, if the existing PATH is

          .. code-block:: doscon

             C:\project\vcpkg_installed\tools\pkg_config;C:\WINDOWS\system32;C:\WINDOWS

          the stripped PATH will be

          .. code-block:: doscon

             C:\WINDOWS\system32;C:\WINDOWS

          Similarly on Unix if the existing PATH is

          .. code-block:: bash

             /home/user/project/vcpkg_installed/tools/pkg_config:/usr/bin:/bin

          the stripped PATH will be

          .. code-block:: bash

             /usr/bin:/bin

       b. Stripped of all entries that contain both the subdirectories ``vcpkg`` and ``installed``. For example, if the existing PATH is

          .. code-block:: doscon

             C:\Program Files\vcpkg\installed\tools\pkg_config;C:\WINDOWS\system32;C:\WINDOWS

          the stripped PATH will be

          .. code-block:: doscon

             C:\WINDOWS\system32;C:\WINDOWS

          Similarly on Unix if the existing PATH is

          .. code-block:: bash

             /usr/local/share/vcpkg/installed/tools/pkg_config:/usr/bin:/bin

          the stripped PATH will be

          .. code-block:: bash

             /usr/bin:/bin

       c. If and only if vcpkg is configured, then:

          * ``<vcpkg_dir>/include`` is added to the ``INCLUDE`` environment value which is used
            `as system header paths by Microsoft's 'cl.exe' compiler <https://docs.microsoft.com/en-us/cpp/build/reference/cl-environment-variables?view=msvc-160>`_
          * ``<vcpkg_dir>/include`` is added to the ``CPATH`` environment value which is used
            `as system header paths by Apple's 'clang' compiler <https://clang.llvm.org/docs/CommandGuide/clang.html>`_
          * ``<vcpkg_dir>/include`` is added to the ``COMPILER_PATH`` environment value which is used
            `as system header paths by GNU's 'gcc' compiler <https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables>`_
          * ``<vcpkg_dir>/lib`` is added to the ``LIB`` environment value which is used
            `as system library paths by Microsoft's 'link.exe' linker <https://docs.microsoft.com/en-us/cpp/build/reference/linking?view=msvc-160#link-environment-variables>`_
          * ``<vcpkg_dir>/lib`` is added to the ``LIBRARY_PATH`` environment value which is used
            as system library paths by `GNU's 'gcc' compiler <https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html#Environment-Variables>`_
            and by `Apple's 'clang' compiler <https://reviews.llvm.org/D65880>`_
          * ``<vcpkg_dir>/lib/pkgconfig`` is added to the ``PKG_CONFIG_PATH`` environment value which is used
            to locate package header and library information by
            `pkg-config <https://linux.die.net/man/1/pkg-config>`_ and
            `pkgconf <https://github.com/pkgconf/pkgconf#readme>`_
          * ``<vcpkg_dir>/bin`` is added to the ``PATH`` environment value
          * ``<vcpkg_dir>/tools/<subdir>`` is added to the ``PATH`` environment value, for any ``<subdir>``
            containing an ``.exe`` or ``.dll``. For example, ``tools/pkgconf/pkgconf.exe`` and
            ``tools/pkgconf/pkgconf-3.dll``.

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

        # Create the Opam switch
        create-opam-switch.sh [-y] -b BUILDTYPE -p PLATFORM

        # Create the Opam switch in target directory.
        # Opam packages will be placed in `OPAMSWITCH/_opam`
        create-opam-switch.sh [-y] -b BUILDTYPE -t OPAMSWITCH

        # [Expert] Create the diskuv-system switch
        create-opam-switch.sh [-y] [-b BUILDTYPE] -s

Option -y
    Say yes to all questions.

Argument OPAMSWITCH
    The target Opam switch directory ``OPAMSWITCH`` or one of its ancestors must contain
    a ``dune-project`` file. When the switch is created, a subdirectory ``_opam``
    of ``OPAMSWITCH`` will be created that will contain your Opam switch packages.
    No other files or subdirectories of ``OPAMSWITCH`` will be modified.

Argument PLATFORM
    Must be ``dev``.

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
        On Windows this build type is the same as Release.

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
