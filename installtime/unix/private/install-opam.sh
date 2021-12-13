#!/bin/bash
# ----------------------------
# install-opam.sh DKMLDIR GIT_TAG INSTALLDIR

set -euf

DKMLDIR=$1
shift
if [ ! -e "$DKMLDIR/.dkmlroot" ]; then echo "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2; fi

GIT_TAG=$1
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

# Set BUILDHOST_ARCH
autodetect_buildhost_arch

# Install the source code
log_trace "$DKMLDIR"/installtime/unix/private/reproducible-compile-opam-1-setup.sh \
    -d "$DKMLDIR" \
    -t "$INSTALLDIR" \
    -a "$BUILDHOST_ARCH" \
    -c "$INSTALLDIR" \
    -u https://github.com/diskuv/opam \
    -v "$GIT_TAG"

# Use reproducible directory created by setup
cd "$INSTALLDIR"

# Build and install Opam
log_trace "$SHARE_REPRODUCIBLE_BUILD_RELPATH"/110-compile-opam/installtime/unix/private/reproducible-compile-opam-2-build-noargs.sh

# Remove intermediate files including build files and .git folders
log_trace "$SHARE_REPRODUCIBLE_BUILD_RELPATH"/110-compile-opam/installtime/unix/private/reproducible-compile-opam-9-trim-noargs.sh
