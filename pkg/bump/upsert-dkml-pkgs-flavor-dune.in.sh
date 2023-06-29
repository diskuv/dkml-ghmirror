#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# Add or upgrade Dune
#       shellcheck disable=SC2043
'@WITH_COMPILER_SH@' "$OPAM_EXE" install @DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS@ --yes
