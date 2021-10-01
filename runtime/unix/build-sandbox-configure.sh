#!/bin/sh
# -------------------------------------------------------
# build-sandbox-configure.sh PLATFORM BUILDTYPE OPAMS
#
# Purpose: Download and install dependencies needed by the source code.
#
# PLATFORM=dev|linux_arm32v6|linux_arm32v7|windows_x86|...
#
#   The PLATFORM can be `dev` which means the dev platform using the native CPU architecture
#   and system binaries for Opam from your development machine.
#   Otherwise it is one of the "PLATFORMS" canonically defined in TOPDIR/Makefile.
#
# BUILDTYPE=Debug|Release|...
#
#   One of the "BUILDTYPES" canonically defined in TOPDIR/Makefile.
#
# OPAMS=xxx.opam,yyy.opam,...
#
#   Comma separated list of .opam files whose dependencies should be installed.
#
# The build is placed in build/$PLATFORM.
#
# -------------------------------------------------------
set -euf

PLATFORM=$1
shift
# shellcheck disable=SC2034
BUILDTYPE=$1
shift
OPAMS=$1
shift

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR"/../.. && pwd)

# shellcheck disable=SC1091
. "$DKMLDIR"/runtime/unix/_common_build.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

install -d "$BUILDDIR"

# Set NUMCPUS if unset from autodetection of CPUs
autodetect_cpus

# Set DKML_POSIX_SHELL
autodetect_posix_shell

# Set OPAMROOTDIR_BUILDHOST
set_opamrootdir

# -----------------------
# BEGIN opam switch create

"$DKMLDIR"/installtime/unix/create-opam-switch.sh -y -b "$BUILDTYPE" -p "$PLATFORM"

# END opam switch create
# -----------------------

# -----------------------
# BEGIN install development dependencies

# dev dependencies get installed _before_ code dependencies so IDE support
# is available even if not all code dependencies are available after a build
# failure
if is_dev_platform; then
    # Query Opam for its packages. We could just `install` which is idempotent but that would
    # force the multi-second autodetection of compilation tools.
    "$DKMLDIR"/runtime/unix/platform-opam-exec -b "$BUILDTYPE" -p "$PLATFORM" list --short > "$WORK"/packages
    if ! grep -q '\bocamlformat\b' "$WORK"/packages || \
       ! grep -q '\bocamlformat-rpc\b' "$WORK"/packages || \
       ! grep -q '\bocaml-lsp-server\b' "$WORK"/packages || \
       ! grep -q '\butop\b' "$WORK"/packages; \
    then
        # We are missing required packages. Let's install them.
        # The explicit veresion of ocamlformat is required because .ocamlformat file lists it.
        {
            echo "'$DKMLDIR'/runtime/unix/platform-opam-exec -b '$BUILDTYPE' -p '$PLATFORM' install --jobs=$NUMCPUS --yes \\"
            if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "  --debug-level 2 \\"; fi
            echo "  ocamlformat ocamlformat-rpc ocaml-lsp-server utop"
        } > "$WORK"/configure.sh
        print_opam_logs_on_error "$DKML_POSIX_SHELL" "$WORK"/configure.sh
    fi
fi

# END install development dependencies
# -----------------------

# -----------------------
# BEGIN install code (.opam) dependencies

{
    echo "'$DKMLDIR'/runtime/unix/platform-opam-exec -b '$BUILDTYPE' -p '$PLATFORM' install --jobs=$NUMCPUS --yes \\"
    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "  --debug-level 2 \\"; fi
    echo "  --deps-only --with-test \\"
    printf "  "
    echo "$OPAMS" | sed 's/,/ /g'
} > "$WORK"/configure.sh
print_opam_logs_on_error "$DKML_POSIX_SHELL" "$WORK"/configure.sh

# END install code (.opam) dependencies
# -----------------------
