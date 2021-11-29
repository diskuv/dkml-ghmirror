#!/bin/sh
# -------------------------------------------------------
# init-opam-root.sh PLATFORM
#
# Purpose:
# 1. Install an OPAMROOT (`opam init`) in $env:LOCALAPPDATA/opam or
#    the PLATFORM's opam-root/ folder.
#
# When invoked?
# On Windows as part of `setup-userprofile.ps1`
# which is itself invoked by `install-world.ps1`. On both
# Windows and Unix it is also invoked as part of `build-sandbox-init-common.sh`.
#
# Prerequisites: A working build/_tools/common/ directory.
#
# -------------------------------------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    init-opam-root.sh -h                   Display this help message" >&2
    printf "%s\n" "    init-opam-root.sh -p PLATFORM          (Deprecated) Initialize the Opam root" >&2
    printf "%s\n" "    init-opam-root.sh [-d STATEDIR]        Initialize the Opam root" >&2
    printf "%s\n" "      Without '-d' the Opam root will be the Opam 2.2 default" >&2
    printf "%s\n" "Options:" >&2
    printf "%s\n" "    -p PLATFORM: (Deprecated) The target platform or 'dev'" >&2
    printf "%s\n" "    -d STATEDIR: If specified, use <STATEDIR>/opam as the Opam root" >&2
    printf "%s\n" "    -o OPAMHOME: Optional. Home directory for Opam containing bin/opam or bin/opam.exe" >&2
    printf "%s\n" "    -v OCAMLVERSION_OR_HOME: Optional. The OCaml version or OCaml home (containing usr/bin/ocaml or bin/ocaml)" >&2
    printf "%s\n" "       to use." >&2
    printf "%s\n" "       The bin/ subdir of the OCaml home is added to the PATH; currently, passing an OCaml version does nothing" >&2
    printf "%s\n" "       Examples: 4.13.1, /usr, /opt/homebrew" >&2
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
OPAMHOME=
OCAMLVERSION_OR_HOME=
while getopts ":h:p:d:o:v:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            PLATFORM=$OPTARG
        ;;
        d )
            STATEDIR=$OPTARG
            USERMODE=OFF
        ;;
        o ) OPAMHOME=$OPTARG ;;
        v )
            OCAMLVERSION_OR_HOME=$OPTARG
        ;;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
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
# BEGIN         ON-DEMAND VERSIONED GLOBAL INSTALLS
#
# The user experience for Unix is that `./makeit build-dev` should just work.
# Anything that is in DiskuvOCamlHome is really just for platforms like Windows
# that must have pre-installed software (for Windows that is MSYS2 or we couldn't
# even run this script).
#
# So ... try to do as much as possible in this section (or "ON-DEMAND OPAM ROOT INSTALLATIONS" below).
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Set DKMLPARENTHOME_BUILDHOST
# TODO: These implementation won't work in containers; needs a mount point for the opam repositories, and
# an @@EXPAND_DKMLPARENTHOME@@ macro
set_dkmlparenthomedir

# -------------------
# BEGIN dkmlvars.sexp
#
# Windows defines many variables in setup-userprofile.ps1. Since setup-userprofile.ps1 will call this script
# on Windows, and dkmlvars.sexp should only be written at the end of a successful install, we explicitly only
# set dkmlvars.sexp for non-Windows.
# Some don't make sense for Unix (MSYS2Dir, Home) and some we don't have (DeploymentId).

if ! is_unixy_windows_build_machine && [ ! -e "$DKMLPARENTHOME_BUILDHOST"/dkmlvars-v2.sexp ] ; then
    install -d "$DKMLPARENTHOME_BUILDHOST"
    # shellcheck disable=SC2154
    cat > "$DKMLPARENTHOME_BUILDHOST"/dkmlvars.sexp.tmp <<EOF
(
("DiskuvOCamlVarsVersion" ("2"))
("DiskuvOCamlVersion" ("$dkml_root_version"))
)
EOF
    mv "$DKMLPARENTHOME_BUILDHOST"/dkmlvars.sexp.tmp "$DKMLPARENTHOME_BUILDHOST"/dkmlvars-v2.sexp
fi

# END dkmlvars.sexp
# -------------------

# Set DKMLHOME_UNIX if available
autodetect_dkmlvars || true

# -----------------------
# BEGIN install opam repositories

