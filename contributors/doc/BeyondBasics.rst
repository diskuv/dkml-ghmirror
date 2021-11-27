.. _BeyondBasics:

Beyond Basics
=============

Learn OCaml - A first project
-----------------------------

.. note::
    This section is almost verbatim from `A first project - Learn OCaml <https://ocaml.org/learn/tutorials/up_and_running.html#A-first-project>`_.
    Since you already installed Diskuv OCaml, almost everything else on that page is already
    done for you!

Let's begin the simplest project with Dune and OCaml. We create a new directory and ask ``dune`` to initialise a new project:

1. Open the Visual Studio Command Prompt (press the Windows key ⊞, type "x64 Native Tools" and then Open ``x64 Native Tools Command Prompt for VS 2019``).
2. Type:

   .. code-block:: doscon

      C:\DiskuvOCaml\BuildTools>cd %USERPROFILE%\DiskuvOCamlProjects

      C:\Users\you\DiskuvOCamlProjects>mkdir helloworld

      C:\Users\you\DiskuvOCamlProjects>cd helloworld/

      C:\Users\you\DiskuvOCamlProjects\helloworld>dune init exe helloworld
      Success: initialized executable component named helloworld

Building our program is as simple as typing ``dune build``:

   .. code-block:: doscon

      C:\Users\you\DiskuvOCamlProjects\helloworld>dune build
      Info: Creating file dune-project with this contents:
      | (lang dune 2.9)

When we change our program, we type ``dune build`` again to make a new executable.
We can run the executable with ``dune exec`` (it's called ``helloworld.exe`` even when we're not using Windows):

   .. code-block:: doscon

      C:\Users\you\DiskuvOCamlProjects\helloworld>dune exec ./helloworld.exe
      Hello, World!

Let's look at the contents of our new directory.
Dune has added the ``helloworld.ml`` file, which is our OCaml program.
It has also added our ``dune`` file, which tells dune how to build the program,
and a ``_build`` subdirectory, which is dune's working space.

   .. code-block:: doscon

      C:\Users\you\DiskuvOCamlProjects\helloworld>dir
      Volume in drive C has no label.
      Volume Serial Number is A00E-4711

      Directory of C:\Users\you\DiskuvOCamlProjects\helloworld

      10/14/2021  02:47 PM    <DIR>          .
      10/14/2021  02:46 PM    <DIR>          ..
      10/14/2021  02:46 PM                32 dune
      10/14/2021  02:47 PM                17 dune-project
      10/14/2021  02:46 PM                40 helloworld.ml
      10/14/2021  02:47 PM    <DIR>          _build
                  3 File(s)             89 bytes
                  3 Dir(s)  116,767,272,960 bytes free

The ``helloworld.exe`` executable is stored inside the ``_build/default`` subdirectory,
so it's easier to run with ``dune exec``. To ship the executable, we can just copy it
from inside ``_build/default`` to somewhere else.

Here is the contents of the automatically-generated ``dune`` file.
When we want to add components to your project, such as third-party libraries, we edit this file.

.. code-block:: scheme

    (executable
      (name helloworld))

Installing packages
~~~~~~~~~~~~~~~~~~~

Opam is the OCaml package manager. It gives you access to thousands of third-party packages that you can use in your
own projects.

Each project is a local directory with source code and its own set of OCaml packages.
Opam will manage the OCaml packages in a local subdirectory named ``_opam``. The technical
term for ``_opam`` is a local **switch**. In this section we will create a project
called ``playground``.

Let's start by finding which switches are available:

1. Open the Visual Studio Command Prompt (press the Windows key ⊞, type "x64 Native Tools" and then Open ``x64 Native Tools Command Prompt for VS 2019``).
2. Type:

   .. code-block:: doscon

      C:\DiskuvOCaml\BuildTools>opam switch
      #  switch                                                      compiler
                description
         C:\Users\you\AppData\Local\Programs\DiskuvOCaml\0\host-tools
                ocaml-system.4.12.1
                C:\Users\you\AppData\Local\Programs\DiskuvOCaml\0\host-tools
      →  diskuv-boot-DO-NOT-DELETE
                diskuv-boot-DO-NOT-DELETE

      [WARNING] The environment is not in sync with the current switch.
                You should run: for /f "tokens=*" %i in ('opam env') do @%i

You just found that you have two switches. The first switch is the directory "host-tools".
The other switch says *DO NOT DELETE*. We will avoid those two switches.

