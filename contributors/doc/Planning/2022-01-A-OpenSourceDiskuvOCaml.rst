2022-01 A - Open Source Diskuv OCaml
====================================

Objectives
    Peel out a maintainable Apache-licensed Diskuv OCaml distribution from the existing Diskuv SDK monorepo

Material Support
    This plan was implemented with the assistance of the `OCaml Software Foundation (OCSF) <http://ocaml-sf.org>`_,
    a sub-foundation of the `INRIA Foundation <https://www.inria.fr/>`_.

Context
    The monorepo https://gitlab.com/diskuv/diskuv-ocaml was originally the publication of Diskuv's internal
    cross-platform build system.

    The original intent was to quickly give other OCaml users a straightforward way to interact with OCaml
    on Windows when the traditional Windows distribution channel by fdopen@ reached end of life.
    There was already a sizable portion of the monorepo that installed and
    provided developer tooling for OCaml on Windows and other operating systems; that portion was called
    **Diskuv OCaml**. So all of the Diskuv OCaml source code was given an open-source Apache 2.0 license header
    except the installer (*task item LICENSE extends the Apache 2.0 license to the installer as well*), with
    the remaining cross-platform build system **Diskuv SDK** falling under a `Fair Source license <https://fair.io>`_.
    After Diskuv OCaml exited its preview phase the work could be done to move any Diskuv SDK specifics
    into another repository; all that would be left was Diskuv OCaml
    in the "diskuv-ocaml" repository (*task item MOVE*).