# Make versioned opam-repositories
#
# Q: Why is opam-repositories here rather than in DiskuvOCamlHome?
# The opam-repositories are required for Unix, not just Windows.
#
# Q: Why aren't we using an HTTP(S) site?
# Yep, we could have done `opam admin index`
# and followed the https://opam.ocaml.org/doc/Manual.html#Repositories instructions.
# It is not hard _but_ we want a) versioning of the repository to coincide with
# the version of Diskuv OCaml and b) ability to
# edit the repository for `AdvancedToolchain.rst` patching. We could have done
# both with HTTP(S) but simpler is usually better.

if [ -x /usr/bin/cygpath ]; then
    # shellcheck disable=SC2154
    OPAMREPOS_MIXED=$(/usr/bin/cygpath -am "$DKMLPARENTHOME_BUILDHOST\\opam-repositories\\$dkml_root_version")
    OPAMREPOS_UNIX=$(/usr/bin/cygpath -au "$DKMLPARENTHOME_BUILDHOST\\opam-repositories\\$dkml_root_version")
else
    OPAMREPOS_MIXED="$DKMLPARENTHOME_BUILDHOST/opam-repositories/$dkml_root_version"
    OPAMREPOS_UNIX="$OPAMREPOS_MIXED"
fi
if [ ! -e "$OPAMREPOS_UNIX".complete ]; then
    install -d "$OPAMREPOS_UNIX"
    if [ -n "${DKMLHOME_UNIX:-}" ] && is_unixy_windows_build_machine; then
        # shellcheck disable=SC2154
        log_trace spawn_rsync -ap \
            "$DKMLHOME_UNIX/$SHARE_OCAML_OPAM_REPO_RELPATH"/ \
            "$OPAMREPOS_UNIX"/fdopen-mingw
    fi
    log_trace spawn_rsync -ap "$DKMLDIR"/etc/opam-repositories/ "$OPAMREPOS_UNIX"
    touch "$OPAMREPOS_UNIX".complete
fi

# END install opam repositories
# -----------------------

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END           ON-DEMAND VERSIONED GLOBAL INSTALLS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# -----------------------
# BEGIN opam init

# Windows does not have a non-deprecated working Opam solution, so we choose
# to have $LOCALAPPDATA/opam be the Opam root for the dev platform. That is
# aligned with ~/.opam for Opam before Opam 2.2. For Windows we also don't have a
# package manager that comes with `opam` pre-compiled, so we bootstrap an
# Opam installation from our Moby Docker downloaded of ocaml/opam image
# (see install-world.ps1).

# Set OPAMROOTDIR_BUILDHOST and OPAMROOTDIR_EXPAND
set_opamrootdir

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    run_opam() {
        log_trace "$DKMLDIR"/runtime/unix/platform-opam-exec.sh -p "$PLATFORM" "$@"
    }
else
    run_opam() {
        log_trace "$DKMLDIR"/runtime/unix/platform-opam-exec.sh -u "$USERMODE" -d "$STATEDIR" -o "$OPAMHOME" -v "$OCAMLVERSION_OR_HOME" "$@"
    }
fi

# `opam init`.
#
# --no-setup: Don't modify user shell configuration (ex. ~/.profile). For containers,
#             the home directory inside the Docker container is not persistent anyways.
# --bare: so we can configure its settings before adding the OCaml system compiler.
REPONAME_PENDINGREMOVAL=pendingremoval-opam-repo
if ! is_minimal_opam_root_present "$OPAMROOTDIR_BUILDHOST"; then
    if is_unixy_windows_build_machine; then
        # We'll use `pendingremoval` as a signal that we can remove it later if it is the 'default' repository.
        # --disable-sandboxing: Sandboxing does not work on Windows
        run_opam init --yes --disable-sandboxing --no-setup --kind local --bare "$OPAMREPOS_MIXED/$REPONAME_PENDINGREMOVAL"
    elif [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ] && is_reproducible_platform; then
        # --disable-sandboxing: Can't nest Opam sandboxes inside of our Build Sandbox because nested chroots are not supported
        run_opam init --yes --disable-sandboxing --no-setup --bare
    else
        run_opam init --yes --no-setup --bare
    fi
fi

