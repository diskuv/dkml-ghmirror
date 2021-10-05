#!/bin/sh
# ----------------------------
# Copyright 2021 Diskuv, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------
#
# @jonahbeckford: 2021-09-07
# - This file is licensed differently than the rest of the Diskuv OCaml distribution.
#   Keep the Apache License in this file since this file is part of the reproducible
#   build files.
#
#################################################
# _common_tool.sh
#
# Inputs:
#   DKMLDIR: The 'diskuv-ocaml' vendored directory containing '.dkmlroot'.
#   TOPDIR: Optional. The project top directory containing 'dune-project'. If
#     not specified it will be discovered from DKMLDIR.
#   PLATFORM: One of the PLATFORMS defined in TOPDIR/Makefile
#
#################################################

is_dev_platform() {
    if [ "$PLATFORM" = "dev" ]; then
        return 0
    fi
    return 1
}

is_reproducible_platform() {
    if [ "$PLATFORM" = "dev" ]; then
        return 1
    fi
    return 0
}

if [ ! -e "$DKMLDIR/.dkmlroot" ]; then echo "FATAL: Not embedded within or launched from a 'diskuv-ocaml' Local Project" >&2 ; exit 1; fi

# set $dkml_root_version
# shellcheck disable=SC1091
. "$DKMLDIR"/.dkmlroot
dkml_root_version=$(echo "$dkml_root_version" | tr -d '\r')

if [ -z "${TOPDIR:-}" ]; then
    # Check at most 10 ancestors
    if [ -n "${TOPDIR_CANDIDATE:-}" ]; then
        TOPDIR=$(cd "$TOPDIR_CANDIDATE" && pwd)
    else
        TOPDIR=$(cd "$DKMLDIR" && cd .. && pwd) # `cd ..` works if DKMLDIR is a Windows path
    fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ] && [ "$TOPDIR" != "/" ]; then TOPDIR=$(cd "$TOPDIR"/.. && pwd); fi
    if [ ! -e "$TOPDIR/dune-project" ]; then echo "FATAL: Not embedded in a Dune-based project with a 'dune-project' file" >&2 ; exit 1; fi
fi

# TOPDIR is sticky, so that platform-opam-exec and any other scripts can be called as children and behave correctly.
export TOPDIR

# Temporary directory that needs to be accessible inside and outside of containers so shell scripts
# can be sent from the outside of a container into a container.
# So we make $WORK be a subdirectory of $TOPDIR.
# Our use of mktemp needs to be portable; docs at:
# * BSD: https://www.freebsd.org/cgi/man.cgi?query=mktemp&sektion=1
# * GNU: https://www.gnu.org/software/autogen/mktemp.html
# Use $WORK in all situations except:
# * Use $WORK_EXPAND to communicate the location of a temporary shell script as an argument to `exec_in_platform`
# * Use $WORK_EXPAND_UNIX to communicate the location of a temporary shell script as a UNIX-path argument to `exec_in_platform`
TMPPARENTDIR_RELTOP="build/_tmp"
TMPPARENTDIR_BUILDHOST="${TMPPARENTDIR_BUILDHOST:-$TOPDIR/$TMPPARENTDIR_RELTOP}"
install -d "$TMPPARENTDIR_BUILDHOST"
WORK=$(mktemp -d "$TMPPARENTDIR_BUILDHOST"/work.XXXXXXXXXX)
trap 'rm -rf "$WORK"' EXIT
WORK_BASENAME=$(basename "$WORK")
# shellcheck disable=SC2034
WORK_EXPAND="@@EXPAND_TOPDIR@@/$TMPPARENTDIR_RELTOP/$WORK_BASENAME"
# shellcheck disable=SC2034
WORK_EXPAND_UNIX="@@EXPAND_TOPDIR_UNIX@@/$TMPPARENTDIR_RELTOP/$WORK_BASENAME"
unset WORK_BASENAME

# shellcheck disable=SC1091
. "$DKMLDIR/etc/contexts/linux-build/crossplatform-functions.sh"

