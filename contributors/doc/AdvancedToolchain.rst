MSVC + MSYS2 toolchain
======================

    TLDR: Some OCaml packages rely on C libraries or embed C code. These
    C-reliant packages may need to be patched to work with the
    MSVC + MSYS2 toolchain used by *Diskuv OCaml*.

Differences
-----------

Many OCaml packages that use the C language have assumed a GCC toolchain
on a UNIX system. If you do encounter problems compiling these packages
with the *Diskuv OCaml* distribution, they are likely due to

1. The GCC toolchain vs the Microsoft Studio (MSVC) toolchain. GCC has
   non-standard extensions to the C language that MSVC's CL.EXE compiler
   does not support.

   > This situation commonly presents itself as a ``syntax error``

2. UNIX vs Windows paths. UNIX paths have forward slashes while Windows paths
   have backslashes. Most Windows programs, and definitely the MSYS2 provided
   programs, support both Windows and Unix paths. However,

   * a) Often UNIX commands for OCaml builds are interpreted by
     the `bash` or `dash` shell; those shells will interpret a backslash as an
     escape character.

     > This situation commonly presents itself as garbled text, like
     > `C:ProgramFilesMicrosoftNET`

   * b) Windows paths commonly have spaces in them (ex. `C:\Program Files`) while
     spaces in UNIX paths are fairly uncommon.

     > This situation commonly presents itself as an invalid argument or file not found. For
     > example `someprog --option1 C:\Program Files` would behave as if `someprog` had "option1"
     > with the value `C:Program` and `Files` was an argument.
3. Windows does not support the same APIs that Linux supports. These APIs include but are not
   limited to POSIX and GLIBC APIs.

   > This situation commonly presents itself as ``Cannot open include file: 'xxx.h': No such file or directory``

.. note::

    **Why use the Microsoft toolchain at all?**

    OCaml lives in a software ecosystem where there are few OCaml packages but many orders of magnitude
    more C packages. And although GCC-linked libraries are generally interchangable with MSVC-linked libraries,
    they are not 100% interchangable especially when it comes to shared libraries and C++ code. There is very
    little reason to have very difficult-to-diagnose problems with your programs in production or in your
    customer's hands simply because we chose to use a lesser supported compiler on Windows. We'd think
    the choices should center on when to use OCaml versus when to use C (or Rust, etc.), rather than add
    more complexity with an unusual (for Windows) compiler toolchain. We'd say somewhat similar things for why we'd want
    to compile with `clang` on macOS/iOS rather than `gcc`, although the argument for `clang` is much weaker
    because `clang` is newer than Microsoft's toolchain and Apple used to work well with `gcc`.

Real example of resolving toolchain problems
--------------------------------------------

*We picked this real package because it was the first package which gave us an opportunity to cover all three common
toolchain problems while writing the documentation. We patched the package because we use it and like it!*

Everything you see below came while using the `Creating your own package patches`_ steps.

Problem 1
~~~~~~~~~

First we replicated the problem we had during compilation by following the boilerplate `opam source` and
`git` steps from `Creating your own package patches`_ steps.

.. code-block:: ps1con

    PS Z:\source\diskuv-ocaml-starter> ./makeit build-dev
    >> ... some errors in package core_kernel.v0.14.2 ...

    PS Z:\source\diskuv-ocaml-starter> ./makeit shell-dev
    >> [diskuv-ocaml-starter]$

