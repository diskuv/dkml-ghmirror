Command Reference
=================

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