# shellcheck disable=SC2034
TOOLSDIR="build/_tools/$PLATFORM"
# shellcheck disable=SC2034
TOOLSCOMMONDIR="build/_tools/common"
# shellcheck disable=SC2034
MULTIARCHTOOLSDIR="build/_tools/_multiarch"
# shellcheck disable=SC2034
OPAMROOT_IN_CONTAINER="$TOOLSDIR"/opam-root

#####
# BEGIN Opam in Windows
#
# Terminology: "port" is msvc or mingw, and described in https://discuss.ocaml.org/t/ann-ocaml-opam-images-for-docker-for-windows/8179
#
# We want to consistently use MSVC compiled libraries and executables so we don't have to debug hard-to-resolve cross-compiler
# issues ... we are using MSVC elsewhere (especially CMake) since it is far more widely adopted; it has way more package support.
# The only exception is when we are trying to compile a native Windows opam.exe within Cygwin. When using our Cygwin setup and the
# 4.12.0+msvc64 variant the ./autoconf for the package `ocaml-variants` detects the MSVC compiler and the Cygwin ld.exe which causes
# the build to break. So for bootstrapping opam.exe we use MinGW. (We don't expect this to happen with MSYS2 since MSYS2 is tested
# for this common cross-compiling on Windows scenario).
#
# We are downloading (install-world.ps1 / moby-download-docker-image.sh) the Docker `amd64`
# architecture (https://hub.docker.com/r/ocaml/opam/tags?page=1&ordering=last_updated&name=windows)
# for our binaries.
# shellcheck disable=SC2034
OPAM_ARCH_IN_WINDOWS=amd64
#
# Which port we will use for all the switches in Windows.
#
# shellcheck disable=SC2034
OPAM_PORT_FOR_SWITCHES_IN_WINDOWS=msvc
#
# Which variant we will use for all the switches in Windows.
# Pick from a msys2 variant in $DiskuvOCamlHome/etc/opam-repositories/diskuv-opam-repo
# that aligns with the OPAM_PORT_FOR_SWITCHES_IN_WINDOWS.
# shellcheck disable=SC2034
OCAML_VARIANT_FOR_SWITCHES_IN_32BIT_WINDOWS=4.12.0+options+dkml+msvc32
OCAML_VARIANT_FOR_SWITCHES_IN_64BIT_WINDOWS=4.12.0+options+dkml+msvc64
#
# END Opam in Windows
#####

# Execute a command either for the dev environment or for the
# reproducible sandbox corresponding to `$PLATFORM`
# which must be defined.
#
# When the optional `$BUILDTYPE` is non-empty the build type and
# corresponding environment variables (`DK_BUILD_TYPE`) will
# be available in the platform.
#
# Inputs:
#   env:PLATFORM          - required. which platform to run in
#   env:BUILDTYPE         - optional
#   env:COMPILATION       - optional. if set to OFF then no compilation tools
#                           like vcvars64.bat will be added to the environment
#                           which can be time consuming if not needed
#   env:PLATFORM_EXEC_PRE - optional. acts as hook.
#                           the specified bash statements, if any, are executed
#                           and their standard output captured. that standard
#                           output is 'dos2unix'-d and 'eval'-d _before_ the
#                           command line arguments are executed.
#                           You can think of it behaving like:
#                             eval "$PLATFORM_EXEC_PRE" | dos2unix > /tmp/eval.sh
#                             eval /tmp/eval.sh
#   $@                    - the command line arguments that will be executed
#
# The text of the arguments $@ and PLATFORM_EXEC_PRE have any macros expanded:
#
#   @@EXPAND_WINDOWS_DISKUVOCAMLHOME@@: The directory containing dkmlvars.sh.
#     Only available when `is_unixy_windows_build_machine` is true (return code 0).
#     When running in MSYS2 the directory will be Windows style (ex. C:\)
#   @@EXPAND_WINDOWS_DISKUVOCAMLHOME_UNIX@@: The directory containing dkmlvars.sh.
#     Only available when `is_unixy_windows_build_machine` is true (return code 0).
#     The directory will always be Unix style (ex. /home/user).
#   @@EXPAND_WINDOWS_DISKUVOCAMLHOME_MIXED@@: The directory containing bin/ocaml.
#     Only available when `is_unixy_windows_build_machine` is true (return code 0).
#     The directory will always be mixed style (ex. C:/home/user).
#   @@EXPAND_TOPDIR@@: The top project directory containing `dune-project`.
#     When running in MSYS2 the directory will be Windows style (ex. C:\)
#   @@EXPAND_TOPDIR_UNIX@@: The top project directory containing `dune-project`.
#     The directory will always be Unix style (ex. /home/user).
#   @@EXPAND_DKMLDIR@@: The directory containing the vendored `diskuv-ocaml/.dkmlroot`.
#     When running in MSYS2 the directory will be Windows style (ex. C:\)
#   @@EXPAND_DKMLDIR_UNIX@@: The directory containing the vendored `diskuv-ocaml/.dkmlroot`.
#     The directory will always be Unix style (ex. /home/user).
exec_in_platform() {
    _exec_dev_or_arch_helper "$PLATFORM" "$@"
}

