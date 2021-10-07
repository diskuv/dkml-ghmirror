#!/bin/bash
#################################################
# _common_tool.sh
#
# Inputs:
#   DKMLDIR: The location of the vendored directory 'diskuv-ocaml' containing
#      the file '.dkmlroot'.
#   TOPDIR: Optional. The project top directory containing 'dune-project'. If
#     not specified it will be discovered from DKMLDIR.
#   BUILDDIR: Optional. The directory that will have a _opam subdirectory containing
#     the Opam switch. If not specified will be crafted from BUILDTYPE.
#   PLATFORM: One of the PLATFORMS defined in TOPDIR/Makefile
#   BUILDTYPE: One of the BUILDTYPES defined in TOPDIR/Makefile
#
#################################################

# shellcheck disable=SC1091
. "$DKMLDIR"/runtime/unix/_common_tool.sh

if [ -z "${BUILDDIR:-}" ]; then
    # shellcheck disable=SC2034
    BUILDDIR="$BUILD_ROOT_UNIX/$PLATFORM/$BUILDTYPE"
fi

# BUILDDIR is sticky, so that platform-opam-exec and any other scripts can be called as children and behave correctly.
export BUILDDIR

# Opam Windows has a weird bug where it rsyncs very very slowly all pinned directories (recursive
# super slowness). There is a possibly related reference on https://github.com/ocaml/opam/wiki/2020-Developer-Meetings#opam-tools
# By setting ON we can use GLOBAL switches for Windows, and namespace it with
# a hash-based encoding of the TOPDIR so, for all intents and purposes, it is a local switch.
USE_GLOBALLY_REGISTERED_LOCAL_SWITCHES_ON_WINDOWS=OFF

# There is one Opam switch for each build directory.
#
# Inputs:
# - env:PLATFORM
# - env:BUILDTYPE
# - env:BUILDDIR. Automatically set by this script if not already set.
# Outputs:
# - env:OPAMROOTDIR_BUILDHOST - [As per set_opamrootdir] The path to the Opam root directory that is usable only on the
#     build machine (not from within a container)
# - env:OPAMROOTDIR_EXPAND - [As per set_opamrootdir] The path to the Opam root directory switch that works as an
#     argument to `exec_in_platform`
# - env:OPAMSWITCHFINALDIR_BUILDHOST - Either:
#     The path to the switch that represents the build directory that is usable only on the
#     build machine (not from within a container). For an external (aka local) switch the returned path will be
#     a `.../_opam`` folder which is where the final contents of the switch live. Use OPAMSWITCHDIR_EXPAND
#     if you want an XXX argument for `opam --switch XXX` rather than this path which is not compatible.
# - env:OPAMSWITCHNAME_BUILDHOST - The name of the switch seen on the build host from `opam switch list --short`
# - env:OPAMSWITCHISGLOBAL - Either ON (switch is global) or OFF (switch is external; aka local)
# - env:OPAMSWITCHDIR_EXPAND - Either
#     The path to the switch **not including any _opam subfolder** that works as an argument to `exec_in_platform` -OR-
#     The name of a global switch that represents the build directory.
#     OPAMSWITCHDIR_EXPAND works inside or outside of a container.
set_opamrootandswitchdir() {
    # Set OPAMROOTDIR_BUILDHOST and OPAMROOTDIR_EXPAND
    set_opamrootdir

    if [ "$USE_GLOBALLY_REGISTERED_LOCAL_SWITCHES_ON_WINDOWS" = ON ] && is_unixy_windows_build_machine; then
        set_opamrootandswitchdir_OPAMGLOBALNAME=$(echo "$TOPDIR" | sha256sum | cut -c1-16 | awk '{print $1}')$(echo "$TOPDIR" | tr / . |  tr -dc '[:alnum:]-_.')
        OPAMSWITCHISGLOBAL=ON
        OPAMSWITCHFINALDIR_BUILDHOST="$OPAMROOTDIR_BUILDHOST/$set_opamrootandswitchdir_OPAMGLOBALNAME"
        OPAMSWITCHNAME_BUILDHOST="$set_opamrootandswitchdir_OPAMGLOBALNAME"
        OPAMSWITCHDIR_EXPAND="$set_opamrootandswitchdir_OPAMGLOBALNAME"
    else
        # shellcheck disable=SC2034
        OPAMSWITCHISGLOBAL=OFF
        # shellcheck disable=SC2034
        OPAMSWITCHFINALDIR_BUILDHOST="${BUILD_BASEPATH}$BUILDDIR/_opam"
        if is_unixy_windows_build_machine; then
            OPAMSWITCHNAME_BUILDHOST=$(cygpath -aw "${BUILD_BASEPATH}$BUILDDIR")
        else
            # shellcheck disable=SC2034
            OPAMSWITCHNAME_BUILDHOST="${BUILD_BASEPATH}$BUILDDIR"
        fi
        if [ -z "$BUILD_BASEPATH" ]; then
            OPAMSWITCHDIR_EXPAND="$OPAMSWITCHNAME_BUILDHOST"
        else
            # shellcheck disable=SC2034
            OPAMSWITCHDIR_EXPAND="@@EXPAND_TOPDIR@@/$BUILDDIR"
        fi
    fi
}
