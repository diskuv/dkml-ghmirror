#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# --- Add all packages needed by PackageUpgrade

# Add the API packages of dkml-install-api (needed by all dkml-component-*)
# but in particular [dune build '@installer/bin/gen-dkml' --auto-promote]
# in [dkml-installer-ocaml] bump-packages.cmake requires
# [package-ml-of-installer-generator] and [common-ml-of-installer-generator]
# executables from [dkml-install]
idempotent_opam_local_install dkml-install '@dkml-install-api_SOURCE_DIR@' ./dkml-install.opam