# Execute a command either for the dev environment or for the
# reproducible sandbox corresponding to the build machine's architecture.
#
# When the optional `$BUILDTYPE` is non-empty the build type and
# corresponding environment variables (`DK_BUILD_TYPE`) will
# be available in the platform.
#
# Can do macro replacement of the arguments:
# @@EXPAND_WINDOWS_DISKUVOCAMLHOME@@: The directory containing bin/ocaml.
#   Only available when `is_unixy_windows_build_machine` is true (return code 0).
#   When running in MSYS2 the directory will be Windows style (ex. C:\)
# @@EXPAND_WINDOWS_DISKUVOCAMLHOME_UNIX@@: The directory containing bin/ocaml.
#   Only available when `is_unixy_windows_build_machine` is true (return code 0).
#   The directory will always be Unix style (ex. /home/user).
# @@EXPAND_WINDOWS_DISKUVOCAMLHOME_MIXED@@: The directory containing bin/ocaml.
#   Only available when `is_unixy_windows_build_machine` is true (return code 0).
#   The directory will always be mixed style (ex. C:/home/user).
# @@EXPAND_TOPDIR@@: The top directory containing dune-project.
#   When running in MSYS2 the directory will be Windows style (ex. C:\)
# @@EXPAND_TOPDIR_UNIX@@: The top project directory containing `dune-project`.
#   The directory will always be Unix style (ex. /home/user).
# @@EXPAND_DKMLDIR@@: The directory containing the vendored `diskuv-ocaml/.dkmlroot`.
#   When running in MSYS2 the directory will be Windows style (ex. C:\)
# @@EXPAND_DKMLDIR_UNIX@@: The directory containing the vendored `diskuv-ocaml/.dkmlroot`.
#   The directory will always be Unix style (ex. /home/user).
exec_dev_or_multiarch() {
    build_machine_arch
    _exec_dev_or_arch_helper "$BUILDHOST_ARCH" "$@"
}

