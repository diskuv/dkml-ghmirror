#!/bin/sh
#
# On entry the following non-exported environment variables will be available:
# * DKML_TARGET_ABI
# * DKMLDIR
#
# This example uses DKML's autodetect_compiler function() to:
# a) find the compiler selected/validated in the Diskuv OCaml installation (Windows) or on first-use (Unix)
# b) find the specific architecture that has been given to us in DKML_TARGET_PLATFORM

# shellcheck disable=SC1091
. "$DKMLDIR"/etc/contexts/linux-build/crossplatform-functions.sh

# Detect the compiler based on DKML_TARGET_ABI environment value (or guess if not set); set BUILDHOST_ARCH
tmpl="$(mktemp)"
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_PLATFORM="$DKML_TARGET_ABI" autodetect_compiler "$tmpl"

# Output:
#   PATH=
#   AS=
#   ...
$tmpl sh -c set | grep -E "^(PATH|AS|ASPP|CC|PARTIALLD|INCLUDE|LIB|COMPILER_PATH|CPATH|LIBRARY_PATH)="
rm -f "$tmpl"