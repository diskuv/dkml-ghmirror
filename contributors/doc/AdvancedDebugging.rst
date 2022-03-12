Debugging
=========

Follow these instructions if you want debug symbols generated for both
the assembly language generated during normal ocamlc/ocamlopt compilation,
and/or C code compiled by Dune.

In the root folder of your OCaml project make a file ``ml64.cmd`` ... you will
need to locate ``ml64.exe`` in your Visual Studio folder:

.. code-block:: winbatch

    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.26.28801\bin\HostX64\x64\ml64.exe" /Zi %*

Make file ``add-debug.sh`` in the same directory:

.. code-block:: bash

    #!/bin/sh

    # Add ml64.cmd to PATH
    HERE=$(dirname "$0")
    HERE=$(cd "$HERE" && pwd)
    export PATH="$HERE:$PATH"

    exec "$@"

If you are in a Dune project you can make the file ``dune-workspace`` in the
same directory:

.. code-block:: scheme

    (lang dune 2.9)

    (env
     (_
      ; C code needs to create debug information.
      ; /Od disable optimizations.
      ; /Z7 embeds debug info inside object files.
      ; Alternative was /Zi, which is cl.exe option to create .PDB debug info;
      ; but would need /FS which lets multiple object files use the same .PDB file
      ; (default is "vc140.pdb" in the same directory as the object file)
      (c_flags (:standard /Z7 /Od))
      (flags
       ; -link will tell flexlink.exe to send the next option to MSVC link.exe
       ; /DEBUG:FULL is link.exe option to create .PDB debug information
       (:standard -ccopt -link -ccopt /DEBUG:FULL))))

Finally build your executables with the ``add-debug.sh`` script ... for example
in a Dune project you would do:

.. code-block:: powershell

    with-dkml ./add-debug.sh dune build --verbose
