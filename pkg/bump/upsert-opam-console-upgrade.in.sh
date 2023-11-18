#!/bin/sh
set -euf

# Run with something like:
#   cmake --build build -t Package-OpamConsoleUpgrade
#   ninja -C build Package-OpamConsoleUpgrade

export TOPDIR='@dkml-runtime-common_SOURCE_DIR@/all/emptytop'
export DKMLDIR='@DKML_ROOT_DIR@'

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

if [ -n "${DKML_UPGRADE_PACKAGES:-}" ]; then
    # shellcheck disable=SC2086
    '@WITH_COMPILER_SH@' "$OPAM_EXE" install $DKML_UPGRADE_PACKAGES
else
    echo "To install specific packages, set the environment variable"
    echo "DKML_UPGRADE_PACKAGES to a space separated list of packages."
    echo "Examples: sha cmdliner.1.2.0"
    echo
    '@WITH_COMPILER_SH@' "$OPAM_EXE" upgrade
fi
