#!/bin/sh
#
# On entry the following environment variables will be available:
# * DKML_TARGET_PLATFORM
# * DKMLDIR
#
# This example uses DKML's autodetect_compiler function() to:
# a) find the compiler selected/validated in the Diskuv OCaml installation (Windows) or on first-use (Unix)
# b) find the specific architecture that has been given to us in DKML_TARGET_PLATFORM

# shellcheck disable=SC1091
. "$DKMLDIR"/etc/contexts/linux-build/crossplatform-functions.sh

# Detect the compiler based on DKML_TARGET_PLATFORM environment value (or guess if not set); set BUILDHOST_ARCH
tmpl="$(mktemp)"
trap 'rm -f "$tmpl"' EXIT
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON autodetect_compiler "$tmpl"

# Output:
#   PATH=
#   ASM=
#   ...
$tmpl sh -c set | grep -E "^(PATH|ASM|CC|INCLUDE|LIB|COMPILER_PATH|CPATH|LIBRARY_PATH)="