.. code-block:: shell-session
    :linenos:
    :emphasize-lines: 15,17,18

    [diskuv-ocaml-starter]$ cd /tmp
    [tmp]$ opam source core_kernel.v0.14.2
    [tmp]$ cd core_kernel.v0.14.2
    [core_kernel.v0.14.2]$ [ -z "$USERPROFILE" ] || HOME=$(cygpath -au "$USERPROFILE")
    [core_kernel.v0.14.2]$ git init && git config core.safecrlf false && git add -A
    [core_kernel.v0.14.2]$ git commit -m "Baseline for patch"
    [core_kernel.v0.14.2]$ git tag baseline-patch

    [core_kernel.v0.14.2]$ opam install ./core_kernel.opam -v --debug-level 2
    > #=== ERROR while compiling core_kernel.v0.14.0 ================================#
    > # context     2.1.0 | win32/x86_64 | ocaml-variants.4.12.0+msvc64+msys2 | pinned(git+file://C:/Users/you/AppData/Local/Programs/DiskuvOCaml/1/tools/MSYS2/tmp/core_kernel.v0.14.2#master#6e50f367)
    > # path        Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\.opam-switch\build\core_kernel.v0.14.0
    > # command     Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\bin\dune.exe build -p core_kernel -j 11
    > # exit-code   1
    > # env-file    ~\.opam\log\core_kernel-44284-942604.env
    > # output-file ~\.opam\log\core_kernel-44284-942604.out
    > ### output ###
    > #         bash src/config.h,src/rt-flags (exit 1)
    > # (cd _build/default/src && C:\Users\you\AppData\Local\Programs\DiskuvOCaml\1\tools\MSYS2\usr\bin\bash.exe -e -u -o pipefail -c "cp Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\jst-config\config.h Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\jst-config\rt-flags .")
    > # cp: cannot stat 'Z:sourcediskuv-ocaml-starterbuilddevDebug_opamlibjst-configconfig.h': No such file or directory
    > # cp: cannot stat 'Z:sourcediskuv-ocaml-starterbuilddevDebug_opamlibjst-configrt-flags': No such file or directory

We aren't big fans of exploring code from the command line, so we opened the package in Visual Studio Code:

.. code-block:: shell-session

    [core_kernel.v0.14.2]$ code .

We searched the code (Ctrl-Shift-F in Visual Studio Code) for ``rt-flags`` (just search for uncommon text strings that you
see in the ERROR). That gave the code in `src/dune <https://github.com/janestreet/core_kernel/blob/a89864f312808390a84a2ca1e8b55dc2dc82836c/src/dune#L1-L2>`_
that what was invoking the highlighted lines above:

.. code-block:: lisp
    :linenos:
    :emphasize-lines: 2

    (rule (targets config.h rt-flags) (deps)
        (action (bash "cp %{lib:jst-config:config.h} %{lib:jst-config:rt-flags} .")))

From our toolchain `Differences`_ we can see the explanation of

    This situation commonly presents itself as garbled text

matches the ERROR description, and the solution for that difference is to introduce quotes.

We changed the code to:

.. code-block:: lisp
    :linenos:
    :emphasize-lines: 2

    (rule (targets config.h rt-flags) (deps)
        (action (bash "cp '%{lib:jst-config:config.h}' '%{lib:jst-config:rt-flags}' .")))

and then committed the code:

.. code-block:: shell-session

    [core_kernel.v0.14.2]$ git commit -m 'Put quotes around jst-config invocation in bash' src/

Problem 2
~~~~~~~~~

We check to see if Problem 1 is fixed, and discover a second problem:

