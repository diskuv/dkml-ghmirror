#!/bin/sh
# -------------------------------------------------------
# create-diskuv-system-switch.sh
#
# Purpose:
# 1. Make or upgrade an Opam switch tied to the current installation of Diskuv OCaml
# 2. Not touch any existing installations of Diskuv OCaml (if blue-green deployments are enabled)
#
# When invoked?
# On Windows as part of `setup-userprofile.ps1`
# which is itself invoked by `install-world.ps1`.
#
# -------------------------------------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    create-diskuv-system-switch.sh -h           Display this help message" >&2
    echo "    create-diskuv-system-switch.sh              Create the Diskuv system switch" >&2
    echo "                                                at <DiskuvOCamlHome>/host-abi-tools on Windows or" >&2
    echo "                                                <OPAMROOT>/host-abi-tools/_opam on non-Windows" >&2
    echo "    create-diskuv-system-switch.sh -d STATEDIR  Create the Diskuv system switch" >&2
    echo "                                                at <STATEDIR>/target-abi-tools" >&2
    echo "Options:" >&2
    echo "    -o OCAMLVERSION: Optional. The OCaml version to use. Ex. 4.13.1" >&2
    echo "    -f FLAVOR: Optional; defaults to CI. The flavor of system packages: 'CI' or 'Full'" >&2
    echo "       'Full' is the same as CI, but has packages for UIs like utop and a language server" >&2
}

STATEDIR=
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    USERMODE=OFF
else
    USERMODE=ON
fi
OCAMLVERSION=
FLAVOR=CI
while getopts ":h:d:o:f:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        d )
            # shellcheck disable=SC2034
            STATEDIR=$OPTARG
            # shellcheck disable=SC2034
            USERMODE=OFF
        ;;
        o )
            OCAMLVERSION=$OPTARG
        ;;
        f )
            case "$OPTARG" in
                Ci|CI|ci)       FLAVOR=CI ;;
                Full|FULL|full) FLAVOR=Full ;;
                *)
                    echo "FLAVOR must be CI or Full"
                    usage
                    exit 1
            esac
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

# END Command line processing
# ------------------

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    # shellcheck disable=SC2034
    PLATFORM=dev
else
    # shellcheck disable=SC2034
    DISKUV_SYSTEM_SWITCH=ON
fi

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

# -----------------------
# BEGIN create system switch
#
# Only CI Flavor packages need to be installed.

# Just compiler
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    log_trace "$DKMLDIR"/installtime/unix/create-opam-switch.sh -y -s -o "$OCAMLVERSION" -b Release
else
    log_trace "$DKMLDIR"/installtime/unix/create-opam-switch.sh -y -s -o "$OCAMLVERSION" -d "$STATEDIR" -u "$USERMODE" -b Release
fi

# CI packages
{
    printf "%s" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec -s \"\$@\" install -y"
    case "$FLAVOR" in
        CI)
            awk 'NF>0 && $1 !~ "#.*" {printf " %s", $1}' "$DKMLDIR"/installtime/none/ci-flavor-packages.txt
            ;;
        Full)
            awk 'NF>0 && $1 !~ "#.*" {printf " %s", $1}' "$DKMLDIR"/installtime/none/ci-flavor-packages.txt
            awk 'NF>0 && $1 !~ "#.*" {printf " %s", $1}' "$DKMLDIR"/installtime/none/full-flavor-minus-ci-flavor-packages.txt
            ;;
        *) echo "FATAL: Unsupported flavor $FLAVOR" >&2; exit 107
    esac
} > "$WORK"/config-diskuv-system.sh
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    log_shell "$WORK"/config-diskuv-system.sh
else
    log_shell "$WORK"/config-diskuv-system.sh -d "$STATEDIR" -u "$USERMODE"
fi

# END create system switch
# -----------------------