Let's now create our own ``playground`` switch. All we need to do is create a directory
and run ``opam dkml init`` inside our new (or existing) directory:

   .. code-block:: doscon

      C:\DiskuvOCaml\BuildTools>cd %USERPROFILE%\DiskuvOCamlProjects

      C:\Users\you\DiskuvOCamlProjects>mkdir playground
      C:\Users\you\DiskuvOCamlProjects>cd playground
      C:\Users\you\DiskuvOCamlProjects\playground>opam dkml init

      C:\Users\you\DiskuvOCamlProjects\playground>opam switch
      #  switch                                                                           compiler
               description
      ...
      →  C:\Users\you\DiskuvOCamlProjects\playground                                    ocaml-system.4.12.1
               C:\Users\you\DiskuvOCamlProjects\playground
         diskuv-boot-DO-NOT-DELETE
               diskuv-boot-DO-NOT-DELETE

      [NOTE] Current switch has been selected based on the current directory.
            The current global system switch is diskuv-boot-DO-NOT-DELETE.
      [WARNING] The environment is not in sync with the current switch.
               You should run: for /f "tokens=*" %i in ('opam env') do @%i

Notice how the switch was created with ``opam dkml init``, and also notice
how ``opam switch`` tells you in its ``[NOTE]`` that it knows which switch
should be used based **on the current directory**.

If we want our playground to be remembered regardless what the directory
currently is, we can follow the ``[WARNING]`` and add the option ``--set-switch``.

Let's do that now so we learn how to do it:

   .. code-block:: doscon

      C:\Users\you\DiskuvOCamlProjects\playground>for /f "tokens=*" %i in ('opam env --set-switch') do @%i

      C:\Users\you\DiskuvOCamlProjects\playground>opam switch
      #  switch                                                                           compiler
               description
      ...
      →  C:\Users\you\DiskuvOCamlProjects\playground                                    ocaml-system.4.12.1
               C:\Users\you\DiskuvOCamlProjects\playground
         diskuv-boot-DO-NOT-DELETE
               diskuv-boot-DO-NOT-DELETE

      [NOTE] Current switch is set locally through the OPAMSWITCH variable.
            The current global system switch is diskuv-boot-DO-NOT-DELETE.

**Great!** You are now ready to install some packages for the playground project.
Let's see what packages are installed with ``opam list`` and available
with ``opam list -a``:

   .. code-block:: doscon

      C:\Users\beckf\DiskuvOCamlProjects\playground>opam list
      # Packages matching: installed
      # Name        # Installed # Synopsis
      base-bigarray base        pinned to version base
      base-threads  base        pinned to version base
      base-unix     base        pinned to version base
      ocaml         4.12.1      pinned to version 4.12.1
      ocaml-config  2           pinned to version 2
      ocaml-system  4.12.1      The OCaml compiler (system version, from outside of opam)

      C:\Users\beckf\DiskuvOCamlProjects\playground>opam list -a
      # Packages matching: available
      # Name                                          # Installed                # Synopsis
      0install                                        --                         pinned to version 2.17
      0install-gtk                                    --                         pinned to version 2.17
      0install-solver                                 --                         pinned to version 2.17
      ANSITerminal                                    --                         pinned to version 0.8.2
      ...
      zstandard                                       --                         pinned to version v0.14.0
      zstd                                            --                         pinned to version 0.2
      zxcvbn                                          --                         pinned to version 2.4+1

There are a lot! You will probably find it easier to use the `OCaml Packages browser <https://v3.ocaml.org/packages>`_
in your web browser.

Since this section is following the Learn OCaml tutorials, let's install the `Graphics library <https://github.com/ocaml/graphics#readme>`_
which gives you the `Graphics module <https://ocaml.github.io/graphics/graphics/Graphics/index.html>`_.
In Opam the package names are always lowercase, so the module ``Graphics`` will be available in the ``graphics`` Opam package:

   .. code-block:: doscon

      C:\Users\you\DiskuvOCamlProjects\playground>with-dkml opam install graphics

Press **Y** when asked if you want to continue, then sit back while it compiles and
installs the ``graphics`` package.

Learn OCaml - A First Hour with OCaml
-------------------------------------

You are almost ready to follow
the tutorial `A First Hour with OCaml - Learn OCaml <https://ocaml.org/learn/tutorials/a_first_hour_with_ocaml.html>`_.

Before you begin that tutorial, you will need to know a few things:

* You don't need to use ``rlwrap``. You already have ``utop`` installed; it is much easier to work with!
* Eventually you will be asked to install the ``graphics`` package and the ``ocamlfind`` package. Both of them
  are already installed, but follow along anyway! When you are asked to do ``opam`` **always**
  use ``with-dkml opam``. So type ``with-dkml opam install graphics`` rather than ``opam install graphics``,
  and the same thing applies to the ``ocamlfind`` package.
