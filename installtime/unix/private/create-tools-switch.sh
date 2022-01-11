#!/bin/sh
# -------------------------------------------------------
# create-tools-switch.sh
#
# Purpose:
# 1. Make or upgrade an Opam switch tied to the current installation of Diskuv OCaml and the
#    current DKMLPLATFORM.
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
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    create-tools-switch.sh -h           Display this help message" >&2
    printf "%s\n" "    create-tools-switch.sh              Create the Diskuv system switch" >&2
    printf "%s\n" "                                                    at <DiskuvOCamlHome>/host-tools on Windows or" >&2
    printf "%s\n" "                                                    <OPAMROOT>/host-tools/_opam on non-Windows" >&2
    printf "%s\n" "    create-tools-switch.sh -d STATEDIR -p DKMLPLATFORM  Create the Diskuv system switch" >&2
    printf "%s\n" "                                                        at <STATEDIR>/host-tools" >&2
    printf "%s\n" "Options:" >&2
    printf "%s\n" "    -p DKMLPLATFORM: The DKML platform for the tools" >&2
    printf "%s\n" "    -f FLAVOR: Optional; defaults to CI. The flavor of system packages: 'CI' or 'Full'" >&2
    printf "%s\n" "       'Full' is the same as CI, but has packages for UIs like utop and a language server" >&2
    printf "%s\n" "    -v OCAMLVERSION_OR_HOME: Optional. The OCaml version or OCaml home (containing usr/bin/ocaml or bin/ocaml)" >&2
    printf "%s\n" "       to use. The OCaml home determines the native code produced by the switch." >&2
    printf "%s\n" "       Examples: 4.13.1, /usr, /opt/homebrew" >&2
    printf "%s\n" "    -o OPAMHOME: Optional. Home directory for Opam containing bin/opam or bin/opam.exe" >&2
}

STATEDIR=
USERMODE=ON
OCAMLVERSION_OR_HOME=
OPAMHOME=
FLAVOR=CI
DKMLPLATFORM=
while getopts ":hd:o:p:v:f:" opt; do
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
        v )
            OCAMLVERSION_OR_HOME=$OPTARG
        ;;
        o ) OPAMHOME=$OPTARG ;;
        p )
            DKMLPLATFORM=$OPTARG
            if [ "$DKMLPLATFORM" = dev ]; then
                usage
                exit 0
            fi
            ;;
        f )
            case "$OPTARG" in
                Ci|CI|ci)       FLAVOR=CI ;;
                Full|FULL|full) FLAVOR=Full ;;
                *)
                    printf "%s\n" "FLAVOR must be CI or Full"
                    usage
                    exit 1
            esac
        ;;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

# END Command line processing
# ------------------

if [ -z "$DKMLPLATFORM" ]; then
    printf "Must specify -p DKMLPLATFORM option\n" >&2
    usage
    exit 1
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

# Set NUMCPUS if unset from autodetection of CPUs
autodetect_cpus

# Set DKML_POSIX_SHELL
autodetect_posix_shell

# Just the OCaml compiler
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    log_trace "$DKMLDIR"/installtime/unix/create-opam-switch.sh -y -s -v "$OCAMLVERSION_OR_HOME" -o "$OPAMHOME" -b Release
else
    log_trace "$DKMLDIR"/installtime/unix/create-opam-switch.sh -y -s -v "$OCAMLVERSION_OR_HOME" -o "$OPAMHOME" -b Release -d "$STATEDIR" -u "$USERMODE" -p "$DKMLPLATFORM"
fi

# Flavor packages
{
    printf "%s" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec.sh -s -v '$OCAMLVERSION_OR_HOME' -o '$OPAMHOME' \"\$@\" install -y"
    printf " %s" "--jobs=$NUMCPUS"
    case "$FLAVOR" in
        CI)
            awk 'NF>0 && $1 !~ "#.*" {printf " %s", $1}' "$DKMLDIR"/installtime/none/ci-flavor-packages.txt
            ;;
        Full)
            awk 'NF>0 && $1 !~ "#.*" {printf " %s", $1}' "$DKMLDIR"/installtime/none/ci-flavor-packages.txt
            awk 'NF>0 && $1 !~ "#.*" {printf " %s", $1}' "$DKMLDIR"/installtime/none/full-flavor-minus-ci-flavor-packages.txt
            ;;
        *) printf "%s\n" "FATAL: Unsupported flavor $FLAVOR" >&2; exit 107
    esac
} > "$WORK"/config-diskuv-host-tools.sh
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    log_shell "$WORK"/config-diskuv-host-tools.sh
else
    log_shell "$WORK"/config-diskuv-host-tools.sh -d "$STATEDIR" -u "$USERMODE" -p "$DKMLPLATFORM"
fi

# END create system switch
# -----------------------
