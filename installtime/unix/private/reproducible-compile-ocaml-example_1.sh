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

# Detect the compiler based on DKML_TARGET_ABI environment value (or guess if not set); set BUILDHOST_ARCH
tmpl="$(mktemp)"
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_PLATFORM="$DKML_TARGET_ABI" autodetect_compiler "$tmpl"

# Microsoft cl.exe and link.exe use forward slash (/) options; do not ever let MSYS2 interpret
# the forward slash and try to convert it to a Windows path.
disambiguate_filesystem_paths

# Troubleshooting
if [ "${DKML_BUILD_TRACE:-}" = ON ]; then
  autodetect_system_binaries # Set DKMLSYS_*
  printf "@+ autodetect_compiler launcher for DKML_TARGET_ABI=%s\n" "$DKML_TARGET_ABI" >&2
  "$DKMLSYS_SED" 's/^/@+| /' "$tmpl" | "$DKMLSYS_AWK" '{print}' >&2
fi

# Output:
#   PATH=
#   AS=
#   ...
$tmpl sh -c set | grep -E "^(PATH|AS|ASFLAGS|CC|CFLAGS|LDFLAGS|DKML_COMPILE_CM_CMAKE_LINKER)=" > "$tmpl".vars
. "$tmpl".vars
rm -f "$tmpl""$tmpl".vars

# ---------------------------------------
# github.com/ocaml/ocaml/configure output
# ---------------------------------------

export PATH CC CFLAGS LDFLAGS

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