_exec_dev_or_arch_helper() {
    _exec_dev_or_arch_helper_PLATFORM=$1
    shift
    _exec_dev_or_arch_helper_CMDFILE="$WORK"/_exec_dev_or_arch_helper-cmdfile.sh
    _exec_dev_or_arch_helper_CMDARGS="$WORK"/_exec_dev_or_arch_helper-cmdfile.args
    true > "$_exec_dev_or_arch_helper_CMDARGS"
    if [ -n "${BUILDTYPE:-}" ]; then
        printf "  -b %s" "$BUILDTYPE" >> "$_exec_dev_or_arch_helper_CMDARGS"
    fi
    if [ "${COMPILATION:-}" = OFF ]; then
        printf "  -n" >> "$_exec_dev_or_arch_helper_CMDARGS"
    fi
    if is_dev_platform || is_unixy_windows_build_machine; then
        if is_unixy_windows_build_machine && [ -z "${DiskuvOCamlHome:-}" ]; then
            echo "FATAL: You must run $DKMLDIR/installtime/windows/install-world.ps1 at least once" >&2
            exit 79
        fi
        if [ -x /usr/bin/cygpath ]; then
            _exec_dev_or_arch_helper_ACTUALTOPDIR=$(/usr/bin/cygpath -aw "$TOPDIR")
            _exec_dev_or_arch_helper_ACTUALTOPDIR_UNIX=$(/usr/bin/cygpath -au "$TOPDIR")
            _exec_dev_or_arch_helper_ACTUALDKMLDIR=$(/usr/bin/cygpath -aw "$DKMLDIR")
            _exec_dev_or_arch_helper_ACTUALDKMLDIR_UNIX=$(/usr/bin/cygpath -au "$DKMLDIR")
            _exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME=$(/usr/bin/cygpath -aw "$DiskuvOCamlHome")
            _exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME_UNIX=$(/usr/bin/cygpath -au "$DiskuvOCamlHome")
            _exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME_MIXED=$(/usr/bin/cygpath -am "$DiskuvOCamlHome")
        else
            _exec_dev_or_arch_helper_ACTUALTOPDIR="$TOPDIR"
            _exec_dev_or_arch_helper_ACTUALTOPDIR_UNIX="$TOPDIR"
            _exec_dev_or_arch_helper_ACTUALDKMLDIR="$DKMLDIR"
            _exec_dev_or_arch_helper_ACTUALDKMLDIR_UNIX="$DKMLDIR"
        fi
        for _exec_dev_or_arch_helper_ARG in "$@"; do
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_TOPDIR@@ "${_exec_dev_or_arch_helper_ACTUALTOPDIR}")
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_TOPDIR_UNIX@@ "${_exec_dev_or_arch_helper_ACTUALTOPDIR_UNIX}")
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_DKMLDIR@@ "${_exec_dev_or_arch_helper_ACTUALDKMLDIR}")
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_DKMLDIR_UNIX@@ "${_exec_dev_or_arch_helper_ACTUALDKMLDIR_UNIX}")
            if is_unixy_windows_build_machine; then
                _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME@@ "${_exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME}")
                _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_UNIX@@ "${_exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME_UNIX}")
                _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_MIXED@@ "${_exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME_MIXED}")
            fi
            printf "%s\n  '%s'" " \\" "$_exec_dev_or_arch_helper_ARG" >> "$_exec_dev_or_arch_helper_CMDARGS"
        done
        if [ -n "${PLATFORM_EXEC_PRE:-}" ]; then
            ACTUAL_PRE_HOOK="$PLATFORM_EXEC_PRE"
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_TOPDIR@@ "${_exec_dev_or_arch_helper_ACTUALTOPDIR}")
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_TOPDIR_UNIX@@ "${_exec_dev_or_arch_helper_ACTUALTOPDIR_UNIX}")
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_DKMLDIR@@ "${_exec_dev_or_arch_helper_ACTUALDKMLDIR}")
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_DKMLDIR_UNIX@@ "${_exec_dev_or_arch_helper_ACTUALDKMLDIR_UNIX}")
            if is_unixy_windows_build_machine; then
                ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME@@ "${_exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME}")
                ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_UNIX@@ "${_exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME_UNIX}")
                ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_MIXED@@ "${_exec_dev_or_arch_helper_ACTUALDISKUVOCAMLHOME_MIXED}")
            fi
        fi
        echo "exec '$DKMLDIR'/runtime/unix/within-dev -p '$_exec_dev_or_arch_helper_PLATFORM' -1 '${ACTUAL_PRE_HOOK:-}' \\" > "$_exec_dev_or_arch_helper_CMDFILE"
    else
        for _exec_dev_or_arch_helper_ARG in "$@"; do
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_TOPDIR@@ "/work")
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_TOPDIR_UNIX@@ "/work")
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME@@ "/opt/diskuv-ocaml")
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_UNIX@@ "/opt/diskuv-ocaml")
            _exec_dev_or_arch_helper_ARG=$(replace_all "${_exec_dev_or_arch_helper_ARG}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_MIXED@@ "/opt/diskuv-ocaml")
            printf "%s\n  '%s'" " \\" "$_exec_dev_or_arch_helper_ARG" >> "$_exec_dev_or_arch_helper_CMDARGS"
        done
        if [ -n "${PLATFORM_EXEC_PRE:-}" ]; then
            ACTUAL_PRE_HOOK="$PLATFORM_EXEC_PRE"
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_TOPDIR@@ "/work")
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_TOPDIR_UNIX@@ "/work")
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME@@ "/opt/diskuv-ocaml")
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_UNIX@@ "/opt/diskuv-ocaml")
            ACTUAL_PRE_HOOK=$(replace_all "${ACTUAL_PRE_HOOK}" @@EXPAND_WINDOWS_DISKUVOCAMLHOME_MIXED@@ "/opt/diskuv-ocaml")
        fi
        echo "exec '$DKMLDIR'/runtime/unix/within-sandbox -p '$_exec_dev_or_arch_helper_PLATFORM' -1 '${ACTUAL_PRE_HOOK:-}' \\" > "$_exec_dev_or_arch_helper_CMDFILE"
    fi
    cat "$_exec_dev_or_arch_helper_CMDARGS" >> "$_exec_dev_or_arch_helper_CMDFILE"

    log_shell "$_exec_dev_or_arch_helper_CMDFILE"
}

