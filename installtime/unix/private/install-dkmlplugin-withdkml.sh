#!/bin/sh
# -------------------------------------------------------
# install-dkmlplugin-withdkml.sh PLATFORM
#
# Purpose:
# 1. Compile with-dkml into the plugins/diskuvocaml/ of the OPAMROOT.
#
# When invoked?
# On Windows as part of `setup-userprofile.ps1`
# which is itself invoked by `install-world.ps1`. On both
# Windows and Unix it is also invoked as part of `build-sandbox-init-common.sh`.
#
# Prerequisites:
# - init-opam-root.sh
# - create-diskuv-system-switch.sh
#
# -------------------------------------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    install-dkmlplugin-withdkml.sh -h                   Display this help message" >&2
    echo "    install-dkmlplugin-withdkml.sh -p PLATFORM          (Deprecated) Install the DKML plugin with-dkml" >&2
    echo "    install-dkmlplugin-withdkml.sh [-d STATEDIR]        Install the DKML plugin with-dkml" >&2
    echo "      Without '-d' the Opam root will be the Opam 2.2 default" >&2
    echo "Options:" >&2
    echo "    -p PLATFORM: The target platform or 'dev'" >&2
    echo "    -d STATEDIR: If specified, use <STATEDIR>/opam as the Opam root" >&2
}

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    PLATFORM=
fi
STATEDIR=
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    USERMODE=OFF
else
    USERMODE=ON
fi
while getopts ":h:p:d:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            PLATFORM=$OPTARG
        ;;
        d )
            # shellcheck disable=SC2034
            STATEDIR=$OPTARG
            # shellcheck disable=SC2034
            USERMODE=OFF
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    if [ -z "$PLATFORM" ]; then
        usage
        exit 1
    fi
fi

# END Command line processing
# ------------------

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/../../.." && pwd)

# shellcheck disable=SC1091
. "$DKMLDIR"/runtime/unix/_common_tool.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# BEGIN         ON-DEMAND OPAM ROOT INSTALLATIONS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# We use the Opam plugin directory to hold our root-specific installations.
# http://opam.ocaml.org/doc/Manual.html#opam-root
#
# In Diskuv OCaml each architecture gets its own Opam root.

# Set OPAMROOTDIR_BUILDHOST and OPAMROOTDIR_EXPAND and WITHDKMLEXE(DIR)_BUILDHOST
set_opamrootdir

# -----------------------
# BEGIN install with-dkml (with-dkml)

if [ ! -x "$WITHDKMLEXE_BUILDHOST" ]; then
    # Compile with Dune into temp build directory
    WITHDKML_TMP_UNIX="$WORK"/with-dkml
    APPS_WINDOWS="$DKMLDIR"/installtime/msys2/apps
    if [ -x /usr/bin/cygpath ]; then
        WITHDKML_TMP_WINDOWS=$(/usr/bin/cygpath -aw "$WITHDKML_TMP_UNIX")
        APPS_WINDOWS=$(/usr/bin/cygpath -aw "$APPS_WINDOWS")
    else
        WITHDKML_TMP_WINDOWS="$WITHDKML_TMP_UNIX"
    fi
    install -d "$WITHDKML_TMP_UNIX"
    if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
        "$DKMLDIR"/runtime/unix/platform-opam-exec -s -- exec -- dune build --root "$APPS_WINDOWS" --build-dir "$WITHDKML_TMP_WINDOWS" with-dkml/with_dkml.exe
    else
        "$DKMLDIR"/runtime/unix/platform-opam-exec -s -d "$STATEDIR" -u "$USERMODE" -- exec -- dune build --root "$APPS_WINDOWS" --build-dir "$WITHDKML_TMP_WINDOWS" with-dkml/with_dkml.exe
    fi

    # Place in plugins
    install -d "$WITHDKMLEXEDIR_BUILDHOST"
    install "$WORK/with-dkml/default/with-dkml/with_dkml.exe" "$WITHDKMLEXE_BUILDHOST"
fi

# END install with-dkml (with-dkml)
# -----------------------

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END           ON-DEMAND OPAM ROOT INSTALLATIONS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