.. code-block:: shell-session
    :linenos:
    :emphasize-lines: 4-8

    [core_kernel.v0.14.2]$ opam install ./core_kernel.opam -v --debug-level 2
    > - (cd _build/default/src && C:\DiskuvOCaml\BuildTools\VC\Tools\MSVC\14.29.30133\bin\HostX64\x64\cl.exe -nologo -O2 -Gy- -MD -D_CRT_SECURE_NO_DEPRECATE -nologo -O2 -Gy- -MD -D_LARGEFILE64_SOURCE -I Z:/source/diskuv-ocaml-starter/build/dev/Debug/_opam/lib/ocaml -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base\base_internalhash_types -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base\caml -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base\md5 -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base\shadow_stdlib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base_bigstring -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base_quickcheck -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\bin_prot -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\bin_prot\shape -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\fieldslib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\jane-street-headers -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\parsexp -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_assert\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_bench\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_compare\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_enumerate\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_expect\collector -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_expect\common -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_expect\config -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_expect\config_types -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_hash\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_here\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_inline_test\config -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_inline_test\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_module_timer\runtime -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\ppx_sexp_conv\runtime-lib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\sexplib -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\sexplib0 -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\splittable_random -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\stdio -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\time_now -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\typerep -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\variantslib -I ../base_for_tests/src /Fogc_stubs.obj -c gc_stubs.c)
    > - gc_stubs.c
    > - gc_stubs.c(16): error C2146: syntax error: missing ')' before identifier '__attribute__'
    > - gc_stubs.c(16): error C2061: syntax error: identifier '__attribute__'
    > - gc_stubs.c(16): error C2059: syntax error: ';'
    > - gc_stubs.c(16): error C2059: syntax error: ')'
    > - gc_stubs.c(17): error C2054: expected '(' to follow 'unused'

The highlighted lines are clear about which file and which line numbers are the cause,
so we opened `gc_stubs.c <https://github.com/janestreet/core_kernel/blob/a89864f312808390a84a2ca1e8b55dc2dc82836c/src/gc_stubs.c#L16-L17>`_
in Visual Studio Code:

.. code-block:: c
    :linenos:
    :emphasize-lines: 16-17

    #define CAML_INTERNALS
    #include <caml/memory.h>
    #include <caml/gc_ctrl.h>

    static intnat minor_words(void)
    {
        return (intnat) (caml_stat_minor_words +
                    (double) (caml_young_end - caml_young_ptr));
    }

    static intnat promoted_words(void)
    {
        return ((intnat) caml_stat_promoted_words);
    }

    CAMLprim value core_kernel_gc_minor_words(value unit __attribute__((unused)))
    {
        return Val_long(minor_words());
    }

From our toolchain `Differences`_ we can see the explanation of

    This situation commonly presents itself as a ``syntax error``

matches the ERROR description, and the solution for that difference is to remove
the GCC non-standard extension ``__attribute__((unused))``.

We changed all the code that ``__attribute__((unused))`` to look like:

.. code-block:: c
    :linenos:
    :emphasize-lines: 5-12,25-26

    #define CAML_INTERNALS
    #include <caml/memory.h>
    #include <caml/gc_ctrl.h>

    #if defined(_MSC_VER) && _MSC_VER >= 1500
    # define __unused(x) __pragma( warning (push) ) \
        __pragma( warning (disable:4189 ) ) \
        x \
        __pragma( warning (pop))
    #else
    # define __unused(x) x __attribute__((unused))
    #endif

    static intnat minor_words(void)
    {
        return (intnat) (caml_stat_minor_words +
                    (double) (caml_young_end - caml_young_ptr));
    }

    static intnat promoted_words(void)
    {
        return ((intnat) caml_stat_promoted_words);
    }

    CAMLprim value core_kernel_gc_minor_words(__unused(value unit))
    {
        return Val_long(minor_words());
    }

We actually got the ``if defined`` macros from other OCaml code, but the top
`top Google search <https://stackoverflow.com/questions/52058457/visual-studio-equivelent-of-gcc-attribute-unused-in-c11-or-lower>`_
for ``msvc __attribute__((unused))`` as of 2021-08-23 turns up something similar.

As always we commit the code:

.. code-block:: shell-session

    [core_kernel.v0.14.2]$ git commit -a -m 'Do not assume the use of GCC'

Problem 3
~~~~~~~~~

We check to see if Problem 2 is fixed, and discover a third problem:

.. code-block:: shell-session
    :linenos:
    :emphasize-lines: 11

    [core_kernel.v0.14.2]$ opam install ./core_kernel.opam -v --debug-level 2
    > #=== ERROR while compiling core_kernel.v0.14.0 ================================#
    > # context     2.1.0 | win32/x86_64 | ocaml-variants.4.12.0+msvc64+msys2 | pinned(git+file://C:/Users/you/AppData/Local/Programs/DiskuvOCaml/1/tools/MSYS2/tmp/core_kernel.v0.14.2#master#a5cf803a)
    > # path        Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\.opam-switch\build\core_kernel.v0.14.0
    > # command     Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\bin\dune.exe build -p core_kernel -j 11
    > # exit-code   1
    > # env-file    ~\.opam\log\core_kernel-1900-c83ce4.env
    > # output-file ~\.opam\log\core_kernel-1900-c83ce4.out
    > source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base -I Z:\source\diskuv-ocaml-starter\build\dev\Debug\_opam\lib\base\base_in[...]
    > # md5_stubs.c
    > # md5_stubs.c(1): fatal error C1083: Cannot open include file: 'unistd.h': No such file or directory

We are experts now, so we open `md5_stubs.c <https://github.com/janestreet/core_kernel/blob/a89864f312808390a84a2ca1e8b55dc2dc82836c/src/md5_stubs.c#L1>`_
in Visual Studio Code:

.. code-block:: c
    :linenos:
    :emphasize-lines: 1

    #include <unistd.h>
    #include <errno.h>
    #include <caml/alloc.h>
    #include <caml/memory.h>
    #include <caml/mlvalues.h>
    #include <caml/signals.h>
    #include <caml/bigarray.h>
    #include <core_params.h>

From our toolchain `Differences`_ we can see the explanation of

    This situation commonly presents itself as ``Cannot open include file: 'xxx.h': No such file or directory``

matches the ERROR description, and the solution for that difference is to place the non-Windows header with
a Windows header.

But at the moment we don't know why the file needs ``unistd.h`` at all, so we comment out that line completely
from all the files which include it, like so:

.. code-block:: c
    :linenos:
    :emphasize-lines: 1

    // #include <unistd.h>
    #include <errno.h>
    #include <caml/alloc.h>
    #include <caml/memory.h>
    #include <caml/mlvalues.h>
    #include <caml/signals.h>
    #include <caml/bigarray.h>
    #include <core_params.h>

And then commit and rebuild:

.. code-block:: shell-session
    :linenos:
    :emphasize-lines: 3

    [core_kernel.v0.14.2]$ git commit -a -m 'Remove unistd.h'
    [core_kernel.v0.14.2]$ opam install ./core_kernel.opam -v --debug-level 2
    > # bigstring_stubs.c(39): fatal error C1083: Cannot open include file: 'endian.h': No such file or directory

We've got another non-Windows header, and we comment that out and rebuild:

.. code-block:: shell-session
    :linenos:
    :emphasize-lines: 3

    [core_kernel.v0.14.2]$ git commit -a -m 'Remove endian.h'
    [core_kernel.v0.14.2]$ opam install ./core_kernel.opam -v --debug-level 2
    > ✶ installed core_kernel.v0.14.0
    > ...
    > Done.
    > 01:49.074  ENV                    Environment is up-to-date
    > ...

Somewhat surprisingly the ``opam install`` completes successfully! Sometimes Windows header files include
more C declarations than the equivalent Linux header, but other times we would have had to do
a Google search for the corresponding Windows header.

We'll clean up the last two commits to look like:

.. code-block:: c

    :linenos:
    :emphasize-lines: 1

    #ifndef _MSC_VER
    # include <unistd.h>
    #endif
    #include <errno.h>
    #include <caml/alloc.h>
    #include <caml/memory.h>
    #include <caml/mlvalues.h>
    #include <caml/signals.h>
    #include <caml/bigarray.h>
    #include <core_params.h>

And then we create the Opam file and patch file from the `Creating your own package patches`_ instructions:

