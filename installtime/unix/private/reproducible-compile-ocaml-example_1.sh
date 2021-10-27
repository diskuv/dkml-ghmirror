#!/bin/sh
#
# This example uses DKML's autodetect_compiler function to find the compiler selected/validated
# in the Diskuv OCaml installation (Windows) or on first-use (Unix)

# shellcheck disable=SC1091
. "$DKMLDIR"/etc/contexts/linux-build/crossplatform-functions.sh

# Detect the compiler; set BUILDHOST_ARCH
tmpl="$(mktemp)"
trap 'rm -f "$tmpl"' EXIT
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON autodetect_compiler "$tmpl"

# Output:
#   DKML_TARGET_ABI=
#   PATH=
#   ...
printf "DKML_TARGET_PLATFORM=%s\n" "$BUILDHOST_ARCH"
$tmpl sh -c set | grep -E "^(PATH|ASM|CC|INCLUDE|LIB|COMPILER_PATH|CPATH|LIBRARY_PATH)="