# Detects DiskuvOCaml and sets its variables.
#
# If the environment variables already exist they are not overwritten.
# Setting these variables is useful for example _during_ a deployment, where the
# version of dkmlvars.sh in the filesystem is either pre-deployment (too old) or not present.
#
# Inputs:
# - env:DiskuvOCamlVarsVersion - optional
# - env:DiskuvOCamlHome - optional
# - env:DiskuvOCamlBinaryPaths - optional
# Outputs:
# - env:DKMLPARENTHOME
# - env:DiskuvOCamlVarsVersion - set if DiskuvOCaml installed
# - env:DiskuvOCamlHome - set if DiskuvOCaml installed
# - env:DiskuvOCamlBinaryPaths - set if DiskuvOCaml installed
# Exit Code:
# - 1 if DiskuvOCaml is not installed
autodetect_dkmlvars() {
    autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override=${DiskuvOCamlVarsVersion:-}
    autodetect_dkmlvars_DiskuvOCamlHome_Override=${DiskuvOCamlHome:-}
    autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override=${DiskuvOCamlBinaryPaths:-}
    set_dkmlparenthomedir
    if is_unixy_windows_build_machine; then
        if [ -e "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh" ]; then
            # shellcheck disable=SC1090
            . "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh"
        fi
    else
        if [ -e "$DKMLPARENTHOME_BUILDHOST/dkmlvars.sh" ]; then
            # shellcheck disable=SC1091
            . "$DKMLPARENTHOME_BUILDHOST/dkmlvars.sh"
        fi
    fi
    # Overrides
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override:-}" ]; then DiskuvOCamlVarsVersion="$autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlHome_Override:-}" ]; then DiskuvOCamlHome="$autodetect_dkmlvars_DiskuvOCamlHome_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override:-}" ]; then DiskuvOCamlBinaryPaths="$autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override"; fi
    # Check if any vars are still unset
    if [ -z "${DiskuvOCamlVarsVersion:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlHome:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlBinaryPaths:-}" ]; then return 1; fi
    return 0
}

