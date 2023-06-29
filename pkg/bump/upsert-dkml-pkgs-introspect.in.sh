#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# Add or upgrade dkml-build-desktop which has tools that parse
# the dkml-runtime-distribution package and use that to inspect the opam switch.
idempotent_opam_local_install dkml-build-desktop '@dkml-component-desktop_SOURCE_DIR@' ./dkml-build-desktop.opam
