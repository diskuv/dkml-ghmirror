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
    echo "    create-diskuv-system-switch.sh -h   Display this help message" >&2
    echo "    create-diskuv-system-switch.sh      Create the Diskuv system switch" >&2
}

while getopts ":h:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
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
log_trace "$DKMLDIR"/installtime/unix/create-opam-switch.sh -y -s -b Release

# CI packages
{
    printf "%s" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec -s install -y"
    awk 'NF>0 && $1 !~ "#.*" {printf " %s", $1}' "$DKMLDIR"/installtime/none/ci-flavor-packages.txt
} > "$WORK"/config-diskuv-system.sh
log_shell "$WORK"/config-diskuv-system.sh

# END create system switch
# -----------------------