# Inputs:
# - env:PLATFORM
# Outputs:
# - env:OPAMROOTDIR_BUILDHOST - The path to the Opam root directory that is usable only on the
#     build machine (not from within a container)
# - env:OPAMROOTDIR_EXPAND - The path to the Opam root directory switch that works as an
#     argument to `exec_in_platform`
# - env:DKMLPLUGIN_BUILDHOST - Plugin directory for config/installations connected to the Opam root
# - env:DKMLPLUGIN_EXPAND - The plugin directory that works as an argument to `exec_in_platform`
set_opamrootdir() {
    if is_dev_platform; then
        if is_unixy_windows_build_machine; then
            if [ -n "${OPAMROOT:-}" ]; then
                # If the developer sets OPAMROOT with an environment variable, then we will respect that
                # just like `opam` would do.
                OPAMROOTDIR_BUILDHOST="$OPAMROOT"
            else
                # Conform to https://github.com/ocaml/opam/pull/4815#issuecomment-910137754
                OPAMROOTDIR_BUILDHOST="${LOCALAPPDATA}\\opam"
            fi
            DKMLPLUGIN_BUILDHOST="$OPAMROOTDIR_BUILDHOST\\plugins\\diskuvocaml"
        else
            if [ -n "${OPAMROOT:-}" ]; then
                OPAMROOTDIR_BUILDHOST="$OPAMROOT"
            else
                # Conform to https://github.com/ocaml/opam/pull/4815#issuecomment-910137754
                OPAMROOTDIR_BUILDHOST="${XDG_CONFIG_HOME:-$HOME/.config}/opam"
            fi
            DKMLPLUGIN_BUILDHOST="$OPAMROOTDIR_BUILDHOST/plugins/diskuvocaml"
        fi
        OPAMROOTDIR_EXPAND="$OPAMROOTDIR_BUILDHOST"
    else
        # In a reproducible container ...
        OPAMROOTDIR_BUILDHOST="$OPAMROOT_IN_CONTAINER"
        # shellcheck disable=SC2034
        DKMLPLUGIN_BUILDHOST="$OPAMROOTDIR_BUILDHOST/plugins/diskuvocaml"
        # shellcheck disable=SC2034
        OPAMROOTDIR_EXPAND="@@EXPAND_TOPDIR@@/$OPAMROOTDIR_BUILDHOST"
    fi
    # shellcheck disable=SC2034
    DKMLPLUGIN_EXPAND="$OPAMROOTDIR_EXPAND/plugins/diskuvocaml"
}

# Select the 'diskuv-system' switch.
#
# Inputs:
# - env:DiskuvOCamlHome - Typically you get this from `autodetect_dkmlvars`
# Outputs:
# - env:OPAMSWITCHFINALDIR_BUILDHOST - Either:
#     The path to the switch that represents the build directory that is usable only on the
#     build machine (not from within a container). For an external (aka local) switch the returned path will be
#     a `.../_opam`` folder which is where the final contents of the switch live. Use OPAMSWITCHDIR_EXPAND
#     if you want an XXX argument for `opam --switch XXX` rather than this path which is not compatible.
# - env:OPAMSWITCHDIR_EXPAND - Either
#     The path to the switch **not including any _opam subfolder** that works as an argument to `exec_in_platform` -OR-
#     The name of a global switch that represents the build directory.
#     OPAMSWITCHDIR_EXPAND works inside or outside of a container.
set_opamswitchdir_of_system() {
    # Set OPAMSWITCHFINALDIR_BUILDHOST and OPAMSWITCHDIR_EXPAND
    # shellcheck disable=SC2034
    OPAMSWITCHFINALDIR_BUILDHOST="$DiskuvOCamlHome/system/_opam"
    # shellcheck disable=SC2034
    OPAMSWITCHDIR_EXPAND="@@EXPAND_WINDOWS_DISKUVOCAMLHOME@@/system"
}