Tasks
    1. **LICENSE**: Extend Apache 2.0 license headers to Diskuv OCaml installer scripts. The parts of the installer
       that is specific to the cross-platform Diskuv SDK product (ie. installing CMake and vcpkg) will be removed
       and replaced with a plugin model (see PLUGIN task).
    2. **PLUGIN**: Design an interface for plugins to extend the installer, and an interface to discover plugins.
       The discovered plugins will be available to the Diskuv OCaml installer; since the installer is currently
       a CLI the plugins will simply expand the CLI options to include the plugin options. The plugin interface would
       expose which installation packages and which Opam modules must be installed and placed in the PATH.

       For this initial plan, the plugins will be git repositories (ex. ``github.com/xx/dkml-install-NAME``) with
       a file structure that matches the plugin interface, and the plugins will be "discovered" in a hard-coded list.

       .. note::
           *Forward looking:* If and when a graphical installer is available the plugins will be configurable
           in the UI.

           *Forward Looking:* A design goal is that other distributions (perhaps Coq?) that have need of custom Opam
           package installations on Windows could publish their own install plugins.

    3.  **MOVE_BASE**: Refactor relevant install code from diskuv-ocaml repository into a plugin implementation. The plugin would only
        be used on its own for CI testing (like Vagrant testing), and as a dependency for other plugins.

        Repository:
            gitlab.com/diskuv/diskuv-plugin-common (does not exist yet)

        Plugin Name:
            Base

        Dependencies:
            *none*

        Administrator Third Party Programs
            Visual Studio Build Tools

        User Third Party Programs
            MSYS2, Git, C# inotify (for `dune watch`), Cygwin (needed for bootstrapping new releases)

        Opam Packages
            ocaml-system, ocamlfind, dune

        Custom OCaml Programs
            :ref:`WithDkml` to shield the Unix world from Windows users

        Opam Pins
            GitLab CI will test and archive a map of ``ocaml_version -> (package, version) list``. The map
            is managed by hand each release with the help of some automation scripts, and will be re-used
            by the Developer plugin (which is why both plugins are in the same git repository).

            .. caution:: Cost Alert
                Currently the selection of the latest package versions that are compatible with Windows
                can't be automated away; it requires OCaml CI to block releases on failing Windows builds
                and other tasks that affect the entire OCaml ecosystem. Since that is out of our control,
                to minimize support costs we plan in the future to have a staggered downstream release model:
                the testing and maintenance cost of pinned versions is done with the non-open source plugins
                (Diskuv SDK) and then automatically after a few months of soak testing the pinned versions will
                be released to the Base + Developer plugins. Of course power users will always be able to change
                their Opam pins to whatever compatible versions they want.

        License
            Apache 2.0

    4.  **MOVE_DEVELOPER**: Refactor relevant install code from diskuv-ocaml repository into a plugin implementation. The plugin
        corresponds to what users use today with Diskuv OCaml.

        Repository:
            gitlab.com/diskuv/diskuv-plugin-common (does not exist yet)

        Plugin Name:
            Developer

        Dependencies:
            Base

        Administrator Third Party Programs
            Base

        User Third Party Programs
            Base

        Opam Packages
            Base + utop, ocaml-lsp-server, ocamlformat

        Custom OCaml Programs
            Base

        Opam Pins
            GitLab CI will test and archive a map of ``ocaml_version -> (package, version) list``. Same
            map as Base.

        License
            Apache 2.0

    5.  **MOVE_SDK**: Refactor relevant install code from diskuv-ocaml repository into a plugin implementation. The plugin
        has some programs that a typical developer does not need unless they are doing cross-platform development
        with C code (aka. Diskuv SDK).

        Repository:
            gitlab.com/diskuv/diskuv-plugin-sdk (does not exist yet)

        Plugin Name:
            Diskuv SDK

        Dependencies:
            Developer

        Administrator Third Party Programs
            Developer

        User Third Party Programs
            Developer + CMake, vcpkg, ninja

        Custom OCaml Programs
            Developer

        Opam Packages
            Developer

        Opam Pins
            GitLab CI will test and archive a map of ``ocaml_version -> (package, version) list``. The map
            is managed by hand each release with the help of some automation scripts. In the future the
            expectation is that these pinned versions will be distributed first to Diskuv SDK
            and then downstream to Base and Developer.

        License
            Fair Source

    6.  **MOVE_REMAINDER**: Leave only Diskuv OCaml in the diskuv-ocaml repository; everything else goes to other
        repositories. The big item left is to split the Diskuv OCaml and Diskuv SDK documentation;
        that will involve the creation of a standalone doc site Git repository that can auto-assemble one site
        out of the Diskuv OCaml repository + also the plugin repositories (Diskuv SDK). Then "diskuv-ocaml"
        can be left with a clean Apache 2.0 license that applies to the entire repository, which should contain
        the following:

        ``installtime/windows/`` *PLUGIN task will make heavy changes to this directory*
            Windows PowerShell scripts and modules to initiate admin + user installation of programs.
            This will undergo a revamp to support the PLUGIN task item; many of these scripts will move into
            the plugins themselves.

        ``installtime/unix/``
            Unix shell scripts to:

            * install OCaml. The OCaml reproducible build scripts do/will support cross-compilation (ie. Linux -> Android, macOS x86_64 to macOS ARM64)
              and will be included in Diskuv OCaml
            * install Opam including a system OCaml
            * install and configure Opam switches

        ``contributors/`` *MOVE_REMAINDER task will do some refactoring in this directory*
            * Unix Makefile to perform new releases
            * Documentation site for Diskuv OCaml and Diskuv SDK; this needs to be split up

        ``.github/, .gitlab/, vagrant/``
            GitLab CI and GitHub CI scripts to test installation, including testing end-to-end with Vagrant

        ``etc/opam-repositories/``
            Custom Opam repository (contains Windows patches, etc.) for Diskuv OCaml

        ``installtime/msys2/apps/``
            Tooling for Diskuv OCaml, including:

            * :ref:`WithDkml`
            * ``opam dkml ...`` plugin to create Opam switches specialised for Windows. *will move to Base plugin*
            * a shim of fswatch that delegates to inotify so ``dune watch`` can work on Windows. *will move to Base plugin*

    7.  **MAINTENANCE**:

        - *Changes every few months*. Each new OCaml version needs to be supported.
        - *Changes about twice a year*. Each new Core_kernel (Jane Street) release needs to be supported.
          Jane Street does not do Windows testing (very important) and they are stopping 32-bit testing
          (somewhat important, mainly for students and non-Western countries).
          *Why do we care? "Core" support is the most frequent ask from Diskuv OCaml Windows users*
        - *Averages one change a month*. Each new version of the developer tools (ocaml-lsp-server, dune, utop, ocamlformat, etc.; see Opam Packages above)
          needs to be tested on Windows.
        - *Averages one breakage a month*. Since Windows is not tested on OCaml CI and since we don't pin every package, inevitably
          a update to a transitive package will break on Windows.
        - *Changes twice a year*. Windows does not just do major version releases (Windows 10 -> Windows 11) but
          also does half-year releases (Windows 10 20H2 -> 21H1 -> 21H2) with supporting updates to Visual Studio
          (especially Windows SDK).
    8.  **SUPPORT_BUGS**: It is hard to anticipate future bugs but https://gitlab.com/diskuv/diskuv-ocaml/-/issues has
        the historical record: 9 issues at the end of 2021 with 8 closed. Closing those bugs amounted to approximately
        25% time overhead. That number needs to come down; the task item SUPPORT_CI_HARDWARE would squash a class of
        bugs that currently accounts for 1/3 of issues.
    9.  **SUPPORT_RELEASES**:
        Because of the open-source reliance on public CI the pre-release tests have been broken up into small pieces, and
        distributed between GitHub CI and GitLab CI. Doing a single release takes at minimum 12 hours babysitting the
        CI systems and restarting CI jobs to get past throttling limits. The plan is to take advantage of the move to a
        standalone open source project: we will ask for more CI testing hardware and higher time limits.
    10. **SUPPORT_CI_HARDWARE**: Extend pre-release testing to heterogeneous customer hardware. We have fairly comprehensive
        tests (ex. Vagrant end-to-end testing is available) but it requires hardware to do it correctly. The plan would
        involve acquiring two dedicated cloud instances of Windows to minimize the class of bugs related to:

        * Customer locale/language settings, which cannot be tested in an evaluation Windows VM because Microsoft only
          provides English evaluation VM images. Regression testing needs to cover at least French and Chinese Windows
          installations
        * Connectivity bugs, especially retry handling. Regression testing should be physically located in Europe to
          minimally exercise the latency/bandwidth degradation connecting to US servers.
