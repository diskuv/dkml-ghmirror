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

# Set OPAMROOTDIR_BUILDHOST. Export for use by DKML_TROUBLESHOOTING_HOOK
set_opamrootdir
export OPAMROOTDIR_BUILDHOST

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
       ! grep -q '\bocp-indent\b' "$WORK"/packages || \
       ! grep -q '\butop\b' "$WORK"/packages; \
    then
        # We are missing required packages. Let's install them.
        {
            echo "'$DKMLDIR'/runtime/unix/platform-opam-exec -b '$BUILDTYPE' -p '$PLATFORM' install --jobs=$NUMCPUS --yes \\"
            if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "  --debug-level 2 \\"; fi
            echo "  ocamlformat ocamlformat-rpc ocaml-lsp-server ocp-indent utop"
        } > "$WORK"/configure.sh
        print_opam_logs_on_error "$DKML_POSIX_SHELL" "$WORK"/configure.sh
    fi
fi

# END install development dependencies
# -----------------------

# -----------------------
# BEGIN install code (.opam) dependencies

# Set and export OPAMSWITCHNAME_BUILDHOST, for use by DKML_TROUBLESHOOTING_HOOK
set_opamrootandswitchdir
export OPAMSWITCHNAME_BUILDHOST

{
    # [configure.sh JOBS]
    echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec -b '$BUILDTYPE' -p '$PLATFORM' install --jobs=\$1 --yes \\"
    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "  --debug-level 2 \\"; fi
    echo "  --deps-only --with-test \\"
    # shellcheck disable=SC2016
    printf ' '
    echo "$OPAMS" | sed 's/,/ /g'
} > "$WORK"/configure.sh
{
    if [ "${CI:-}" = true ]; then
        # When we are doing CI:
        # * we'll run it twice ... allowing for failures ... and the last time we will run it
        # without any failures allowed
        # * we disable DKML_BUILD_PRINT_LOGS_ON_ERROR=ON during retries except the last one
        # * any retries are done with parallelism=1 to remove race problems

        # shellcheck disable=SC2016
        echo 'old_bploe="${DKML_BUILD_PRINT_LOGS_ON_ERROR:-}"'
        echo "export DKML_BUILD_PRINT_LOGS_ON_ERROR=OFF"
        echo "if $DKML_POSIX_SHELL '$WORK/configure.sh' $NUMCPUS; then exit 0; fi"
        if [ -n "${DKML_TROUBLESHOOTING_HOOK:-}" ]; then
            echo "echo 'Installing code dependencies failed. Using troubleshooting hook: $DKML_TROUBLESHOOTING_HOOK.' >&2"
            # run hook but ignore errors
            echo "$DKML_POSIX_SHELL -x $DKML_TROUBLESHOOTING_HOOK || true"
        fi
        echo 'echo Installing code dependencies failed. Disabling any parallelism. Retry 1 of 2. >&2'
        echo "if $DKML_POSIX_SHELL -x '$WORK/configure.sh' 1; then exit 0; fi"
        echo 'echo Installing code dependencies failed. Disabling any parallelism. Retry 2 of 2. >&2'
        # shellcheck disable=SC2016
        echo 'DKML_BUILD_PRINT_LOGS_ON_ERROR="$old_bploe"'
        echo "exec $DKML_POSIX_SHELL '$WORK/configure.sh' 1"
    else
        echo "exec $DKML_POSIX_SHELL '$WORK/configure.sh' $NUMCPUS"
    fi
} > "$WORK"/configure-with-retry.sh

print_opam_logs_on_error "$DKML_POSIX_SHELL" "$WORK"/configure-with-retry.sh

# END install code (.opam) dependencies
# -----------------------
