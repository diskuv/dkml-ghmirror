#!/bin/sh
#
# On entry the following non-exported environment variables will be available:
# * DKML_TARGET_ABI
# * DKMLDIR
#
# On exit the variables needed for github.com/ocaml/ocaml/configure will be set and exported.
#
# This example uses DKML's autodetect_compiler() function to:
# a) find the compiler selected/validated in the Diskuv OCaml installation (Windows) or on first-use (Unix)
# b) find the specific architecture that has been given to us in DKML_TARGET_PLATFORM
set -euf

# shellcheck disable=SC1091
. "$DKMLDIR"/etc/contexts/linux-build/crossplatform-functions.sh

# Microsoft cl.exe and link.exe use forward slash (/) options; do not ever let MSYS2 interpret
# the forward slash and try to convert it to a Windows path.
disambiguate_filesystem_paths

# ---------------------------------------
# github.com/ocaml/ocaml/configure output
# ---------------------------------------

export PATH CC CFLAGS LDFLAGS AR

# CFLAGS
# clang and perhaps other compilers need --target=armv7-none-linux-androideabi21 for example
CFLAGS="${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_TARGET:-}${DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET:-} ${CFLAGS:-}"
export CFLAGS

# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure.ac#L1213-L1240
_TMP_AS="${AS:-}"
AS="$_TMP_AS $ASFLAGS"
ASPP="$_TMP_AS $ASFLAGS"
case "$DKML_TARGET_ABI" in
  darwin_*) AS="$AS -Wno-trigraphs"
esac
export AS ASPP

# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure#L3434-L3534
# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure.ac#L1158-L1175
if [ -n "${DKML_COMPILE_CM_CMAKE_LINKER:-}" ]; then
  LD=$DKML_COMPILE_CM_CMAKE_LINKER
  DIRECT_LD=$DKML_COMPILE_CM_CMAKE_LINKER
fi
export LD DIRECT_LD

# STRIP, RANLIB, NM, OBJDUMP
RANLIB="${DKML_COMPILE_CM_CMAKE_RANLIB:-}"
STRIP="${DKML_COMPILE_CM_CMAKE_STRIP:-}"
NM="${DKML_COMPILE_CM_CMAKE_NM:-}"
OBJDUMP="${DKML_COMPILE_CM_CMAKE_OBJDUMP:-}"
export STRIP RANLIB NM OBJDUMP