# If and only if we have Windows Opam root we have to configure its global options
# to tell it to use `wget` instead of `curl`
if is_unixy_windows_build_machine && is_minimal_opam_root_present "$OPAMROOTDIR_BUILDHOST"; then
    WINDOWS_DOWNLOAD_COMMAND=wget

    # MSYS curl does not work with Opam. After debugging with `platform-opam-exec.sh ... reinstall ocaml-variants --debug` found it was calling:
    #   C:\source\...\build\_tools\common\MSYS2\usr\bin\curl.exe --write-out %{http_code}\n --retry 3 --retry-delay 2 --user-agent opam/2.1.0 -L -o C:\Users\...\.opam\4.12\.opam-switch\sources\ocaml-variants\4.12.0.tar.gz.part -- https://github.com/ocaml/ocaml/archive/4.12.0.tar.gz
    # yet erroring with:
    #   [ERROR] Failed to get sources of ocaml-variants.4.12.0+msvc64: curl error code %http_coden
    # Seems like Windows command line processing is stripping braces and backslash (upstream bugfix: wrap --write-out argument with single quotes?).
    # Goes away with wget!! With wget has no funny symbols ... it is like:
    #   C:\source\...\build\_tools\common\MSYS2\usr\bin\wget.exe --content-disposition -t 3 -O C:\Users\...\AppData\Local\Temp\opam-29232-cc6ec1\inline-flexdll.patch.part -U opam/2.1.0 -- https://gist.githubusercontent.com/fdopen/fdc645a61a208552ebac76a67eafd3ee/raw/9f521e91c8f0e9490652651ccdbfae88da701919/inline-flexdll.patch
    if ! grep -q '^download-command: wget' "$OPAMROOTDIR_BUILDHOST/config"; then
        run_opam option --yes --global download-command=$WINDOWS_DOWNLOAD_COMMAND
    fi
fi

# Make a `default` repo that is actually an overlay of diskuv-opam-repo and fdopen (only on Windows and defined as --rank=2 in create-opam-switch.sh) and finally the offical Opam repository.
# If we don't we get make a repo named "default" in opam 2.1.0 the following will happen:
#     #=== ERROR while compiling ocamlbuild.0.14.0 ==================================#
#     Sys_error("C:\\Users\\user\\.opam\\repo\\default\\packages\\ocamlbuild\\ocamlbuild.0.14.0\\files\\ocamlbuild-0.14.0.patch: No such file or directory")
if [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/diskuv-$dkml_root_version" ] && [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/diskuv-$dkml_root_version.tar.gz" ]; then
    OPAMREPO_DISKUV="$OPAMREPOS_MIXED/diskuv-opam-repo"
    run_opam repository add diskuv-"$dkml_root_version" "$OPAMREPO_DISKUV" --yes --dont-select --rank=1
fi
# check if we can remove 'default' if it was pending removal.
# sigh, we have to parse non-machine friendly output. we'll do safety checks.
if [ -e "$OPAMROOTDIR_BUILDHOST/repo/default" ] || [ -e "$OPAMROOTDIR_BUILDHOST/repo/default.tar.gz" ]; then
    run_opam repository list --all > "$WORK"/list
    awk '$1=="default" {print $2}' "$WORK"/list > "$WORK"/default
    _NUMLINES=$(awk 'END{print NR}' "$WORK"/default)
    if [ "$_NUMLINES" -ne 1 ]; then
        printf "%s\n" "FATAL: init-opam-root.sh does not understand the Opam repo format used at $OPAMROOTDIR_BUILDHOST/repo/default" >&2
        printf "%s\n" "FATAL: Details A:" >&2
        ls "$OPAMROOTDIR_BUILDHOST"/repo >&2
        printf "%s\n" "FATAL: Details B:" >&2
        cat "$WORK"/default
        printf "%s\n" "FATAL: Details C:" >&2
        cat "$WORK"/list
        exit 1
    fi
    if grep -q "/$REPONAME_PENDINGREMOVAL"$ "$WORK"/default; then
        # ok. is like file://C:/source/xxx/etc/opam-repositories/pendingremoval-opam-repo
        run_opam repository remove default --yes --all --dont-select
    fi
fi
# add back the default we want if a default is not there
if [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/default" ] && [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/default.tar.gz" ]; then
    run_opam repository add default https://opam.ocaml.org --yes --dont-select --rank=3
fi

# END opam init
# -----------------------
