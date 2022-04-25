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
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    platform-dune-exec.sh -h                                                     Display this help message." >&2
    printf "%s\n" "    platform-dune-exec.sh -b BUILDTYPE -p PLATFORM [--] build|clean|help|...     Run the dune command." >&2
    printf "%s\n" "Options:" >&2
    printf "%s\n" "    -p PLATFORM: (Deprecated) The target platform or 'dev'. 'dev' and -b Debug will use standard Dune _build subdirectory" >&2
    printf "%s\n" "    -p DKMLPLATFORM: The DKML platform (not 'dev')" >&2
    printf "%s\n" "       -d STATEDIR: Use <STATEDIR>/_opam as the Opam switch prefix, unless [-s] is also" >&2
    printf "%s\n" "          selected which uses <STATEDIR>/dkml/_opam, and unless [-s] [-u ON] is also" >&2
    printf "%s\n" "          selected which uses <DiskuvOCamlHome>/dkml/_opam on Windows and" >&2
    printf "%s\n" "          <OPAMROOT>/dkml/_opam on non-Windows." >&2
    printf "%s\n" "          Opam init shell scripts search the ancestor paths for an '_opam' directory, so" >&2
    printf "%s\n" "          the non-system switch will be found if you are in <STATEDIR>" >&2
    printf "%s\n" "       -u ON|OFF: User mode. If OFF, sets Opam --root to <STATEDIR>/opam." >&2
    printf "%s\n" "          Defaults to ON; ie. using Opam 2.2+ default root." >&2
    printf "%s\n" "          Also affects the Opam switches; see [-d STATEDIR] option" >&2
    printf "%s\n" "       -o OPAMHOME: Optional. Home directory for Opam containing bin/opam or bin/opam.exe." >&2
    printf "%s\n" "          The bin/ subdir of the Opam home is added to the PATH" >&2
    printf "%s\n" "       -v OCAMLVERSION_OR_HOME: Optional. The OCaml version or OCaml home (containing bin/ocaml) to use." >&2
    printf "%s\n" "          Examples: 4.13.1, /usr, /opt/homebrew" >&2
    printf "%s\n" "          The bin/ subdir of the OCaml home is added to the PATH; currently, passing an OCaml version does nothing" >&2
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
STATEDIR=
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    USERMODE=OFF
else
    USERMODE=ON
fi
OPAMHOME=
OCAMLVERSION_OR_HOME=
while getopts ":hb:p:d:u:o:v:" opt; do
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
            PLATFORM=$OPTARG
        ;;
        d )
            STATEDIR=$OPTARG
        ;;
        u )
            # shellcheck disable=SC2034
            USERMODE=$OPTARG
        ;;
        o ) OPAMHOME=$OPTARG ;;
        v ) OCAMLVERSION_OR_HOME=$OPTARG ;;
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
. "$DKMLDIR"/vendor/drc/unix/_common_build.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# no subcommand should display help
if [ $# -eq 0 ]; then
    usage
    exit 1
else
    subcommand=$1; shift
fi

# Set DKML_POSIX_SHELL
autodetect_posix_shell

# Set DKMLHOME_UNIX if available
autodetect_dkmlvars || true

# Set TARGET_OPAMSWITCH (only used when USERMODE=ON)
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    TARGET_OPAMSWITCH=
elif cmake_flag_off "$USERMODE"; then
    TARGET_OPAMSWITCH=
else
    if [ -n "${DKML_BUILD_ROOT:-}" ]; then
        RESOLVED_BUILDDIR=$DKML_BUILD_ROOT
    else
        RESOLVED_BUILDDIR=$TOPDIR/build
    fi
    if [ "$PLATFORM" = "dev" ]; then
        # Set BUILDHOST_ARCH
        autodetect_buildhost_arch
        TARGET_OPAMSWITCH=$RESOLVED_BUILDDIR/$BUILDHOST_ARCH/$BUILDTYPE
    else
        TARGET_OPAMSWITCH=$RESOLVED_BUILDDIR/$PLATFORM/$BUILDTYPE
    fi
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

# We want tools/apps/fswatch in the PATH, especially on Windows so we can do `dune build --watch``
{
    printf "%s\n" "#!$DKML_POSIX_SHELL"
    if [ -n "$DKMLHOME_UNIX" ]; then
        printf "PATH='%s':\"\$PATH\"\n" "$DKMLHOME_UNIX/tools/apps"
    fi
} > "$WORK"/add-tools-to-path.sh
chmod +x "$WORK"/add-tools-to-path.sh

# -----------------------
# Inject our options first, immediately after the subcommand

case "$subcommand" in
    help)
        exec_in_platform dune help "$@"
    ;;
    *)
        if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
            install -d "$DKML_DUNE_BUILD_DIR"
            if is_dev_platform && [ "$BUILDTYPE" = Debug ]; then
                DUNE_OPTS+=() # no-op; use standard Dune build directory for dev-Debug
            elif [ -z "$BUILD_BASEPATH" ]; then
                DUNE_OPTS+=(--build-dir "$BUILDDIR_BUILDHOST${OS_DIR_SEP}_dune") # BUILDDIR_BUILDHOST is absolute path
            else
                DUNE_OPTS+=(--build-dir "@@EXPAND_TOPDIR@@/$DKML_DUNE_BUILD_DIR/_dune")
            fi
            "$DKMLDIR"/vendor/drd/src/unix/private/platform-opam-exec.sh -0 "$WORK"/add-tools-to-path.sh -b "$BUILDTYPE" -p "$PLATFORM" exec -- dune "$subcommand" "${DUNE_OPTS[@]}" "$@"
        else
            if is_dev_platform && [ "$BUILDTYPE" = Debug ]; then
                DUNE_OPTS+=() # no-op; use standard Dune build directory for dev-Debug
            else
                if [ -x /usr/bin/cygpath ]; then
                    DUNEDIR_BUILDHOST=$(/usr/bin/cygpath -aw "$TARGET_OPAMSWITCH/_dune")
                else
                    DUNEDIR_BUILDHOST="$TARGET_OPAMSWITCH/_dune"
                fi
                DUNE_OPTS+=(--build-dir "$DUNEDIR_BUILDHOST")
            fi
            "$DKMLDIR"/vendor/drd/src/unix/private/platform-opam-exec.sh -0 "$WORK"/add-tools-to-path.sh -p "$PLATFORM" -b "$BUILDTYPE" -u "$USERMODE" -t "$TARGET_OPAMSWITCH" -o "$OPAMHOME" -v "$OCAMLVERSION_OR_HOME" -d "$STATEDIR" exec -- dune "$subcommand" "${DUNE_OPTS[@]}" "$@"
        fi
    ;;
esac