# is_empty_opam_switch_present SWITCHDIR
#
# SWITCHDIR - Must be the `_opam/` subfolder if the switch is an external (aka local)
#    switch. Otherwise the switch is a global switch and must be the subfolder of
#    the Opam root directory (ex. ~/.opam) that has the same name as the global switch.
#
# Returns: True (0) if and only if the switch exists and is at least an `opam switch create --empty` switch.
#          False (1) otherwise.
is_empty_opam_switch_present() {
    is_empty_opam_switch_present_switchdir_buildhost=$1
    shift
    if [ -s "$is_empty_opam_switch_present_switchdir_buildhost/.opam-switch/switch-config" ]
    then
        return 0
    else
        return 1
    fi
}

# is_minimal_opam_switch_present SWITCHDIR
#
# SWITCHDIR - Must be the `_opam/` subfolder if the switch is an external (aka local)
#    switch. Otherwise the switch is a global switch and must be the subfolder of
#    the Opam root directory (ex. ~/.opam) that has the same name as the global switch.
#
# Returns: True (0) if and only if the switch exists and has at least an OCaml system compiler.
#          False (1) otherwise.
is_minimal_opam_switch_present() {
    is_minimal_opam_switch_present_switchdir_buildhost=$1
    shift
    if [ -e "$is_minimal_opam_switch_present_switchdir_buildhost/bin/ocamlc" ] || [ -e "$is_minimal_opam_switch_present_switchdir_buildhost/bin/ocamlc.exe" ]
    then
        return 0
    else
        return 1
    fi
}

# is_minimal_opam_root_present ROOTDIR
#
# ROOTDIR - The Opam root directory.
#
# Returns: True (0) if and only if the root exists and has an Opam configuration file.
#          False (1) otherwise.
is_minimal_opam_root_present() {
    is_minimal_opam_root_present_rootdir_buildhost=$1
    shift
    if [ -e "$is_minimal_opam_root_present_rootdir_buildhost/config" ]
    then
        return 0
    else
        return 1
    fi
}

# get_opam_switch_state_toplevelsection SWITCHDIR TOPLEVEL_SECTION_NAME
#
# Speedy way to grab sections from Opam. Opam is pretty speedy but
# `opam install utop` for example requires that `vcvars64.bat` is loaded
# on Windows which can take seconds.
#
# Inputs:
#
# SWITCHDIR - Must be the `_opam/` subfolder if the switch is an external (aka local)
#    switch. Otherwise the switch is a global switch and must be the subfolder of
#    the Opam root directory (ex. ~/.opam) that has the same name as the global switch.
# TOPLEVEL_SECTION_NAME - The name of the section. See Examples.
#
# Output: [stdout] The toplevel section of `switch-state` that
#   has the name TOPLEVEL_SECTION_NAME
#
# Examples:
#   If `~/_opam/.opam-switch/switch-state` contained:
#        compiler: ["ocaml-variants.4.12.0+msvc64+msys2"]
#        roots: [
#          "bigstringaf.0.8.0"
#          "digestif.1.0.1"
#          "dune-configurator.2.9.0"
#          "ocaml-lsp-server.1.8.2"
#          "ocaml-variants.4.12.0+msvc64+msys2"
#          "ocamlformat.0.18.0"
#          "ppx_expect.v0.14.1"
#          "utop.2.8.0"
#        ]
#   Then `get_opam_switch_state_toplevelsection ~/_opam compiler` would give:
#        compiler: ["ocaml-variants.4.12.0+msvc64+msys2"]
#   and `get_opam_switch_state_toplevelsection ~/_opam roots` would give:
#        roots: [
#          "bigstringaf.0.8.0"
#          "digestif.1.0.1"
#          "dune-configurator.2.9.0"
#          "ocaml-lsp-server.1.8.2"
#          "ocaml-variants.4.12.0+msvc64+msys2"
#          "ocamlformat.0.18.0"
#          "ppx_expect.v0.14.1"
#          "utop.2.8.0"
#        ]
get_opam_switch_state_toplevelsection() {
    get_opam_switch_state_toplevelsection_switchdir_buildhost=$1
    shift
    get_opam_switch_state_toplevelsection_toplevel_section_name=$1
    shift
    if [ ! -e "${get_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state" ]; then
        echo "FATAL: There is no Opam switch at ${get_opam_switch_state_toplevelsection_switchdir_buildhost}" >&2
        exit 71
    fi
    awk -v section="$get_opam_switch_state_toplevelsection_toplevel_section_name" \
        '$1 ~ ":" {state=0} $1==(section ":") {state=1} state==1{print}' \
        "${get_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state"
}

