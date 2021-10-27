# Reproducible: Compile Opam

Caution:
* The MSVC compiler search performed by https://github.com/metastack/msvs-tools/blob/master/msvs-detect is not yet fully reproducible since it
  down not allow pinning the MSVC compiler minor version (ex. 14.26 vs 14.29 can cause a compilation failure) and the Windows SDK toolkit (ex. 10.0.18362.0
  is only SDK known to work).

Prerequisites:
* On Windows you will need:
  * MSYS2
  * Microsoft Visual Studio 2015 Update 3 or later
  * Git

Then run the following in Bash (for Windows use `msys2_shell.cmd` in your MSYS installation folder):

```bash
if [ ! -e @@BOOTSTRAPDIR_UNIX@@README.md ]; then
    echo "You are not in a reproducible target directory" >&2
    exit 1
fi

# Install required system packages
@@BOOTSTRAPDIR_UNIX@@installtime/unix/private/reproducible-compile-ocaml-0-system.sh

# Install the source code
# (Typically you can skip this step. It is only necessary if you changed any of these scripts or don't have a complete reproducible directory)
@@BOOTSTRAPDIR_UNIX@@installtime/unix/private/reproducible-compile-ocaml-1-setup-noargs.sh

# Build and install OCaml
@@BOOTSTRAPDIR_UNIX@@installtime/unix/private/reproducible-compile-ocaml-2-build-noargs.sh
```
