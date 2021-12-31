#!/bin/bash
# ----------------------------
# install-ocaml.sh DKMLDIR GIT_TAG_OR_COMMIT DKMLHOSTABI INSTALLDIR

set -euf

DKMLDIR=$1
shift
if [ ! -e "$DKMLDIR/.dkmlroot" ]; then echo "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2; fi

GIT_TAG_OR_COMMIT=$1
shift

DKMLHOSTABI=$1
shift

INSTALLDIR=$1
shift

# Need feature flag and usermode and statedir until all legacy code is removed in _common_tool.sh
# shellcheck disable=SC2034
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON
# shellcheck disable=SC2034
USERMODE=ON
# shellcheck disable=SC2034
STATEDIR=

# shellcheck disable=SC1091
. "$DKMLDIR"/runtime/unix/_common_tool.sh

# Keep the _common_tool provided temporary directory, even when we switch into the reproducible directory
# so the reproducible directory does not leak anything
export TMPPARENTDIR_BUILDHOST

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# Install the source code
log_trace "$DKMLDIR"/installtime/unix/private/reproducible-compile-ocaml-1-setup.sh \
    -d "$DKMLDIR" \
    -t "$INSTALLDIR" \
    -v "$GIT_TAG_OR_COMMIT" \
    -e "$DKMLHOSTABI" \
    -k installtime/unix/private/reproducible-compile-ocaml-example_1.sh

# Use reproducible directory created by setup
cd "$INSTALLDIR"

# Build and install OCaml (but no cross-compilers)
log_trace "$SHARE_REPRODUCIBLE_BUILD_RELPATH"/100-compile-ocaml/installtime/unix/private/reproducible-compile-ocaml-2-build_host-noargs.sh
