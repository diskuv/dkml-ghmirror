#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# Add or upgrade installer
#
# Add dkml-component-staging-ocamlrun (needed by dkml-component-offline-desktop-full)
# Add or upgrade the components in dkml-component-desktop
#   For now we focus only on the Full flavor. We could have options to do the
#   CI flavor, but we don't need an setup.exe installer for that (yet).
idempotent_opam_local_install dkml-installer-ocaml_TRANSITIVE \
    '@dkml-compiler_SHORTREF@,@dkml-component-ocamlrun_SHORTREF@,@dkml-component-desktop_SHORTREF@,@dkml-component-opam_SHORTREF@,@dkml-component-unixutils_SHORTREF@,@dkml-component-ocamlcompiler_SHORTREF@,@dkml-install-api_SHORTREF@,@dkml-installer-ocaml_SHORTREF@,@dkml-installer-ocaml-byte_SHORTREF@' \
    '@PROJECT_SOURCE_DIR@' \
    '@dkml-compiler_REL_SOURCE_DIR@/dkml-compiler-src.opam' \
    '@dkml-component-ocamlrun_REL_SOURCE_DIR@/dkml-component-staging-ocamlrun.opam' \
    '@dkml-component-desktop_REL_SOURCE_DIR@/dkml-component-staging-withdkml.opam' \
    '@dkml-component-desktop_REL_SOURCE_DIR@/dkml-component-staging-dkmlconfdir.opam' \
    '@dkml-component-desktop_REL_SOURCE_DIR@/dkml-component-common-desktop.opam' \
    '@dkml-component-desktop_REL_SOURCE_DIR@/dkml-component-staging-desktop-full.opam' \
    '@dkml-component-desktop_REL_SOURCE_DIR@/dkml-component-offline-desktop-full.opam' \
    '@dkml-component-opam_REL_SOURCE_DIR@/dkml-component-common-opam.opam' \
    '@dkml-component-opam_REL_SOURCE_DIR@/dkml-component-staging-opam32.opam' \
    '@dkml-component-opam_REL_SOURCE_DIR@/dkml-component-staging-opam64.opam' \
    '@dkml-component-opam_REL_SOURCE_DIR@/dkml-component-offline-opamshim.opam' \
    '@dkml-component-unixutils_REL_SOURCE_DIR@/dkml-component-common-unixutils.opam' \
    '@dkml-component-unixutils_REL_SOURCE_DIR@/dkml-component-staging-unixutils.opam' \
    '@dkml-component-unixutils_REL_SOURCE_DIR@/dkml-component-offline-unixutils.opam' \
    '@dkml-component-ocamlcompiler_REL_SOURCE_DIR@/dkml-component-ocamlcompiler-common.opam' \
    '@dkml-component-ocamlcompiler_REL_SOURCE_DIR@/dkml-component-ocamlcompiler-network.opam' \
    '@dkml-component-ocamlcompiler_REL_SOURCE_DIR@/dkml-component-ocamlcompiler-offline.opam' \
    '@dkml-install-api_REL_SOURCE_DIR@/dkml-package-console.opam' \
    '@dkml-installer-ocaml_REL_SOURCE_DIR@/dkml-installer-ocaml-common.opam' \
    '@dkml-installer-ocaml_REL_SOURCE_DIR@/dkml-installer-ocaml-network.opam' \
    '@dkml-installer-ocaml-byte_REL_SOURCE_DIR@/dkml-installer-ocaml-offline.opam'
