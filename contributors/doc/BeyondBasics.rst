.. _BeyondBasics:

Beyond Basics
=============

.. important::

  These are early days for Diskuv OCaml. We frequently update the software for bug fixes.
  Stay informed about new features, bug fixes and security updates on Twitter:

  .. image:: https://img.shields.io/twitter/url/https/twitter.com/diskuv.svg?style=social&label=Follow%20%40diskuv
    :target: https://twitter.com/diskuv

  If you are a student, **talk with your instructor** before applying a major update. They will
  likely want you to stay on your existing version until the course is complete.

Learn OCaml - A first project
-----------------------------

.. note::
    This section is almost verbatim from `A first project - Learn OCaml`_.
    Since you already installed Diskuv OCaml, almost everything else on that page is already
    done for you!

.. _A first project - Learn OCaml: https://ocaml.org/learn/tutorials/up_and_running.html#A-first-project

Let's begin the simplest project with Dune and OCaml. We create a new directory and ask ``dune`` to initialise a new project:

1. Open the Command Prompt (press the Windows key ⊞ and ``R``, and then type "cmd" and ENTER).
2. Type:

   .. code-block:: doscon

      C:\Users\you>if not exist "%USERPROFILE%\DiskuvOCamlProjects" mkdir %USERPROFILE%\DiskuvOCamlProjects
      C:\Users\you>cd %USERPROFILE%\DiskuvOCamlProjects

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
and a ``_build`` subdirectory, which is Dune's working space.

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
When we want to add components to your project, such as third-party libraries,
we can edit this file:

.. code-block:: scheme

    (executable
      (name helloworld))

.. important::

   **Editing files**

   Now is a good time to talk about editing a file. *Editing* is how you change
   the contents of a file. You probably already know how to use Microsoft Word
   to edit Word documents: just start up Microsoft Word and then use the
   Word menu to "Open" a Word document. But Microsoft Word only works with
   Word documents that end with ``.doc`` or ``.docx``! On Windows you can use
   the program ``Notepad`` (press the Windows key ⊞, and then type "notepad")
   to edit "text" documents.

   All programming languages, including OCaml, use text documents. These are
   also called text files and source files. (We'll use the term "source file"
   from now on.) Source files are not Word documents. In fact,
   **you will mess up your source file if you use Microsoft Word** to edit it.
   You have to use a text editor. Other than that difference, editing should
   still be familiar to you:

   * Open your editor (example: open Notepad)
   * Use the editor menu to "Open" a source file, or make a "New" source file
   * Type in your code
   * Save the source file with an appropriate name and ending.

   Click on the animated image below (use your mouse!) to see how to open a file:

   .. image:: BeyondBasics-win32-opening.gif
      :width: 700
      :alt: Opening a source file with Notepad on Windows

   Click on the picture below to see how you change the **Save As type** box while
   you are saving a file:

   .. image:: BeyondBasics-win32-editing.png
      :width: 700
      :alt: Editing a source file with Notepad on Windows

   We should always save with **All file types (*.*)**, not **"Text documents (*.txt)"**,
   because Notepad and other simple editors will add ".txt" to the ending of the
   filename (also known as the *file extension*) without telling you!

It bears repeating:

**The name, extension and location of the source file is critical!** As you go
through this documentation make sure you Save the text file *exactly where* it
tells you with the *exact name and extension* it tells you!

Continuous building
~~~~~~~~~~~~~~~~~~~

Eventually you may get tired of running ``dune build`` all the time.

Try running the following:

.. code-block:: doscon

   C:\Users\you\DiskuvOCamlProjects>cd %USERPROFILE%\DiskuvOCamlProjects\helloworld
   C:\Users\you\DiskuvOCamlProjects\helloworld>with-dkml sh -c 'while true; do dune build --watch; sleep 1; done'

and then edit your ``helloworld.ml`` to say "This is so fast!" instead of
"Hello, World!".

Then open a new Command Prompt (press the Windows key ⊞ and ``R``, and then type "cmd" and ENTER) to run:

.. code-block:: doscon

   C:\Users\you>cd %USERPROFILE%\DiskuvOCamlProjects\helloworld
   C:\Users\you\DiskuvOCamlProjects\helloworld>_build\default\helloworld.exe
   This is so fast!

Anytime you edit your source code, it will recompile what has changed.

Installing packages
~~~~~~~~~~~~~~~~~~~

Opam is the OCaml package manager. It gives you access to thousands of third-party packages that you can use in your
own projects.

Each project is a local directory with source code and its own set of OCaml packages.
Opam will manage the OCaml packages in a local subdirectory named ``_opam``. The technical
term for ``_opam`` is a local **switch**. In this section we will create a project
called ``my-first-switch``.

Let's start by finding which switches are available:

1. Open the Command Prompt (press the Windows key ⊞ and ``R``, and then type "cmd" and ENTER).
2. Type:

   .. code-block:: doscon

      C:\Users\you>opam switch
      #  switch                                                      compiler
                description
         C:\Users\you\AppData\Local\Programs\DiskuvOCaml\0\dkml
                ocaml-system.4.12.1
                C:\Users\you\AppData\Local\Programs\DiskuvOCaml\0\dkml
      →  playground
                ocaml-system.4.12.1
                playground

      [WARNING] The environment is not in sync with the current switch.
                You should run: for /f "tokens=*" %i in ('opam env') do @%i

You just found that you have at least two (2) switches: the directory ``...\0\dkml``
and the ``playground``. We will avoid the ``dkml`` reserved switch, and for now we'll
ignore the ``playground`` switch.

Let's create our own ``my-first-switch`` switch. All we need to do is create a directory
and run ``dkml init`` inside our new (or existing) directory:

.. note::

   Press **y** (yes) whenever you are prompted!

.. note::

   The very first time you run ``dkml init`` it can take 15 minutes.
   After the first time ``dkml init`` will run much faster.

.. code-block:: doscon

   C:\Users\you>if not exist "%USERPROFILE%\DiskuvOCamlProjects" mkdir %USERPROFILE%\DiskuvOCamlProjects
   C:\Users\you>cd %USERPROFILE%\DiskuvOCamlProjects

   C:\Users\you\DiskuvOCamlProjects>mkdir my-first-switch
   C:\Users\you\DiskuvOCamlProjects>cd my-first-switch
   C:\Users\you\DiskuvOCamlProjects\my-first-switch>dkml init

   C:\Users\you\DiskuvOCamlProjects\my-first-switch>opam switch
   #  switch                                                                           compiler
            description
   ...
   →  C:\Users\you\DiskuvOCamlProjects\my-first-switch                                    ocaml-system.4.12.1
            C:\Users\you\DiskuvOCamlProjects\my-first-switch

   [NOTE] Current switch has been selected based on the current directory.
         The current global system switch is C:\Users\you\AppData\Local\Programs\DiskuvOCaml\0\dkml.
   [WARNING] The environment is not in sync with the current switch.
            You should run: for /f "tokens=*" %i in ('opam env') do @%i

Notice how the switch was created with ``dkml init``, and also notice
how ``opam switch`` tells you in its ``[NOTE]`` that it knows which switch
should be used based **on the current directory**.

If we want our my-first-switch to be remembered regardless what the directory
currently is, we can follow the ``[WARNING]`` and add the option ``--set-switch``.

Let's do that now so we learn how to do it:

   .. code-block:: doscon

      C:\Users\you\DiskuvOCamlProjects\my-first-switch>for /f "tokens=*" %i in ('opam env --set-switch') do @%i

      C:\Users\you\DiskuvOCamlProjects\my-first-switch>opam switch
      #  switch                                                                           compiler
               description
      ...
      →  C:\Users\you\DiskuvOCamlProjects\my-first-switch                                    ocaml-system.4.12.1
               C:\Users\you\DiskuvOCamlProjects\my-first-switch

      [NOTE] Current switch is set locally through the OPAMSWITCH variable.
            The current global system switch is C:\Users\you\AppData\Local\Programs\DiskuvOCaml\0\dkml.

**Great!** You are now ready to install some packages for the my-first-switch project.
Let's see what packages are installed with ``opam list`` and available
with ``opam list -a``:

   .. code-block:: doscon

      C:\Users\you\DiskuvOCamlProjects\my-first-switch>opam list
      # Packages matching: installed
      # Name        # Installed # Synopsis
      base-bigarray base        pinned to version base
      base-threads  base        pinned to version base
      base-unix     base        pinned to version base
      conf-withdkml 1           Virtual package relying on with-dkml
      ocaml         4.12.1      pinned to version 4.12.1
      ocaml-config  3           pinned to version 3
      ocaml-system  4.12.1      The OCaml compiler (system version, from outside of opam)

      C:\Users\you\DiskuvOCamlProjects\my-first-switch>opam list -a
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

   C:\Users\you\DiskuvOCamlProjects\my-first-switch>opam install graphics

.. note::

   Press **y** when asked if you want to continue, then sit back while it compiles and
   installs the ``graphics`` package.

Learn OCaml - A First Hour with OCaml
-------------------------------------

You are almost ready to follow
the tutorial `A First Hour with OCaml - Learn OCaml <https://ocaml.org/learn/tutorials/a_first_hour_with_ocaml.html>`_.

Before you begin that tutorial, you will need to know a few things:

* Make sure you are using the ``my-first-switch`` switch. Go back to the previous section if you don't remember how to
  select the ``my-first-switch`` switch.
* You don't need to use ``rlwrap``. Instead use ``with-dkml utop`` in your my-first-switch switch; it is much
  easier to work with! Do an **extra** ``opam install utop`` when it asks you to install the ``graphics`` package
  and the ``ocamlfind`` packages.

.. warning::

   When you want to use OCaml tools from your project, use ``with-dkml``
   to reliably get those tools to work on Windows. We already do this on your
   behalf for ``opam`` and ``dune``, **but** some tools like
   ``ocamlc``, ``ocamlopt`` and ``utop`` need help to find the Microsoft compiler
   or UNIX binaries or the right Windows paths. So don't guess; just get in the
   habit of using ``with-dkml``!

   So ``with-dkml ocamlopt -o helloworld helloworld.ml`` rather than
   ``ocamlopt -o helloworld helloworld.ml``. And ``with-dkml utop`` rather than
   ``utop``. Et cetera.

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

In the ``File`` > ``Preferences`` > ``Extensions`` view (or press ``Ctrl Shift X``),
type ``ocamllabs.ocaml-platform`` in the search box to find and install:

.. code-block:: markdown

   #### OCaml Platform
   * Official OCaml language extension for VSCode

Now you need to quit **ALL** Visual Studio Code windows (if any), and then restart Visual Studio Code.

After that, in the ``File`` > ``Preferences`` > ``Settings`` view (or press ``Ctrl ,``),
select ``User`` > ``Extensions`` > ``OCaml Platform``.

Then **uncheck** ``OCaml: Use OCaml Env``.

.. important:: Do not forget to uncheck ``OCaml: Use OCaml Env``

   This setting is a legacy option that may disappear in future versions
   of the OCaml Plugin. For now, if you don't uncheck the option,
   you will *not* see your Opam switches in Visual Studio Code.
