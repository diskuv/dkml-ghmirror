#!/bin/bash
# -------------------------------------------------------
# platform-dune-exec.sh -b BUILDTYPE -p PLATFORM [--] build|clean|help|...
#
# Q: Why delegate to `platform-opam-exec.sh exec -- dune` when Dune does
# not need Opam?
# Ans: Yep. If you setup a
# https://github.com/ocamllabs/opam-monorepo then you can build your
# application using just `dune`. As of 2021-08-11 we are using
# Opam to provide Dune but in the future we will likely provide
# build/_tools/common/dune-bootstrap/ just like .../opam-bootstrap/.
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
# The build is placed in build/$PLATFORM.
#
# -------------------------------------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    platform-dune-exec.sh -h                                                  Display this help message." >&2
    echo "    platform-dune-exec.sh -b BUILDTYPE -p PLATFORM [--] build|clean|help|...  Run the dune command." >&2
}

# no arguments should display usage
if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

# Problem 1:
#
#   Dune (and Opam) do not like:
#     dune --build-dir xyz build
#   Instead it expects:
#     dune build --build-dir xyz
#   We want to inject `--build-dir xyz` right after the subcommand but before
#   any arg seperators like `--`.
#   For example, we can't just add `--build-dir xyz` to the end of the command line
#   because we wouldn't be able to support:
#     dune exec something.exe -- --some-arg-for-something abc
#   where the `--build-dir xyz` **must** go before `--`.
#
# Solution 1:
#
#   Any arguments that can go in 'dune --somearg somecommand' should be processed here
#   and added to DUNE_OPTS. We'll parse 'somecommand ...' options in a second getopts loop.
BUILDTYPE=
PLATFORM=
while getopts ":hb:p:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        b )
            # shellcheck disable=SC2034
            BUILDTYPE=$OPTARG
        ;;
        p )
            # shellcheck disable=SC2034
            PLATFORM=$OPTARG
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$PLATFORM" ] || [ -z "$BUILDTYPE" ]; then
    usage
    exit 1
fi

if [ "${1:-}" = "--" ]; then # support `platform-dune-exec.sh ... -- --version`
    shift
fi

# END Command line processing
# ------------------

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

install -d "$DKML_DUNE_BUILD_DIR"

# no subcommand should display help
if [ $# -eq 0 ]; then
    usage
    exit 1
else
    subcommand=$1; shift
fi

# ------------
# BEGIN DUNE_OPTS

DUNE_OPTS=(--profile "$PLATFORM-$BUILDTYPE")
case "$BUILDTYPE" in
    Release*)
        # If a Release build then mimic all the same options that `dune --release` does
        # except do not do:
        # * `--profile release` (we have multilpe Release* profiles)
        # * `--default-target @install` (we can and should supply our own targets)
        DUNE_OPTS+=(
            --root .
            --no-config
            --ignore-promoted-rules
            --always-show-command-line
            --promote-install-files
        )
        ;;
    *)
        if is_reproducible_platform; then
            # Never promote source code from, for example, a CI system. Instead only the developers
            # (aka the dev platform) should be able to change source code and possibly check it in.
            DUNE_OPTS+=(
                --root .
                --no-config
                --ignore-promoted-rules
            )
        fi    
esac

# END DUNE_OPTS
# ------------

# -----------------------
# Inject our options first, immediately after the subcommand

case "$subcommand" in
    help)
        exec_in_platform dune help "$@"
    ;;
    *)
        if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
            if is_dev_platform && [ "$BUILDTYPE" = Debug ]; then
                DUNE_OPTS+=() # no-op; use standard Dune build directory for dev-Debug
            elif [ -z "$BUILD_BASEPATH" ]; then
                DUNE_OPTS+=(--build-dir "$BUILDDIR_BUILDHOST${OS_DIR_SEP}_dune") # BUILDDIR_BUILDHOST is absolute path
            else
                DUNE_OPTS+=(--build-dir "@@EXPAND_TOPDIR@@/$DKML_DUNE_BUILD_DIR/_dune")
            fi
        else
            DUNE_OPTS+=(--build-dir "$DKML_DUNE_BUILD_DIR")
        fi
        "$DKMLDIR"/runtime/unix/platform-opam-exec.sh -b "$BUILDTYPE" -p "$PLATFORM" exec -- dune "$subcommand" "${DUNE_OPTS[@]}" "$@"
    ;;
esac
