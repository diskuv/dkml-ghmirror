#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# Add dkml-component-staging-ocamlrun (needed by dkml-component-offline-desktop-full)
idempotent_opam_local_install dkml-compiler-src '' '@dkml-compiler_SOURCE_DIR@' ./dkml-compiler-src.opam
idempotent_opam_local_install dkml-component-staging-ocamlrun '' '@dkml-component-ocamlrun_SOURCE_DIR@' ./dkml-component-staging-ocamlrun.opam

# Add or upgrade the components in dkml-component-desktop in topological order
idempotent_opam_local_install dkml-component-staging-withdkml '' '@dkml-component-desktop_SOURCE_DIR@' ./dkml-component-staging-withdkml.opam
idempotent_opam_local_install dkml-component-staging-dkmlconfdir '' '@dkml-component-desktop_SOURCE_DIR@' ./dkml-component-staging-dkmlconfdir.opam
#   For now we focus only on the Full flavor. We could have options to do the
#   CI flavor, but we don't need an setup.exe installer for that (yet).
idempotent_opam_local_install dkml-component-offline-desktop-full-TRANSITIVE '' '@dkml-component-desktop_SOURCE_DIR@' \
    ./dkml-component-common-desktop.opam \
    ./dkml-component-staging-desktop-full.opam \
    ./dkml-component-offline-desktop-full.opam
idempotent_opam_local_install dkml-component-offline-opamshim-TRANSITIVE '' '@dkml-component-opam_SOURCE_DIR@' \
    ./dkml-component-common-opam.opam \
    ./dkml-component-staging-opam32.opam \
    ./dkml-component-staging-opam64.opam \
    ./dkml-component-offline-opamshim.opam
idempotent_opam_local_install dkml-component-offline-unixutils-TRANSITIVE '' '@dkml-component-unixutils_SOURCE_DIR@' \
    ./dkml-component-common-unixutils.opam \
    ./dkml-component-staging-unixutils.opam \
    ./dkml-component-offline-unixutils.opam
idempotent_opam_local_install dkml-component-ocamlcompiler-network-TRANSITIVE '' '@dkml-component-ocamlcompiler_SOURCE_DIR@' \
    ./dkml-component-ocamlcompiler-common.opam \
    ./dkml-component-ocamlcompiler-network.opam

# Add or upgrade installer
idempotent_opam_local_install dkml-package-console '' '@dkml-install-api_SOURCE_DIR@' ./dkml-package-console.opam
idempotent_opam_local_install dkml-installer-ocaml-network '' '@dkml-installer-ocaml_SOURCE_DIR@' ./dkml-installer-ocaml-network.opam