.. code-block:: shell-session

    [core_kernel.v0.14.2]$ git commit -a -m 'Skip unistd.h and endian.h if MSVC toolchain'
    [core_kernel.v0.14.2]$ opam install ./core_kernel.opam -v --debug-level 2
    [core_kernel.v0.14.2]$ opam remove core_kernel
    > <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    > λ removed   core_kernel.v0.14.0
    > Done.
    [core_kernel.v0.14.2]$ opam pin remove core_kernel
    > Ok, core_kernel is no longer pinned to git+file://C:/Users/you/AppData/Local/Programs/DiskuvOCaml/1/tools/MSYS2/tmp/core_kernel.v0.14.2#master (version v0.14.0)
    [core_kernel.v0.14.2]$ git diff baseline-patch > /tmp/custom.patch
    [core_kernel.v0.14.2]$ opam show core_kernel -f opam-file > /tmp/opam
    [core_kernel.v0.14.2]$ echo 'patches: ["custom.patch"]' >> /tmp/opam

`Creating your own package patches`_ shows where to place these ``/tmp/opam`` and ``/tmp/custom.patch``
files, and you can see the final results in
https://gitlab.com/diskuv/diskuv-ocaml/-/tree/main/vendor/diskuv-opam-repository/packages/core_kernel/core_kernel.v0.14.2

The last step is to update the Opam package repository with our newly copied patches:

.. code-block:: shell-session

    [core_kernel.v0.14.2]$ opam update diskuv-1.1.0

Creating your own package patches
---------------------------------

    This procedure **will not work** if the package already has a patch.
    For example you can't use this procedure if the package is present
    in ``vendor/diskuv-opam-repository`` and has
    ``patches: [...]`` in its ``opam`` file. You may be able to remove
    the ``patches`` clause and then do a
    ``opam update diskuv-1.1.0 && opam upgrade`` before doing any of these
    instructions, but that procedure has not been tested.

The https://gitlab.com/diskuv/diskuv-ocaml repository has a `vendor/diskuv-opam-repository` folder
containing all of the patches necessary for the Microsoft Visual Studio toolchain on MSYS2 to work.
Your local project vendors that repository as a git submodule at `vendor/diskuv-ocaml` (run `git submodule status`
to see it). You can fork the https://gitlab.com/diskuv/diskuv-ocaml repository (assuming you meet the license requirements
of course), edit it, and update your git submodule with `git submodule set-url vendor/diskuv-ocaml https://YOUR_GIT_FORK`.

Follow these instructions to add patches to your own fork.

FIRST, find which OCaml package is failing and check out that package with:

.. code:: bash

    opam source PACKAGE_NAME

The version of the package is important. Using the above command
will check out the *version* of the package that Opam thinks should
be installed, which is almost always what you should be patching.

SECOND, create a local git repository; we'll be using ``git`` to create
our patch:

.. code:: bash

    cd PACKAGE_NAME.PACKAGE_VERSION
    [ -z "$USERPROFILE" ] || HOME=$(cygpath -au "$USERPROFILE")
    git init && git config core.safecrlf false && git add -A
    git commit -m "Baseline for patch"
    git tag baseline-patch

*If ``git init`` fails because Git is already there, skip to
``git tag baseline-patch`` and then proceed to the THIRD step*

THIRD, verify you can recreate the error:

.. code:: bash

    ls *.opam
    basename $PWD
    opam install ./PACKAGE_NAME.opam -v --debug-level 2

*There may be many ``.opam`` files. Use the one that matches the
``basename`` without the version number*

FOURTH,

Fix the error in the source code with your favorite editor, do a
``git commit`` and test it with:

.. code:: bash

    opam install ./PACKAGE_NAME.opam

**Doing a ``git commit`` is required**. Do not get concerned if you
end up with a long string of bad ``git commit``\ s; they will be
squashed in the SIXTH step.

Repeat until you get a successful install.

FIFTH, remove your edits so they do not hide the ``diskuv-opam-repository``
repository:

.. code:: bash

    opam remove PACKAGE_NAME
    opam pin remove PACKAGE_NAME

SIXTH, create a patch:

.. code:: bash

    git diff baseline-patch > /tmp/custom.patch

SEVENTH, create a self-contained ``opam`` file:

.. code:: bash

    opam show PACKAGE_NAME -f opam-file > /tmp/opam
    echo 'patches: ["custom.patch"]' >> /tmp/opam

    cat /tmp/opam

There should be a ``url { src: "..." checksum: "" }`` in your file.
If not, make sure you ran ``opam pin remove PACKAGE_NAME``

EIGHTH, create/modify the ``diskuv-opam-repository`` directory (on Windows PowerShell look in
``$env:DiskuvOCamlHome\vendor\drd\repos``; in general look wherever
``opam repo list --all | awk '$1=="diskuv"{print $2}'`` tells you):

.. code:: text

    etc
    └── repos
        └── diskuv-opam-repository
            ├── packages
            │   └── <PACKAGE_NAME>
            │       └── <PACKAGE_NAME.PACKAGE_VERSION>
            │           ├── files
            │           │   └── custom.patch           <==  Copy /tmp/custom.patch
            │           └── opam                       <==  Copy /tmp/opam
            └── repo

    For more details visit
    https://opam.ocaml.org/doc/Manual.html#Package-definitions

NINTH, update your Opam switch with your new ``diskuv-opam-repository`` patch:

.. code:: bash

    opam update diskuv-1.1.0

*See `Troubleshooting: opam update diskuv <#opam-update-diskuv>`__ if
this fails*

TENTH, add your new package to the "PINNED\_PACKAGES" variable in
``vendor/drd/src/unix/create-opam-switch.sh`` if it is not there already.

Done! Go ahead and continue with your normal build.
If your patches are useful to the open source community, please consider
sending a Pull Request.

--------------

Troubleshooting
~~~~~~~~~~~~~~~

opam update diskuv
^^^^^^^^^^^^^^^^^^

If after ``opam update diskuv-1.1.0`` you get:

.. code:: text

    [diskuv] synchronised from file://Z:/somewhere/vendor/diskuv-opam-repository
    [ERROR] Could not update repository "diskuv": "Z:\\somewhere\\build\\_tools\\common\\MSYS2\\usr\\bin\\patch.exe -p1 -i C:\\Users\\user\\.opam\\log\\patch-28544-5495c0" exited with code 1

then rerun the command as ``opam update diskuv-1.1.0 -vv``. That will give you
something like:

.. code:: text

    - patching file packages/dune-configurator/dune-configurator.2.9.0/files/custom.patch
    - patching file packages/dune-configurator/dune-configurator.2.9.0/files/v1.patch
    - Reversed (or previously applied) patch detected!  Assume -R? [n]
    - Apply anyway? [n]
    - Skipping patch.
    - 1 out of 1 hunk ignored -- saving rejects to file packages/dune-configurator/dune-configurator.2.9.0/files/v1.patch.rej
    - patching file packages/dune-configurator/dune-configurator.2.9.0/opam
    - Hunk #1 FAILED at 47 (different line endings).
    - 1 out of 1 hunk FAILED -- saving rejects to file packages/dune-configurator/dune-configurator.2.9.0/opam.rej

Anything with a
``saving rejects to file packages/SOME_PACKAGE_NAME/.../*.rej`` is
showing a broken package. Just remove the broken package with
``opam remove SOME_PACKAGE_NAME`` and
``opam pin remove SOME_PACKAGE_NAME``, like:

.. code:: bash

    opam remove dune-configurator
    opam pin remove dune-configurator

    opam update diskuv-1.1.0

in the example above.

If that still doesn't work just do:

.. code:: bash

    opam repository remove diskuv-1.1.0 --all

    # On Windows do: ./makeit init-dev
    make init-dev

    opam repository priority diskuv-1.1.0 1 --all
    opam update diskuv-1.1.0

which will rebuild your repository.

Then you can do ``make prepare-dev`` to rebuild your switch.