# delete_opam_switch_state_toplevelsection SWITCHDIR TOPLEVEL_SECTION_NAME
#
# Prints out the switch state with the specified toplevel section name removed.
# See get_opam_switch_state_toplevelsection for more details.
delete_opam_switch_state_toplevelsection() {
    delete_opam_switch_state_toplevelsection_switchdir_buildhost=$1
    shift
    delete_opam_switch_state_toplevelsection_toplevel_section_name=$1
    shift
    if [ ! -e "${delete_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state" ]; then
        echo "FATAL: There is no Opam switch at ${delete_opam_switch_state_toplevelsection_switchdir_buildhost}" >&2
        exit 71
    fi
    awk -v section="$delete_opam_switch_state_toplevelsection_toplevel_section_name" \
        '$1 ~ ":" {state=0} $1==(section ":") {state=1} state==0{print}' \
        "${delete_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state"
}

# [print_opam_logs_on_error CMD [ARGS...]] will execute `CMD [ARGS...]`. If the CMD fails _and_
# the environment variable `DKML_BUILD_PRINT_LOGS_ON_ERROR` is `ON` then print out Opam log files
# to the standard error.
print_opam_logs_on_error() {
    # save `set` state
    print_opam_logs_on_error_OLDSTATE=$(set +o)
    set +e # allow the next command to possibly fail
    "$@"
    print_opam_logs_on_error_EC=$?
    if [ "$print_opam_logs_on_error_EC" -ne 0 ]; then
        if [ "${DKML_BUILD_PRINT_LOGS_ON_ERROR:-}" = ON ]; then
            printf "\n\n========= [START OF TROUBLESHOOTING] ===========\n\n" >&2

            # print _one_ of the environment
            # shellcheck disable=SC2030
            find "$OPAMROOTDIR_BUILDHOST"/log -mindepth 1 -maxdepth 1 -name "*.env" ! -name "log-*.env" ! -name "ocaml-variants-*.env" | head -n1 | while read -r dump_on_error_LOG; do
                # shellcheck disable=SC2031
                dump_on_error_BLOG=$(basename "$dump_on_error_LOG")
                printf "\n\n========= [TROUBLESHOOTING] %s ===========\n# To save space, this is only one of the many similar Opam environment files that have been printed.\n\n" "$dump_on_error_BLOG" >&2
                cat "$dump_on_error_LOG" >&2
            done

            # print all output files (except ocaml-variants)
            find "$OPAMROOTDIR_BUILDHOST"/log -mindepth 1 -maxdepth 1 -name "*.out" ! -name "log-*.out" ! -name "ocaml-variants-*.out" | while read -r dump_on_error_LOG; do
                dump_on_error_BLOG=$(basename "$dump_on_error_LOG")
                printf "\n\n========= [TROUBLESHOOTING] %s ===========\n\n" "$dump_on_error_BLOG" >&2
                cat "$dump_on_error_LOG" >&2
            done

            # TODO: we could add other logs files from the switch, like
            # `$env:LOCALAPPDATA\Programs\DiskuvOCaml\0\system\_opam\.opam-switch\build\ocamlfind.1.9.1\ocargs.log`

            printf "The command %s failed with exit code $print_opam_logs_on_error_EC. Scroll up to see the [TROUBLESHOOTING] logs that begin at the [START OF TROUBLESHOOTING] line\n" "$*" >&2
        fi

        exit $print_opam_logs_on_error_EC
    fi
    # restore old state
    eval "$print_opam_logs_on_error_OLDSTATE"
}
