#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# --- Add all packages needed by PackageUpgrade

# ------- 1 ------
# Add the API packages of dkml-install-api (needed by all dkml-component-*)
# but in particular [dune build '@installer/bin/gen-dkml' --auto-promote]
# in [dkml-installer-ocaml] bump-packages.cmake requires
# [package-ml-of-installer-generator] and [common-ml-of-installer-generator]
# executables from [dkml-install-installer]
# ------- 2 ------
# Add dkml-workflows
idempotent_opam_local_install api-TRANSITIVE \
    '@dkml-install-api_SHORTREF@,@dkml-workflows_SHORTREF@' \
    '@PROJECT_SOURCE_DIR@' \
    '@dkml-install-api_REL_SOURCE_DIR@/dkml-install.opam' \
    '@dkml-install-api_REL_SOURCE_DIR@/dkml-install-runner.opam' \
    '@dkml-install-api_REL_SOURCE_DIR@/dkml-install-installer.opam' \
    '@dkml-install-api_REL_SOURCE_DIR@/dkml-package-console.opam' \
    '@dkml-workflows_REL_SOURCE_DIR@/dkml-workflows.opam'
