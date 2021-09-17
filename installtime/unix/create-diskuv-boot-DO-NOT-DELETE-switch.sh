#!/bin/bash
# -------------------------------------------------------
# create-diskuv-boot-DO-NOT-DELETE-switch.sh
#
# Purpose: Make a global switch that ...
#
# 1. Allows IDEs like VS Code to run `opam var root` which needs
#    at least one global switch present.
# 2. In the future may compile OCaml code that will upgrade the
#    `diskuv-system` switches (instead of the hard-to-maintain /
#    hard-to-test Bash scripts in use today, and instead of
#    relying on the user to have up-to-date Bash scripts).
#
# Prerequisites: A working build/_tools/common/ directory.
#   And an OPAMROOT created by `init-opam-root.sh`.
#
# The global switch will be called `diskuv-boot-DO-NOT-DELETE`
# and initially it will NOT include a working system compiler. Over
# time we may add a system compiler that may get out of date but it
# can be upgraded like any other opam switch.
#
# -------------------------------------------------------
set -euf -o pipefail

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    create-diskuv-boot-DO-NOT-DELETE-switch.sh -h   Display this help message." >&2
    echo "    create-diskuv-boot-DO-NOT-DELETE-switch.sh      Create the Opam switch." >&2
}

while getopts ":h" opt; do
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

if [ -z "${DKMLDIR:-}" ]; then
    DKMLDIR=$(dirname "$0")
    DKMLDIR=$(cd "$DKMLDIR/../.." && pwd)
fi
if [ ! -e "$DKMLDIR/.dkmlroot" ]; then echo "FATAL: Not embedded within or launched from a 'diskuv-ocaml' Local Project" >&2 ; exit 1; fi

PLATFORM=dev # not actually in the dev platform but we are just pulling the "common" tool functions (so we can choose whatever platform we like)

# shellcheck disable=SC1091
source "$DKMLDIR"/runtime/unix/_common_tool.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# -----------------------
# BEGIN opam switch create  --empty

# Set OPAMROOTDIR_BUILDHOST and OPAMROOTDIR_EXPAND
set_opamrootdir
# Set the other vars needed
OPAMGLOBALNAME="diskuv-boot-DO-NOT-DELETE"
OPAMSWITCHFINALDIR_BUILDHOST="$OPAMROOTDIR_BUILDHOST/$OPAMGLOBALNAME"
OPAMSWITCHDIR_EXPAND="$OPAMGLOBALNAME"

OPAM_SWITCH_CREATE_ARGS=(
    --empty
    --yes
)

if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then OPAM_SWITCH_CREATE_ARGS+=(--debug-level 2); fi

if ! is_empty_opam_switch_present "$OPAMSWITCHFINALDIR_BUILDHOST"; then
    # clean up any partial install
    "$DKMLDIR"/runtime/unix/platform-opam-exec -p "$PLATFORM" switch remove "$OPAMSWITCHDIR_EXPAND" --yes || \
        rm -rf "$OPAMSWITCHFINALDIR_BUILDHOST"
    # do real install
    "$DKMLDIR"/runtime/unix/platform-opam-exec -p "$PLATFORM" \
        switch create "$OPAMSWITCHDIR_EXPAND" "${OPAM_SWITCH_CREATE_ARGS[@]}"
fi

# END opam switch create --empty
# -----------------------
