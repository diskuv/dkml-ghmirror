#!/bin/bash
# -------------------------------------------------------
# deinit-opam-root.sh PLATFORM
#
# Purpose:
# 1. Unregister former Opam roots from previous installs
#
# Prerequisites: A working build/_tools/common/ directory.
#
# -------------------------------------------------------
set -euf -o pipefail

# shellcheck disable=SC2034
PLATFORM=$1
shift

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/../.." && pwd)

# shellcheck disable=SC1091
source "$DKMLDIR"/runtime/unix/_common_tool.sh
# shellcheck disable=SC1091
source "$DKMLDIR"/.dkmlroot # set $dkml_root_version

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# ---------------------
# BEGIN Version Cleanup

function uninstall_opam_root () {
    local OLDOPAMROOT="$1"
    opam switch list --root "$OLDOPAMROOT" --short > "$WORK"/list
    for sw in $(< "$WORK"/list); do
        trimmed_switch=$(echo "$sw" | awk 'NF>0{print $1}')
        if [[ -z "$trimmed_switch" ]] || [[ "$trimmed_switch" = "/" ]]; then
            echo "Unsafe switch deletion: $trimmed_switch" >&2
            exit 2
        fi
        clear
        echo "The OPAM root has changed to $LOCALAPPDATA/opam in 0.2.x. All Diskuv OCaml switches must be deleted and recreated." >&2
        echo "After the upgrade use './makeit prepare-dev' to recreate each of your Local Projects (if any)." >&2
        read -r -p "Candidate for deletion: $trimmed_switch. Are you sure (yes/no)? Type 'yes' to proceed. " yesno
        case "$yesno" in
        yes ) echo "Deleting ...";;
        * )
            echo "Did not type 'yes'. Exiting." >&2
            exit 1
            ;;
        esac
        opam switch remove --root "$OLDOPAMROOT" --yes "$trimmed_switch"
    done
    rm -rf "$OLDOPAMROOT"
}

# shellcheck disable=SC2154
if [[ "$dkml_root_version" = 0.2.0* ]]; then
    # $env:USERPROFILE/.opam is no longer used
    if [[ -n "${USERPROFILE:-}" ]] && [[ -e "${USERPROFILE:-}/.opam/diskuv-boot-DO-NOT-DELETE" ]]; then
        uninstall_opam_root "${USERPROFILE:-}"/.opam
        clear
    fi
    # $env:LOCALAPPDATA/.opam is no longer used
    if [[ -n "${LOCALAPPDATA:-}" ]] && [[ -e "${LOCALAPPDATA:-}/.opam/diskuv-boot-DO-NOT-DELETE" ]]; then
        uninstall_opam_root "${LOCALAPPDATA:-}"/.opam
        clear
    fi
fi

# END Version Cleanup
# ---------------------