* Make sure you are using the system switch. Go back to the previous section if you don't remember how to
  select the system switch.

Now go follow `A First Hour with OCaml - Learn OCaml <https://ocaml.org/learn/tutorials/a_first_hour_with_ocaml.html>`_!

Integrated Development Environment (IDE)
----------------------------------------

Installing Visual Studio Code
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. sidebar:: Visual Studio Code is optional.

  Using Visual Studio Code is optional but strongly recommended! The only other development environment
  that supports OCaml well is Emacs.

Installing an IDE like Visual Studio Code will let you navigate the code in your SDK Projects, see
the source code with syntax highlighting (color), get auto-complete to help you write your own code,
and inspect the types within your code.

If you haven't already, download and install `Visual Studio Code <https://code.visualstudio.com/Download>`_ from
its website. For Windows 64-bit you will want to choose the "User Installer" "64-bit" button underneath
the Windows button, unless you have Administrator access to your PC (then "System Installer" is usually the right choice):

.. image:: SdkProject-VisualStudio-Windows.png
  :width: 300

Windows `Development Environment Virtual Machine <https://developer.microsoft.com/en-us/windows/downloads/virtual-machines/>`_
users (you will know if you are one of them) already have Visual Studio Code bundled
in the virtual machine.

Installing the OCaml Plugin
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once you have Visual Studio Code, you will want the OCaml plugin.
Open a *new* PowerShell session and type:

.. code-block:: ps1con
    :emphasize-lines: 5,8

    PS1> iwr `
            "https://github.com/diskuv/vscode-ocaml-platform/releases/download/v1.8.5-diskuvocaml/ocaml-platform.vsix" `
            -OutFile "$env:TEMP\ocaml-platform.vsix"
    PS1> code --install-extension "$env:TEMP\ocaml-platform.vsix"
    >> Installing extensions...
    >> (node:16672) [DEP0005] DeprecationWarning: Buffer() is deprecated due to security and usability issues. Please use the Buffer.alloc(), Buffer.allocUnsafe(), or Buffer.from() methods instead.
    >> (Use `Code --trace-deprecation ...` to show where the warning was created)
    >> Extension 'ocaml-platform.vsix' was successfully installed.
    >> (node:16672) UnhandledPromiseRejectionWarning: Canceled: Canceled
    >>     at D (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:5:1157)
    >>     at O.cancel (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:9:62880)
    >>     at O.dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:9:63012)
    >>     at N.dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:9:63274)
    >>     at d (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:3655)
    >>     at N.clear (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:4133)
    >>     at N.dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:4112)
    >>     at dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:4672)
    >>     at dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cliProcessMain.js:11:7330)
    >>     at d (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:3655)
    >>     at C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:3843
    >>     at C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:3942
    >>     at Object.dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:762)
    >>     at d (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:3788)
    >>     at C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cliProcessMain.js:14:41520
    >>     at Map.forEach (<anonymous>)
    >>     at Ne.dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cliProcessMain.js:14:41496)
    >>     at d (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:3655)
    >>     at N.clear (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:4133)
    >>     at N.dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:4112)
    >>     at S.dispose (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:6:4672)
    >>     at Object.M [as main] (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cliProcessMain.js:17:38649)
    >>     at async N (C:\Users\you\AppData\Local\Programs\Microsoft VS Code\resources\app\out\vs\code\node\cli.js:12:13842)
    >> (node:16672) UnhandledPromiseRejectionWarning: Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the node process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). (rejection id: 1)
    >> (node:16672) [DEP0018] DeprecationWarning: Unhandled promise rejections are deprecated. In the future, promise rejections that are not handled will terminate the Node.js process with a non-zero exit code.

You may get a lot of warnings/noise, but the highlighted lines will show you that the installation was successful.

Now you need to quit **ALL** Visual Studio Code windows (if any), and then restart Visual Studio Code.

Next Steps?
-----------

Once you feel you are an intermediate OCaml user (likely you've spent a few weeks getting comfortable with OCaml), you may want
to create your own OCaml-based application. :ref:`SDKProjects`, which let you edit code for your application in an IDE,
import open-source code packages and build your application, are the topic of the next section.

SDK Projects are **intermediate level difficulty**, so make sure you are comfortable with OCaml by going through:

* `Learn OCaml tutorials <https://ocaml.org/learn/tutorials/>`_
* `Part 1 of Real World OCaml <https://dev.realworldocaml.org/toc.html>`_
