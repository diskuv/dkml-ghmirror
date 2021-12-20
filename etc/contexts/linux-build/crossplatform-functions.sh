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
######################################
# crossplatform-functions.sh
#
# Meant to be `source`-d.
#
# Can be run within a container or outside of a container.
#

export SHARE_OCAML_OPAM_REPO_RELPATH=share/dkml/repro
export SHARE_REPRODUCIBLE_BUILD_RELPATH=share/dkml/repro
export SHARE_FUNCTIONS_RELPATH=share/dkml/functions

# Prefer dash if it is there because it is average 4x faster than bash and should
# be much more secure. Otherwise /bin/sh which should always be a POSIX
# compatible shell.
#
# Output:
#   - env:DKML_POSIX_SHELL - The path to the POSIX shell. Only set if it wasn't already
#     set.
#   - env:DKML_HOST_POSIX_SHELL - The host's path to the POSIX shell. Only set if it wasn't already
#     set. On a Windows host (Cygwin/MSYS2) this will be a Windows path; on Unix this will be a Unix
#     path.
# References:
#   - https://unix.stackexchange.com/questions/148035/is-dash-or-some-other-shell-faster-than-bash
autodetect_posix_shell() {
    export DKML_POSIX_SHELL
    export DKML_HOST_POSIX_SHELL
    if [ -n "${DKML_POSIX_SHELL:-}" ] && [ -n "${DKML_HOST_POSIX_SHELL}" ]; then
        return
    # On MSYS2 especially, binaries look like they exist simultaneously in /usr/bin and /bin but
    # only if you are inside MSYS2. The binaries in /bin are in fact a mount of /usr/bin.
    # This is a critical problem for `opam exec -- /bin/dash.exe` which will fail because Opam cannot
    # see the mount.
    elif [ -e /usr/bin/dash.exe ]; then
        DKML_POSIX_SHELL=/usr/bin/dash.exe
    elif [ -e /usr/bin/dash ]; then
        DKML_POSIX_SHELL=/usr/bin/dash
    elif [ -e /bin/dash.exe ]; then
        DKML_POSIX_SHELL=/bin/dash.exe
    elif [ -e /bin/dash ]; then
        DKML_POSIX_SHELL=/bin/dash
    elif [ -e /bin/sh.exe ]; then
        DKML_POSIX_SHELL=/bin/sh.exe
    else
        DKML_POSIX_SHELL=/bin/sh
    fi
    if [ -x /usr/bin/cygpath ]; then
        DKML_HOST_POSIX_SHELL=$(/usr/bin/cygpath -aw "$DKML_POSIX_SHELL")
    else
        DKML_HOST_POSIX_SHELL="$DKML_POSIX_SHELL"
    fi
}

# Set the parent directory of DiskuvOCamlHome.
#
# Always defined, even on Unix. It is your responsibility to check if it exists.
#
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
set_dkmlparenthomedir() {
    if [ -n "${LOCALAPPDATA:-}" ]; then
        DKMLPARENTHOME_BUILDHOST="$LOCALAPPDATA\\Programs\\DiskuvOCaml"
    else
        # shellcheck disable=SC2034
        DKMLPARENTHOME_BUILDHOST="${XDG_DATA_HOME:-$HOME/.local/share}/diskuv-ocaml"
    fi
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
# - env:DiskuvOCamlDeploymentId - optional
# - env:DiskuvOCamlVersion - optional
# - env:DiskuvOCamlMSYS2Dir - optional
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:DKMLHOME_BUILDHOST - set if DiskuvOCaml installed. Path will be in Windows (semicolon separated) or Unix (colon separated) format
# - env:DKMLHOME_UNIX - set if DiskuvOCaml installed. Path will be in Unix (colon separated) format
# - env:DKMLBINPATHS_BUILDHOST - set if DiskuvOCaml installed. Paths will be in Windows (semicolon separated) or Unix (colon separated) format
# - env:DKMLBINPATHS_UNIX - set if DiskuvOCaml installed. Paths will be in Unix (colon separated) format
# Exit Code:
# - 1 if DiskuvOCaml is not installed
autodetect_dkmlvars() {
    autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override=${DiskuvOCamlVarsVersion:-}
    autodetect_dkmlvars_DiskuvOCamlHome_Override=${DiskuvOCamlHome:-}
    autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override=${DiskuvOCamlBinaryPaths:-}
    autodetect_dkmlvars_DiskuvOCamlDeploymentId_Override=${DiskuvOCamlDeploymentId:-}
    autodetect_dkmlvars_DiskuvOCamlVersion_Override=${DiskuvOCamlVersion:-}
    autodetect_dkmlvars_DiskuvOCamlMSYS2Dir_Override=${DiskuvOCamlMSYS2Dir:-}

    set_dkmlparenthomedir

    # Init output vars
    DKMLHOME_UNIX=
    DKMLHOME_BUILDHOST=
    DKMLBINPATHS_UNIX=
    DKMLBINPATHS_BUILDHOST=

    if is_unixy_windows_build_machine; then
        if [ -e "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh" ]; then
            if [ -x /usr/bin/cygpath ]; then
                autodetect_dkmlvars_VARSSCRIPT=$(/usr/bin/cygpath -a "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh")
                # shellcheck disable=SC1090
                . "$autodetect_dkmlvars_VARSSCRIPT"
            else
                # shellcheck disable=SC1090
                . "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh"
            fi
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
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlDeploymentId_Override:-}" ]; then DiskuvOCamlDeploymentId="$autodetect_dkmlvars_DiskuvOCamlDeploymentId_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlVersion_Override:-}" ]; then DiskuvOCamlVersion="$autodetect_dkmlvars_DiskuvOCamlVersion_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlMSYS2Dir_Override:-}" ]; then DiskuvOCamlMSYS2Dir="$autodetect_dkmlvars_DiskuvOCamlMSYS2Dir_Override"; fi
    # Check if any vars are still unset
    if [ -z "${DiskuvOCamlVarsVersion:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlHome:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlBinaryPaths:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlDeploymentId:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlVersion:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlMSYS2Dir:-}" ]; then return 1; fi

    # Validate DiskuvOCamlVarsVersion. Can be v1 or v2 since only the .sexp file changed in v2.
    if [ ! "$DiskuvOCamlVarsVersion" = "1" ] && [ ! "$DiskuvOCamlVarsVersion" = "2" ]; then
        printf "FATAL: Only able to read Diskuv OCaml variables version '1' and '2'. Instead Diskuv OCaml variables for %s were on version '%s'\n" "$DiskuvOCamlHome" "$DiskuvOCamlVarsVersion" >&2
        exit 107
    fi

    # Unixize DiskuvOCamlHome
    if [ -x /usr/bin/cygpath ]; then
        DKMLHOME_UNIX=$(/usr/bin/cygpath -au "$DiskuvOCamlHome")
        DKMLHOME_BUILDHOST=$(/usr/bin/cygpath -aw "$DiskuvOCamlHome")
    else
        DKMLHOME_UNIX="$DiskuvOCamlHome"
        # shellcheck disable=SC2034
        DKMLHOME_BUILDHOST="$DiskuvOCamlHome"
    fi

    # Pathize DiskuvOCamlBinaryPaths
    if [ -x /usr/bin/cygpath ]; then
        # Going from Windows to Unix is safe. Going from Unix to Windows is safe.
        # But Windows to Windows has garbled output from cygpath.
        DKMLBINPATHS_UNIX=$(/usr/bin/cygpath --path "$DiskuvOCamlBinaryPaths")
        DKMLBINPATHS_BUILDHOST=$(/usr/bin/cygpath -w --path "$DKMLBINPATHS_UNIX")
    else
        DKMLBINPATHS_UNIX="$DiskuvOCamlBinaryPaths"
        # shellcheck disable=SC2034
        DKMLBINPATHS_BUILDHOST="$DiskuvOCamlBinaryPaths"
    fi

    return 0
}

# Set OCAMLHOME and OPAMHOME if part of DKML system installation.
autodetect_ocaml_and_opam_home() {
    # Set DKMLHOME_UNIX
    autodetect_dkmlvars || true

    # Set OCAMLHOME and OPAMHOME from DKMLHOME
    OCAMLHOME=
    OPAMHOME=
    if [ -n "$DKMLHOME_UNIX" ]; then
        if [ -x "$DKMLHOME_UNIX/usr/bin/ocaml" ] || [ -x "$DKMLHOME_UNIX/usr/bin/ocaml.exe" ]; then
            OCAMLHOME=$DKMLHOME_UNIX
        elif [ -x "$DKMLHOME_UNIX/bin/ocaml" ] || [ -x "$DKMLHOME_UNIX/bin/ocaml.exe" ]; then
            # shellcheck disable=SC2034
            OCAMLHOME=$DKMLHOME_UNIX
        fi
        if [ -x "$DKMLHOME_UNIX/usr/bin/opam" ] || [ -x "$DKMLHOME_UNIX/usr/bin/opam.exe" ]; then
            OPAMHOME=$DKMLHOME_UNIX
        elif [ -x "$DKMLHOME_UNIX/bin/opam" ] || [ -x "$DKMLHOME_UNIX/bin/opam.exe" ]; then
            # shellcheck disable=SC2034
            OPAMHOME=$DKMLHOME_UNIX
        fi
    fi
}

# Get a path that has system binaries, and nothing else.
#
# Purpose: Use whenever you have something meant to be reproducible.
#
# On Windows this includes the Cygwin/MSYS2 paths, the  but also Windows directories
# like C:\Windows\System32 and C:\Windows\System32\OpenSSH and Powershell directories and
# also the essential binaries in $env:DiskuvOCamlHome\bin. The general binaries in $env:DiskuvOCamlHome\usr\bin are not
# included.
#
# Output:
#   env:DKML_SYSTEM_PATH - A PATH containing only system directories like /usr/bin.
#      The path will be in Unix format (so a path on Windows MSYS2 could be /c/Windows/System32)
autodetect_system_path() {
    export DKML_SYSTEM_PATH
    if [ -x /usr/bin/cygpath ]; then
        autodetect_system_path_SYSDIR=$(/usr/bin/cygpath --sysdir)
        autodetect_system_path_WINDIR=$(/usr/bin/cygpath --windir)
        # folder 38 = C:\Program Files typically
        autodetect_system_path_PROGRAMFILES=$(/usr/bin/cygpath --folder 38)
    fi

    if is_cygwin_build_machine; then
        DKML_SYSTEM_PATH=/usr/bin:/bin:$autodetect_system_path_PROGRAMFILES/PowerShell/7:$autodetect_system_path_SYSDIR:$autodetect_system_path_WINDIR:$autodetect_system_path_SYSDIR/Wbem:$autodetect_system_path_SYSDIR/WindowsPowerShell/v1.0:$autodetect_system_path_SYSDIR/OpenSSH
    elif is_msys2_msys_build_machine; then
        # /bin is a mount (essentially a symlink) to /usr/bin on MSYS2
        DKML_SYSTEM_PATH=/usr/bin:$autodetect_system_path_PROGRAMFILES/PowerShell/7:$autodetect_system_path_SYSDIR:$autodetect_system_path_WINDIR:$autodetect_system_path_SYSDIR/Wbem:$autodetect_system_path_SYSDIR/WindowsPowerShell/v1.0:$autodetect_system_path_SYSDIR/OpenSSH
    else
        DKML_SYSTEM_PATH=/usr/bin:/bin
    fi

    # Set DKMLHOME_UNIX if available
    autodetect_dkmlvars || true

    # Add Git at beginning of PATH
    autodetect_system_path_GITEXE=$(command -v git || true)
    if [ -n "$autodetect_system_path_GITEXE" ]; then
        autodetect_system_path_GITDIR=$(PATH=/usr/bin:/bin dirname "$autodetect_system_path_GITEXE")
        case "$autodetect_system_path_GITDIR" in
            /usr/bin|/bin) ;;
            *) DKML_SYSTEM_PATH="$autodetect_system_path_GITDIR:$DKML_SYSTEM_PATH"
        esac
    fi

    # Add $DKMLHOME_UNIX/bin at beginning of PATH
    if [ -n "${DKMLHOME_UNIX:-}" ] && [ -d "$DKMLHOME_UNIX/bin" ]; then
        DKML_SYSTEM_PATH="$DKMLHOME_UNIX/bin:$DKML_SYSTEM_PATH"
    fi
}

# Get standard locations of Unix system binaries like `/usr/bin/mv` (or `/bin/mv`).
#
# Will not return anything in `/usr/local/bin` or `/usr/sbin`. Use when you do not
# know whether the PATH has been set correctly, or when you do not know if the
# system binary exists.
#
# At some point in the future, this function will error out if the required system binaries
# do not exist. Most system binaries are common to all Unix/Linux/macOS installations but
# some (like `comm`) may need to be installed for proper functioning of DKML.
#
# Outputs:
# - env:DKMLSYS_MV - Location of `mv`
# - env:DKMLSYS_CHMOD - Location of `chmod`
# - env:DKMLSYS_UNAME - Location of `uname`
# - env:DKMLSYS_ENV - Location of `env`
# - env:DKMLSYS_AWK - Location of `awk`
# - env:DKMLSYS_SED - Location of `sed`
# - env:DKMLSYS_COMM - Location of `comm`
# - env:DKMLSYS_INSTALL - Location of `install`
# - env:DKMLSYS_RM - Location of `rm`
# - env:DKMLSYS_SORT - Location of `sort`
# - env:DKMLSYS_CAT - Location of `cat`
# - env:DKMLSYS_STAT - Location of `stat`
# - env:DKMLSYS_GREP - Location of `grep`
# - env:DKMLSYS_CURL - Location of `curl`
autodetect_system_binaries() {
    if [ -z "${DKMLSYS_MV:-}" ]; then
        if [ -x /usr/bin/mv ]; then
            DKMLSYS_MV=/usr/bin/mv
        else
            DKMLSYS_MV=/bin/mv
        fi
    fi
    if [ -z "${DKMLSYS_CHMOD:-}" ]; then
        if [ -x /usr/bin/chmod ]; then
            DKMLSYS_CHMOD=/usr/bin/chmod
        else
            DKMLSYS_CHMOD=/bin/chmod
        fi
    fi
    if [ -z "${DKMLSYS_UNAME:-}" ]; then
        if [ -x /usr/bin/uname ]; then
            DKMLSYS_UNAME=/usr/bin/uname
        else
            DKMLSYS_UNAME=/bin/uname
        fi
    fi
    if [ -z "${DKMLSYS_ENV:-}" ]; then
        if [ -x /usr/bin/env ]; then
            DKMLSYS_ENV=/usr/bin/env
        else
            DKMLSYS_ENV=/bin/env
        fi
    fi
    if [ -z "${DKMLSYS_AWK:-}" ]; then
        if [ -x /usr/bin/awk ]; then
            DKMLSYS_AWK=/usr/bin/awk
        else
            DKMLSYS_AWK=/bin/awk
        fi
    fi
    if [ -z "${DKMLSYS_SED:-}" ]; then
        if [ -x /usr/bin/sed ]; then
            DKMLSYS_SED=/usr/bin/sed
        else
            DKMLSYS_SED=/bin/sed
        fi
    fi
    if [ -z "${DKMLSYS_COMM:-}" ]; then
        if [ -x /usr/bin/comm ]; then
            DKMLSYS_COMM=/usr/bin/comm
        else
            DKMLSYS_COMM=/bin/comm
        fi
    fi
    if [ -z "${DKMLSYS_INSTALL:-}" ]; then
        if [ -x /usr/bin/install ]; then
            DKMLSYS_INSTALL=/usr/bin/install
        else
            DKMLSYS_INSTALL=/bin/install
        fi
    fi
    if [ -z "${DKMLSYS_RM:-}" ]; then
        if [ -x /usr/bin/rm ]; then
            DKMLSYS_RM=/usr/bin/rm
        else
            DKMLSYS_RM=/bin/rm
        fi
    fi
    if [ -z "${DKMLSYS_SORT:-}" ]; then
        if [ -x /usr/bin/sort ]; then
            DKMLSYS_SORT=/usr/bin/sort
        else
            DKMLSYS_SORT=/bin/sort
        fi
    fi
    if [ -z "${DKMLSYS_CAT:-}" ]; then
        if [ -x /usr/bin/cat ]; then
            DKMLSYS_CAT=/usr/bin/cat
        else
            DKMLSYS_CAT=/bin/cat
        fi
    fi
    if [ -z "${DKMLSYS_STAT:-}" ]; then
        if [ -x /usr/bin/stat ]; then
            DKMLSYS_STAT=/usr/bin/stat
        else
            DKMLSYS_STAT=/bin/stat
        fi
    fi
    if [ -z "${DKMLSYS_GREP:-}" ]; then
        if [ -x /usr/bin/grep ]; then
            DKMLSYS_GREP=/usr/bin/grep
        else
            DKMLSYS_GREP=/bin/grep
        fi
    fi
    if [ -z "${DKMLSYS_CURL:-}" ]; then
        if [ -x /usr/bin/curl ]; then
            DKMLSYS_CURL=/usr/bin/curl
        else
            DKMLSYS_CURL=/bin/curl
        fi
    fi
    export DKMLSYS_MV DKMLSYS_CHMOD DKMLSYS_UNAME DKMLSYS_ENV DKMLSYS_AWK DKMLSYS_SED DKMLSYS_COMM DKMLSYS_INSTALL
    export DKMLSYS_RM DKMLSYS_SORT DKMLSYS_CAT DKMLSYS_STAT DKMLSYS_GREP DKMLSYS_CURL
}

# Is a Windows build machine if we are in a MSYS2 or Cygwin environment.
#
# Better alternatives
# -------------------
#
# 1. If you are checking to see if you should do a cygpath, then just guard it
#    like so:
#       if [ -x /usr/bin/cygpath ]; then
#           do_something $(/usr/bin/cygpath ...) ...
#       fi
#    This clearly guards what you are about to do (cygpath) with what you will
#    need (cygpath).
# 2. is_arg_windows_platform
is_unixy_windows_build_machine() {
    if is_msys2_msys_build_machine || is_cygwin_build_machine; then
        return 0
    fi
    return 1
}

# Is a MSYS2 environment with the MSYS subsystem? (MSYS2 can also do MinGW 32-bit
# and 64-bit subsystems)
is_msys2_msys_build_machine() {
    if [ -e /usr/bin/msys-2.0.dll ] && [ "${MSYSTEM:-}" = "MSYS" ]; then
        return 0
    fi
    return 1
}

is_cygwin_build_machine() {
    if [ -e /usr/bin/cygwin1.dll ]; then
        return 0
    fi
    return 1
}

# Inputs:
# - $1 - The PLATFORM
is_arg_windows_platform() {
    case "$1" in
        windows_x86)    return 0;;
        windows_x86_64) return 0;;
        windows_arm32)  return 0;;
        windows_arm64)  return 0;;
        dev)            if is_unixy_windows_build_machine; then return 0; else return 1; fi ;;
        *)              return 1;;
    esac
}

# Linux and Android are Linux based platforms
# Inputs:
# - $1 - The PLATFORM
# Outputs:
# - BUILDHOST_ARCH
is_arg_linux_based_platform() {
    autodetect_buildhost_arch
    case "$1" in
        linux_*)    return 0;;
        android_*)  return 0;;
        dev)
            case "$BUILDHOST_ARCH" in
                linux_*)    return 0;;
                android_*)  return 0;;
                *)          return 1;;
            esac
            ;;
        *)          return 1;;
    esac
}

# macOS and iOS are Darwin based platforms
# Inputs:
# - $1 - The PLATFORM
# Outputs:
# - BUILDHOST_ARCH
is_arg_darwin_based_platform() {
    autodetect_buildhost_arch
    case "$1" in
        darwin_*)  return 0;;
        dev)
            case "$BUILDHOST_ARCH" in
                darwin_*)  return 0;;
                *)         return 1;;
            esac
            ;;
        *)          return 1;;
    esac
}

# Install files that will always be in a reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
install_reproducible_common() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_common_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$install_reproducible_common_BOOTSTRAPDIR"
    install_reproducible_file .dkmlroot
    install_reproducible_file installtime/none/emptytop/dune-project
    install_reproducible_file etc/contexts/linux-build/crossplatform-functions.sh
    install_reproducible_file runtime/unix/_common_tool.sh
}

# Install any non-common files that go into your reproducible build.
# All installed files will have the executable bit set.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the script that will be installed.
#       It will be deployed relative to $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
install_reproducible_file() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    _install_reproducible_file_RELFILE="$1"
    shift
    _install_reproducible_file_RELDIR=$(dirname "$_install_reproducible_file_RELFILE")
    _install_reproducible_file_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
    # When we rerun a setup script from within
    # the reproducible target directory we may be installing on top of ourselves; that is, installing with
    # the source and destination files being the same file.
    # shellcheck disable=SC3013
    if [ /dev/null -ef /dev/null ] 2>/dev/null; then
        # This script accepts the -ef operator
        if [ ! "$DKMLDIR"/"$_install_reproducible_file_RELFILE" -ef "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELFILE" ]; then
            "$DKMLSYS_INSTALL" "$DKMLDIR"/"$_install_reproducible_file_RELFILE" "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
        fi
    else
        # Sigh; portable scripts are not required to have a [ f1 -ef f2 ] operator. So we compare inodes (assuming `stat` supports `-c`)
        install_reproducible_file_STAT1=$("$DKMLSYS_STAT" -c '%i' "$DKMLDIR"/"$_install_reproducible_file_RELFILE")
        if [ -e "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELFILE" ]; then
            install_reproducible_file_STAT2=$("$DKMLSYS_STAT" -c '%i' "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELFILE")
        else
            install_reproducible_file_STAT2=
        fi
        if [ ! "$install_reproducible_file_STAT1" = "$install_reproducible_file_STAT2" ]; then
            "$DKMLSYS_INSTALL" "$DKMLDIR"/"$_install_reproducible_file_RELFILE" "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
        fi
    fi
}

# Install any deterministically generated files that go into your
# reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path to the generated script.
#  $2 - The location of the script that will be installed.
#       It must be specified relative to $DEPLOYDIR_UNIX.
install_reproducible_generated_file() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_generated_file_SRCFILE="$1"
    shift
    install_reproducible_generated_file_RELFILE="$1"
    shift
    install_reproducible_generated_file_RELDIR=$(dirname "$install_reproducible_generated_file_RELFILE")
    install_reproducible_generated_file_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELDIR"/
    "$DKMLSYS_RM" -f "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELFILE" # ensure if exists it is a regular file or link but not a directory
    "$DKMLSYS_INSTALL" "$install_reproducible_generated_file_SRCFILE" "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELFILE"
}

# Install a README.md file that go into your reproducible build.
#
# The @@BOOTSTRAPDIR_UNIX@@ is a macro you can use inside the Markdown file
# which will be replaced with the relative path to the BOOTSTRAPNAME folder;
# it will have a trailing slash.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the .md file that will be installed.
#       It will be deployed as 'README.md' in the bootstrap folder of $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
install_reproducible_readme() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_readme_RELFILE="$1"
    shift
    install_reproducible_readme_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$install_reproducible_readme_BOOTSTRAPDIR"
    "$DKMLSYS_SED" "s,@@BOOTSTRAPDIR_UNIX@@,$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME/,g" "$DKMLDIR"/"$install_reproducible_readme_RELFILE" > "$install_reproducible_readme_BOOTSTRAPDIR"/README.md
}

# Changes the suffix of a string and print to the standard output.
# change_suffix TEXT OLD_SUFFIX NEW_SUFFIX
#
# This function can handle old and suffixes containing:
# * A-Za-z0-9
# * commas (,)
# * dashes (-)
# * underscores (_)
# * periods (.)
# * ampersands (@)
#
# Other characters may work, but they are not officially supported by this function.
change_suffix() {
    change_suffix_TEXT="$1"
    shift
    change_suffix_OLD_SUFFIX="$1"
    shift
    change_suffix_NEW_SUFFIX="$1"
    shift

    # Set DKMLSYS_*
    autodetect_system_binaries

    printf "%s" "$change_suffix_TEXT" | "$DKMLSYS_AWK" -v REPLACE="$change_suffix_NEW_SUFFIX" "{ gsub(/$change_suffix_OLD_SUFFIX/,REPLACE); print }"
}

# Replaces all occurrences of the search term with a replacement string, and print to the standard output.
# replace_all TEXT SEARCH REPLACE
#
# This function can handle SEARCH text containing:
# * A-Za-z0-9
# * commas (,)
# * dashes (-)
# * underscores (_)
# * periods (.)
# * ampersands (@)
#
# Other characters may work, but they are not officially supported by this function.
#
# Any characters can be used in TEXT and REPLACE.
replace_all() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    replace_all_TEXT="$1"
    shift
    replace_all_SEARCH="$1"
    shift
    replace_all_REPLACE="$1"
    shift
    replace_all_REPLACE=$(printf "%s" "$replace_all_REPLACE" | "$DKMLSYS_SED" 's#\\#\\\\#g') # escape all backslashes for awk

    printf "%s" "$replace_all_TEXT" | "$DKMLSYS_AWK" -v REPLACE="$replace_all_REPLACE" "{ gsub(/$replace_all_SEARCH/,REPLACE); print }"
}

# Install a script that can re-install necessary system packages.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the script that will be created, relative to $DEPLOYDIR_UNIX.
#       Must end with `.sh`.
#  $@ - All remaining arguments are how to invoke the run script ($1).
install_reproducible_system_packages() {
    # Set DKMLSYS_*
    autodetect_system_binaries
    # Set BUILDHOST_ARCH
    autodetect_buildhost_arch

    install_reproducible_system_packages_SCRIPTFILE="$1"
    shift
    install_reproducible_system_packages_PACKAGEFILE=$(change_suffix "$install_reproducible_system_packages_SCRIPTFILE" .sh .packagelist.txt)
    if [ "$install_reproducible_system_packages_PACKAGEFILE" = "$install_reproducible_system_packages_SCRIPTFILE" ]; then
        printf "%s" "FATAL: The run script $install_reproducible_system_packages_SCRIPTFILE must end with .sh" >&2
        exit 1
    fi
    install_reproducible_system_packages_SCRIPTDIR=$(dirname "$install_reproducible_system_packages_SCRIPTFILE")
    install_reproducible_system_packages_BOOTSTRAPRELDIR=$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install_reproducible_system_packages_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$install_reproducible_system_packages_BOOTSTRAPRELDIR
    "$DKMLSYS_INSTALL" -d "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTDIR"/

    if is_msys2_msys_build_machine; then
        # https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#List_of_installed_packages
        pacman -Qqet > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        printf "#!/bin/sh\nexec pacman -S \"\$@\" --needed - < '%s'\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE" > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif is_cygwin_build_machine; then
        cygcheck.exe -c -d > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            printf "%s\n" "#!/bin/sh"
            printf "%s\n" "if [ ! -e /usr/local/bin/cyg-get ]; then wget -O /usr/local/bin/cyg-get 'https://gitlab.com/cogline.v3/cygwin/-/raw/2049faf4b565af81937d952292f8ae5008d38765/cyg-get?inline=false'; fi"
            printf "%s\n" "if [ ! -x /usr/local/bin/cyg-get ]; then chmod +x /usr/local/bin/cyg-get; fi"
            printf "readarray -t pkgs < <(awk 'display==1{print \$1} \$1==\"Package\"{display=1}' '%s')\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE"
            # shellcheck disable=SC2016
            printf "%s\n" 'set -x ; /usr/local/bin/cyg-get install ${pkgs[@]}'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif is_arg_darwin_based_platform "$BUILDHOST_ARCH"; then
        # Use a Brewfile.lock.json as the package manifest.
        # However, when `brew` is not available (ex. Xcode runs CMake with a PATH that excludes homebrew) it is likely
        # that no brew installed packages are available either. So if CMake succeeds then no brew commands were needed!
        if command -v brew >/dev/null; then
            # Brew exists and its installed packages can be used in the rest of the reproducible scripts.
            install_reproducible_system_packages_OLDDIR=$PWD
            if ! cd "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTDIR"; then echo "FATAL: Could not cd to script directory" >&2; exit 107; fi
            brew bundle dump --force # creates a Brewfile in current directory
            if ! cd "$install_reproducible_system_packages_OLDDIR"; then echo "FATAL: Could not cd to old directory" >&2; exit 107; fi
            $DKMLSYS_MV \
                "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTDIR"/Brewfile \
                "$install_reproducible_system_packages_BOOTSTRAPDIR/$install_reproducible_system_packages_PACKAGEFILE"

            {
                printf "%s\n" "#!/bin/sh"
                printf "set -x ; brew bundle install --file '%s'\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE"
            } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        else
            # Brew and its installed packages are not available in the rest of the reproducible scripts.
            {
                printf "%s\n" "#!/bin/sh"
                printf "# Brew was not used so nothing to install\n"
                printf "true\n"
            } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        fi
    else
        printf "%s\n" "TODO: install_reproducible_system_packages for non-Windows platforms" >&2
        exit 1
    fi
    "$DKMLSYS_CHMOD" 755 "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
}

# Install a script that can relaunch itself in a relocated position.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the pre-existing script that should be run.
#       It will be deployed relative to $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
#       Must end with `.sh`.
#  $@ - All remaining arguments are how to invoke the run script ($1).
install_reproducible_script_with_args() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_script_with_args_SCRIPTFILE="$1"
    shift
    install_reproducible_script_with_args_RECREATEFILE=$(change_suffix "$install_reproducible_script_with_args_SCRIPTFILE" .sh -noargs.sh)
    if [ "$install_reproducible_script_with_args_RECREATEFILE" = "$install_reproducible_script_with_args_SCRIPTFILE" ]; then
        printf "%s\n" "FATAL: The run script $install_reproducible_script_with_args_SCRIPTFILE must end with .sh" >&2
        exit 1
    fi
    install_reproducible_script_with_args_RECREATEDIR=$(dirname "$install_reproducible_script_with_args_SCRIPTFILE")
    install_reproducible_script_with_args_BOOTSTRAPRELDIR=$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install_reproducible_script_with_args_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$install_reproducible_script_with_args_BOOTSTRAPRELDIR

    install_reproducible_file "$install_reproducible_script_with_args_SCRIPTFILE"
    "$DKMLSYS_INSTALL" -d "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEDIR"/
    {
        printf "#!/bin/sh\nexec env TOPDIR=\"\$PWD/%s/installtime/none/emptytop\" %s " \
            "$install_reproducible_script_with_args_BOOTSTRAPRELDIR" \
            "$install_reproducible_script_with_args_BOOTSTRAPRELDIR/$install_reproducible_script_with_args_SCRIPTFILE"
        escape_args_for_shell "$@"
        printf "\n"
    } > "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEFILE"
    "$DKMLSYS_CHMOD" 755 "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEFILE"
}

# Tries to find the ARCH (defined in TOPDIR/Makefile corresponding to the build machine).
# ARCH is also called the PLATFORM.
# For now only tested in Linux/Windows x86/x86_64 and Apple x86_64/arm64.
#
# This function uses `uname` probing which sometimes is often inaccurate
# during cross-compilation.
#
# Outputs:
# - env:BUILDHOST_ARCH will contain the correct ARCH
autodetect_buildhost_arch() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    autodetect_buildhost_arch_MACHINE=$("$DKMLSYS_UNAME" -m)
    autodetect_buildhost_arch_SYSTEM=$("$DKMLSYS_UNAME" -s)
    # list from https://en.wikipedia.org/wiki/Uname and https://stackoverflow.com/questions/45125516/possible-values-for-uname-m
    case "${autodetect_buildhost_arch_SYSTEM}-${autodetect_buildhost_arch_MACHINE}" in
        Linux-armv7*)
            BUILDHOST_ARCH=linux_arm32v7;;
        Linux-armv6* | Linux-arm)
            BUILDHOST_ARCH=linux_arm32v6;;
        Linux-aarch64 | Linux-arm64 | Linux-armv8*)
            BUILDHOST_ARCH=linux_arm64;;
        Linux-i386 | Linux-i686)
            BUILDHOST_ARCH=linux_x86;;
        Linux-x86_64)
            BUILDHOST_ARCH=linux_x86_64;;
        Darwin-arm64)
            BUILDHOST_ARCH=darwin_arm64;;
        Darwin-x86_64)
            BUILDHOST_ARCH=darwin_x86_64;;
        *-i386 | *-i686)
            if is_unixy_windows_build_machine; then
                BUILDHOST_ARCH=windows_x86
            else
                printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $autodetect_buildhost_arch_SYSTEM and $autodetect_buildhost_arch_MACHINE" >&2
                exit 1
            fi
            ;;
        *-x86_64)
            if is_unixy_windows_build_machine; then
                BUILDHOST_ARCH=windows_x86_64
            else
                printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $autodetect_buildhost_arch_SYSTEM and $autodetect_buildhost_arch_MACHINE" >&2
                exit 1
            fi
            ;;
        *)
            # Since:
            # 1) MSYS2 does not run on ARM/ARM64 (https://www.msys2.org/docs/environments/)
            # 2) MSVC does not use ARM/ARM64 as host machine (https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-160)
            # we do not support Windows ARM/ARM64 as a build machine
            printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $autodetect_buildhost_arch_SYSTEM and $autodetect_buildhost_arch_MACHINE" >&2
            exit 1
            ;;
    esac
}

# (Deprecated) Tries to find the VCPKG_TRIPLET (defined in TOPDIR/Makefile corresponding to the build machine)
# For now only tested in Linux/Windows x86/x86_64.
# Inputs:
# - env:PLATFORM
# Outputs:
# - env:BUILDHOST_ARCH will contain the correct ARCH
# - env:DKML_VCPKG_HOST_TRIPLET will contain the correct vcpkg triplet
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
platform_vcpkg_triplet() {
    autodetect_buildhost_arch
    export DKML_VCPKG_HOST_TRIPLET
    # TODO: This static list is brittle. Should parse the Makefile or better yet
    # place in a different file that can be used by this script and the Makefile.
    # In fact, the list we should be using is base.mk:VCPKG_TRIPLET_*
    case "$PLATFORM-$BUILDHOST_ARCH" in
        dev-windows_x86)      DKML_VCPKG_HOST_TRIPLET=x86-windows ;;
        dev-windows_x86_64)   DKML_VCPKG_HOST_TRIPLET=x64-windows ;;
        dev-windows_arm32)    DKML_VCPKG_HOST_TRIPLET=arm-windows ;;
        dev-windows_arm64)    DKML_VCPKG_HOST_TRIPLET=arm64-windows ;;
        dev-linux_x86)        DKML_VCPKG_HOST_TRIPLET=x86-linux ;;
        dev-linux_x86_64)     DKML_VCPKG_HOST_TRIPLET=x64-linux ;;
        # See base.mk:DKML_PLATFORMS for why OS/X triplet is chosen rather than iOS (which would be dev-darwin_arm64_iosdevice)
        # Caution: arm64-osx and arm64-ios triplets are Community supported. https://github.com/microsoft/vcpkg/tree/master/triplets/community
        # and https://github.com/microsoft/vcpkg/issues/12258 .
        dev-darwin_arm64)     DKML_VCPKG_HOST_TRIPLET=arm64-osx ;;
        dev-darwin_x86_64)    DKML_VCPKG_HOST_TRIPLET=x64-osx ;;
        windows_x86-*)        DKML_VCPKG_HOST_TRIPLET=x86-windows ;;
        windows_x86_64-*)     DKML_VCPKG_HOST_TRIPLET=x64-windows ;;
        windows_arm-*)        DKML_VCPKG_HOST_TRIPLET=arm-windows ;;
        windows_arm64-*)      DKML_VCPKG_HOST_TRIPLET=arm64-windows ;;
        darwin_arm64-*)       DKML_VCPKG_HOST_TRIPLET=arm64-osx ;;
        darwin_x86_64-*)      DKML_VCPKG_HOST_TRIPLET=x64-osx ;;
        *)
            printf "%s\n" "FATAL: Unsupported vcpkg triplet for PLATFORM-BUILDHOST_ARCH: $PLATFORM-$BUILDHOST_ARCH" >&2
            exit 1
            ;;
    esac
}
else
vcpkg_triplet_arg_platform() {
    vcpkg_triplet_arg_platform_PLATFORM=$1
    shift
    # TODO: This static list is brittle. Should parse the Makefile or better yet
    # place in a different file that can be used by this script and the Makefile.
    # In fact, the list we should be using is base.mk:VCPKG_TRIPLET_*
    case "$vcpkg_triplet_arg_platform_PLATFORM" in
        # See base.mk:DKML_PLATFORMS for why OS/X triplet is chosen rather than iOS (which would be dev-darwin_arm64_iosdevice)
        # Caution: arm64-osx and arm64-ios triplets are Community supported. https://github.com/microsoft/vcpkg/tree/master/triplets/community
        # and https://github.com/microsoft/vcpkg/issues/12258 .
        windows_x86)        DKML_VCPKG_HOST_TRIPLET=x86-windows ;;
        windows_x86_64)     DKML_VCPKG_HOST_TRIPLET=x64-windows ;;
        windows_arm)        DKML_VCPKG_HOST_TRIPLET=arm-windows ;;
        windows_arm64)      DKML_VCPKG_HOST_TRIPLET=arm64-windows ;;
        darwin_arm64)       DKML_VCPKG_HOST_TRIPLET=arm64-osx ;;
        darwin_x86_64)      DKML_VCPKG_HOST_TRIPLET=x64-osx ;;
        *)
            printf "%s\n" "FATAL: Unsupported vcpkg triplet for DKMLPLATFORM: $vcpkg_triplet_arg_platform_PLATFORM" >&2
            exit 1
            ;;
    esac
}
fi

# Fix the MSYS2 ambiguity problem described at https://github.com/msys2/MSYS2-packages/issues/2316. Our error is running:
#   cl -nologo -O2 -Gy- -MD -Feocamlrun.exe prims.obj libcamlrun.lib advapi32.lib ws2_32.lib version.lib /link /subsystem:console /ENTRY:wmainCRTStartup
# would warn
#   cl : Command line warning D9002 : ignoring unknown option '/subsystem:console'
#   cl : Command line warning D9002 : ignoring unknown option '/ENTRY:wmainCRTStartup'
# because the slashes (/) could mean Windows paths or Windows options. We force the latter.
#
# This is described in Automatic Unix ⟶ Windows Path Conversion
# at https://www.msys2.org/docs/filesystem-paths/
disambiguate_filesystem_paths() {
    if is_msys2_msys_build_machine; then
        export MSYS2_ARG_CONV_EXCL='*'
    fi
}

# Get the number of CPUs available.
#
# Inputs:
# - env:NUMCPUS. Optional. If set, no autodetection occurs.
# Outputs:
# - env:NUMCPUS . Maximum of 8 if detectable; otherwise 1. Always a number from 1 to 8, even
#   if on input env:NUMCPUS was set to text.
autodetect_cpus() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    # initialize to 0 if not set
    if [ -z "${NUMCPUS:-}" ]; then
        NUMCPUS=0
    fi
    # type cast to a number (in case user gave a string)
    NUMCPUS=$(( NUMCPUS + 0 ))
    if [ "${NUMCPUS}" -eq 0 ]; then
        # need temp directory
        if [ -n "${_CS_DARWIN_USER_TEMP_DIR:-}" ]; then # macOS (see `man mktemp`)
            autodetect_cpus_TEMPDIR=$(mktemp -d "$_CS_DARWIN_USER_TEMP_DIR"/dkmlcpu.XXXXX)
        elif [ -n "${TMPDIR:-}" ]; then # macOS (see `man mktemp`)
            autodetect_cpus_TEMPDIR=$(printf "%s" "$TMPDIR" | sed 's#/$##') # remove trailing slash on macOS
            autodetect_cpus_TEMPDIR=$(mktemp -d "$autodetect_cpus_TEMPDIR"/dkmlcpu.XXXXX)
        elif [ -n "${TMP:-}" ]; then # MSYS2 (Windows), Linux
            autodetect_cpus_TEMPDIR=$(mktemp -d "$TMP"/dkmlcpu.XXXXX)
        else
            autodetect_cpus_TEMPDIR=$(mktemp -d /tmp/dkmlcpu.XXXXX)
        fi

        # do calculations
        NUMCPUS=1
        if [ -n "${NUMBER_OF_PROCESSORS:-}" ]; then
            # Windows usually has NUMBER_OF_PROCESSORS
            NUMCPUS="$NUMBER_OF_PROCESSORS"
        elif [ -x /usr/bin/getconf ] && /usr/bin/getconf _NPROCESSORS_ONLN > "$autodetect_cpus_TEMPDIR"/numcpus 2>/dev/null && [ -s "$autodetect_cpus_TEMPDIR"/numcpus ]; then
            # getconf is POSIX standard; works on macOS; https://pubs.opengroup.org/onlinepubs/009604499/utilities/getconf.html
            NUMCPUS=$("$DKMLSYS_CAT" "$autodetect_cpus_TEMPDIR"/numcpus)
        elif [ -x /usr/bin/nproc ] && /usr/bin/nproc --all > "$autodetect_cpus_TEMPDIR"/numcpus 2>/dev/null && [ -s "$autodetect_cpus_TEMPDIR"/numcpus ]; then
            # nproc is usually available on Linux
            NUMCPUS=$("$DKMLSYS_CAT" "$autodetect_cpus_TEMPDIR"/numcpus)
        fi

        # clean temp directory
        rm -rf "$autodetect_cpus_TEMPDIR"
    fi
    # type cast again to a number (in case autodetection produced a string)
    NUMCPUS=$(( NUMCPUS + 0 ))
    if [ "${NUMCPUS}" -lt 1 ]; then
        NUMCPUS=1
    elif [ "${NUMCPUS}" -gt 8 ]; then
        NUMCPUS=8
    fi
    export NUMCPUS
}

# Set VSDEV_HOME_UNIX and VSDEV_HOME_BUILDHOST, if Visual Studio was installed or detected during
# Windows Diskuv OCaml installation.
#
# Inputs:
# - $1 - Optional. If provided, then $1/include and $1/lib are added to INCLUDE and LIB, respectively
# - env:PLATFORM - Optional; if missing treated as 'dev'. This variable will select the Visual Studio
#   options necessary to cross-compile (or native compile) to the target PLATFORM. 'dev' is always
#   a native compilation.
# - env:WORK - Optional. If provided will be used as temporary directory
# - env:DKML_COMPILE_VS_DIR - Optional. If provided with all three (3) DKML_COMPILE_VS_* variables the
#   specified installation directory of Visual Studio will be used.
#   The directory should contain VC and Common7 subfolders.
# - env:DKML_COMPILE_VS_VCVARSVER - Optional. If provided it must be a version that can locate the Visual Studio
#   installation in DKML_COMPILE_VS_DIR when `vsdevcmd.bat -vcvars_ver=VERSION` is invoked. Example: `14.26`
# - env:DKML_COMPILE_VS_WINSDKVER - Optional. If provided it must be a version that can locate the Windows SDK
#   kit when `vsdevcmd.bat -winsdk=VERSION` is invoked. Example: `10.0.18362.0`
# - env:DKML_COMPILE_VS_MSVSPREFERENCE - Optional. If provided it must be a MSVS_PREFERENCE environment variable
#   value that can locate the Visual Studio installation in DKML_COMPILE_VS_DIR when
#   https://github.com/metastack/msvs-tools's or Opam's `msvs-detect` is invoked. Example: `VS16.6`
# - env:DKML_COMPILE_VS_CMAKEGENERATOR - Optional. If provided it must be a CMake Generator that makes use of
#   the Visual Studio installation in DKML_COMPILE_VS_DIR. Example: `Visual Studio 16 2019`.
#   Full list at https://cmake.org/cmake/help/v3.22/manual/cmake-generators.7.html#visual-studio-generators
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:VSDEV_HOME_UNIX is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Empty otherwise
# - env:VSDEV_HOME_BUILDHOST is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Will be Windows path if Windows. Empty if Visual Studio not detected.
# Return Values:
# - 0: Success or a non-Windows machine. A non-Windows machine will have all outputs set to blank
# - 1: Windows machine without proper Diskuv OCaml installation (typically you should exit fatally)
autodetect_vsdev() {
    export VSDEV_HOME_UNIX=
    export VSDEV_HOME_BUILDHOST=
    export VSDEV_VCVARSVER=
    export VSDEV_WINSDKVER=
    export VSDEV_MSVSPREFERENCE=
    export VSDEV_CMAKEGENERATOR=
    if ! is_unixy_windows_build_machine; then
        return 0
    fi

    # Set DKMLPARENTHOME_BUILDHOST
    set_dkmlparenthomedir
    # Set DKMLSYS_*
    autodetect_system_binaries

    if [ "${DKML_COMPILE_SPEC:-}" = 1 ] && [ "${DKML_COMPILE_TYPE:-}" = VS ]; then
        autodetect_vsdev_VSSTUDIODIR=$DKML_COMPILE_VS_DIR
        autodetect_vsdev_VSSTUDIOVCVARSVER=$DKML_COMPILE_VS_VCVARSVER
        autodetect_vsdev_VSSTUDIOWINSDKVER=$DKML_COMPILE_VS_WINSDKVER
        autodetect_vsdev_VSSTUDIOMSVSPREFERENCE=$DKML_COMPILE_VS_MSVSPREFERENCE
        autodetect_vsdev_VSSTUDIOCMAKEGENERATOR=$DKML_COMPILE_VS_CMAKEGENERATOR
    else
        autodetect_vsdev_VSSTUDIO_DIRFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.dir.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_DIRFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIO_VCVARSVERFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.vcvars_ver.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_VCVARSVERFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIO_WINSDKVERFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.winsdk.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_WINSDKVERFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIO_MSVSPREFERENCEFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.msvs_preference.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_MSVSPREFERENCEFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIOCMAKEGENERATORFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.cmake_generator.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIOCMAKEGENERATORFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIODIR=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_DIRFILE")
        autodetect_vsdev_VSSTUDIOVCVARSVER=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_VCVARSVERFILE")
        autodetect_vsdev_VSSTUDIOWINSDKVER=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_WINSDKVERFILE")
        autodetect_vsdev_VSSTUDIOMSVSPREFERENCE=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_MSVSPREFERENCEFILE")
        autodetect_vsdev_VSSTUDIOCMAKEGENERATOR=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIOCMAKEGENERATORFILE")
    fi
    if [ -x /usr/bin/cygpath ]; then
        autodetect_vsdev_VSSTUDIODIR=$(/usr/bin/cygpath -au "$autodetect_vsdev_VSSTUDIODIR")
    fi
    VSDEV_HOME_UNIX="$autodetect_vsdev_VSSTUDIODIR"
    if [ -x /usr/bin/cygpath ]; then
        VSDEV_HOME_BUILDHOST=$(/usr/bin/cygpath -aw "$VSDEV_HOME_UNIX")
    else
        VSDEV_HOME_BUILDHOST="$VSDEV_HOME_UNIX"
    fi
    VSDEV_VCVARSVER="$autodetect_vsdev_VSSTUDIOVCVARSVER"
    VSDEV_WINSDKVER="$autodetect_vsdev_VSSTUDIOWINSDKVER"
    VSDEV_MSVSPREFERENCE="$autodetect_vsdev_VSSTUDIOMSVSPREFERENCE"
    VSDEV_CMAKEGENERATOR="$autodetect_vsdev_VSSTUDIOCMAKEGENERATOR"
}

# Creates a program launcher that will use the system PATH.
#
# create_system_launcher OUTPUT_SCRIPT
create_system_launcher() {
    create_system_launcher_OUTPUTFILE="$1"
    shift

    # Set DKML_SYSTEM_PATH
    autodetect_system_path
    # Set DKML_POSIX_SHELL if not already set
    autodetect_posix_shell
    # Set DKMLSYS_*
    autodetect_system_binaries

    if [ -x /usr/bin/cygpath ]; then
        create_system_launcher_SYSTEMPATHUNIX=$(/usr/bin/cygpath --path "$DKML_SYSTEM_PATH")
    else
        create_system_launcher_SYSTEMPATHUNIX="$DKML_SYSTEM_PATH"
    fi

    printf "#!%s\nexec %s PATH='%s' %s\n" "$DKML_POSIX_SHELL" "$DKMLSYS_ENV" "$create_system_launcher_SYSTEMPATHUNIX" '"$@"' > "$create_system_launcher_OUTPUTFILE".tmp
    "$DKMLSYS_CHMOD" +x "$create_system_launcher_OUTPUTFILE".tmp
    "$DKMLSYS_MV" "$create_system_launcher_OUTPUTFILE".tmp "$create_system_launcher_OUTPUTFILE"
}

# Detects a compiler like Visual Studio and sets its variables.
#
# autodetect_compiler [--sexp] OUTPUT_SCRIPT_OR_SEXP [EXTRA_PREFIX]
#
# Example:
#  autodetect_compiler /tmp/launcher.sh && /tmp/launcher.sh cl.exe /help
#
# The generated launcher.sh behaves like a `env` command. You may place environment variable
# definitions before your target executable. Also you may use `-u name` to unset an environment
# variable. In fact, if there is no compiler detected than the generated launcher.sh is simply
# a file containing the line `exec env "$@"`.
#
# The launcher script will use the system PATH; any existing PATH will be ignored.
#
# If `--sexp` was used, then the output file is an s-expr (https://github.com/janestreet/sexplib#lexical-conventions-of-s-expression)
# file. It contains an association list of the environment variables; that is, a list of pairs where each pair is a 2-element
# list (KEY VALUE). The s-exp output will always use the full PATH, but the variable PATH_COMPILER will be the
# parts of PATH that are specific to the compiler (you can prepend it to an existing PATH).
#
# If `--msvs-detect` was used, then the output file will be a script that can replace
# https://github.com/metastack/msvs-tools#msvs-detect. The shell output from the output script
# will be the Visual Studio installation detected by this function.
#
# Example:
#   DKML_TARGET_PLATFORM=windows_x86 DKML_FEATUREFLAG_CMAKE_PLATFORM=ON autodetect_compiler --msvs-detect /tmp/msvs-detect
#   eval `bash /tmp/msvs-detect` # this is what https://github.com/ocaml/opam/blob/c7759e08722520d3ab8a8e162f3841d270191490/configure#L3655 does
#   echo $MSVS_NAME # etc.
#
# Inputs:
# - $1 - Optional. If provided, then $1/include and $1/lib are added to INCLUDE and LIB, respectively
# - env:DKML_TARGET_PLATFORM - This variable will select the compiler options necessary to cross-compile (or native compile)
#   to the target PLATFORM. 'dev' is not a target platform.
# - env:DKML_PREFER_CROSS_OVER_NATIVE - Optional. ON means prefer to create a cross-compiler, while OFF (the default)
#   means to prefer to create a native compiler. The only time the preference is used is when both native and cross compilers
#   are viable ways to produce a binary. Examples are:
#      1. Windows x64 host can cross-compile to x86 binaries, but it can also use a x86 compiler to natively build x86 binaries.
#         This is possible because 64-bit Windows Intel machines can run both x64 and x86.
#      2. Apple Silicon (Mac M1) can cross-compile from ARM64 to x86_64, but it can also use a x86_64 compiler (under Rosetta emulator)
#         to natively build x86_64 binaries.
#         This is possible because Apple Silicon with a Rosetta emulator can run both ARM64 and x86_64.
#   The tradeoff is that a native compiler will always produce the correct binaries if it can build the binary, but a cross-compiler
#   has more opportunities to build a binary because it can have more RAM (ex. bigger symbol tables are available on a Win64 host
#   cross-compiling to Win32 binary) and often runs faster (ex. QEMU emulation of a native compiler is slow). The tradeoff is similar to
#   precision (correctness for native compiler) versus recall (binaries can be produced in more situations, more quickly, than a native compiler).
#   The default is to prefer native compiler (ie. OFF) so that the generated binaries are always correct.
# - env:PLATFORM - (Deprecated) Optional; if missing treated as 'dev'. This variable will select the Visual Studio
#   options necessary to cross-compile (or native compile) to the target PLATFORM. 'dev' is always
#   a native compilation.
# - env:WORK - Optional. If provided will be used as temporary directory
# - env:DKML_COMPILE_SPEC - Optional. If specified will be a specification number, which determines which
#   other environment variables have to be supplied and the format of each variable.
#   Only spec 1 is supported today:
#   - env:DKML_COMPILE_TYPE - "VS" for Visual Studio. The following vars must be defined:
#     - env:DKML_COMPILE_VS_DIR - The
#       specified installation directory of Visual Studio will be used.
#       The directory should contain VC and Common7 subfolders.
#     - env:DKML_COMPILE_VS_VCVARSVER - Must be a version that can locate the Visual Studio
#       installation in DKML_COMPILE_VS_DIR when `vsdevcmd.bat -vcvars_ver=VERSION` is invoked. Example: `14.26`
#     - env:DKML_COMPILE_VS_WINSDKVER - Must be a version that can locate the Windows SDK
#       kit when `vsdevcmd.bat -winsdk=VERSION` is invoked. Example: `10.0.18362.0`
#     - env:DKML_COMPILE_VS_MSVSPREFERENCE - Must be a MSVS_PREFERENCE environment variable
#       value that can locate the Visual Studio installation in DKML_COMPILE_VS_DIR when
#       https://github.com/metastack/msvs-tools's or Opam's `msvs-detect` is invoked. Example: `VS16.6`
#   - env:DKML_COMPILE_TYPE - "CM" for CMake. The following CMake variables should be defined if they exist:
#     - env:DKML_COMPILE_CM_CONFIG - The value of the CMake generator expression $<CONFIG>
#     - env:DKML_COMPILE_CM_HAVE_AFL - Whether the CMake compiler is an AFL fuzzy compiler
#     - env:DKML_COMPILE_CM_CMAKE_SYSROOT - The CMake variable CMAKE_SYSROOT
#     - env:DKML_COMPILE_CM_CMAKE_SYSTEM_NAME - The CMake variable CMAKE_SYSTEM_NAME
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_ASM_NASM_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILER_ID
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS - All uppercased values of $<CONFIG> should be defined as well. The
#       4 variables below are the standard $<CONFIG> that come with DKSDK.
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_RELEASE
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_RELEASECOMPATFUZZ
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_RELEASECOMPATPERF
#     - env:DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P
#     - env:DKML_COMPILE_CM_MSVC
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:BUILDHOST_ARCH will contain the correct ARCH
# - env:DKML_SYSTEM_PATH
# - env:OCAML_HOST_TRIPLET is non-empty if `--host OCAML_HOST_TRIPLET` should be passed to OCaml's ./configure script when
#   compiling OCaml. Aligns with the PLATFORM variable that was specified, especially for cross-compilation.
# - env:VSDEV_HOME_UNIX is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Empty otherwise
# - env:VSDEV_HOME_BUILDHOST is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Will be Windows path if Windows. Empty if Visual Studio not detected.
# Launcher/s-exp Environment:
# - (When DKML_COMPILE_TYPE=VS) MSVS_PREFERENCE will be set for https://github.com/metastack/msvs-tools or
#   Opam's `msvs-detect` to detect which Visual Studio installation to use. Example: `VS16.6`
# - (When DKML_COMPILE_TYPE=VS) CMAKE_GENERATOR_RECOMMENDED will be set for build scripts to use a sensible generator
#   in `cmake -G <generator>` if there is not a more appropriate value. Example: `Visual Studio 16 2019`
# - (When DKML_COMPILE_TYPE=VS) CMAKE_GENERATOR_INSTANCE_RECOMMENDED will be set for build scripts to use a sensible
#   generator instance in `cmake -G ... -D CMAKE_GENERATOR_INSTANCE=<generator instance>`. Only set for Visual Studio where
#   it is the absolute path to a Visual Studio instance. Example: `C:\DiskuvOCaml\BuildTools`
# - (When DKML_COMPILE_TYPE=CM) CC - C compiler
# - (When DKML_COMPILE_TYPE=CM) CFLAGS - C compiler flags
# - (When DKML_COMPILE_TYPE=CM) AS - Assembler (assembly language compiler)
# - (When DKML_COMPILE_TYPE=CM) DKML_COMPILE_CM_* - All these variables will be passed-through if CMake so
#   downstream OCaml/Opam/etc. can fine-tune what flags / environment variables get passed into
#   their `./configure` scripts
autodetect_compiler() {
    # Set BUILDHOST_ARCH (needed before we process arguments)
    autodetect_buildhost_arch

    # Process arguments
    autodetect_compiler_OUTPUTMODE=LAUNCHER
    if [ "$1" = --sexp ]; then
        autodetect_compiler_OUTPUTMODE=SEXP
        shift
    elif [ "$1" = --msvs-detect ]; then
        autodetect_compiler_OUTPUTMODE=MSVS_DETECT
        shift
    fi
    autodetect_compiler_OUTPUTFILE="$1"
    shift
    autodetect_compiler_TEMPDIR=${WORK:-$TMP}
    if [ -n "${WORK:-}" ]; then
        autodetect_compiler_TEMPDIR=$WORK
    elif [ -n "${_CS_DARWIN_USER_TEMP_DIR:-}" ]; then # macOS (see `man mktemp`)
        autodetect_compiler_TEMPDIR=$(mktemp -d "$_CS_DARWIN_USER_TEMP_DIR"/dkmlc.XXXXX)
    elif [ -n "${TMPDIR:-}" ]; then # macOS (see `man mktemp`)
        autodetect_compiler_TEMPDIR=$(printf "%s" "$TMPDIR" | sed 's#/$##') # remove trailing slash on macOS
        autodetect_compiler_TEMPDIR=$(mktemp -d "$autodetect_compiler_TEMPDIR"/dkmlc.XXXXX)
    elif [ -n "${TMP:-}" ]; then # MSYS2 (Windows), Linux
        autodetect_compiler_TEMPDIR=$(mktemp -d "$TMP"/dkmlc.XXXXX)
    else
        autodetect_compiler_TEMPDIR=$(mktemp -d /tmp/dkmlc.XXXXX)
    fi
    if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
        autodetect_compiler_PLATFORM_ARCH=${PLATFORM:-dev}
    else
        if [ -n "${DKML_TARGET_PLATFORM:-}" ]; then
            autodetect_compiler_PLATFORM_ARCH=$DKML_TARGET_PLATFORM
        else
            autodetect_compiler_PLATFORM_ARCH=$BUILDHOST_ARCH
        fi
    fi

    # Validate compile spec
    autodetect_compiler_SPECBITS=""

    [ -n "${DKML_COMPILE_VS_DIR:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}1"
    [ -n "${DKML_COMPILE_VS_VCVARSVER:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}2"
    [ -n "${DKML_COMPILE_VS_WINSDKVER:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}3"
    [ -n "${DKML_COMPILE_VS_MSVSPREFERENCE:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}4"

    [ -n "${DKML_COMPILE_CM_CONFIG:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}a"
    [ -n "${DKML_COMPILE_CM_CMAKE_SYSTEM_NAME:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}b"
    [ -n "${DKML_COMPILE_CM_CMAKE_C_COMPILER:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}c"
    [ -n "${DKML_COMPILE_CM_CMAKE_C_COMPILER_ID:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}d"
    [ -n "${DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}e"

    if [ -z "${DKML_COMPILE_SPEC:-}" ]; then
        if [ ! "$autodetect_compiler_SPECBITS" = "" ]; then
            printf "No DKML compile environment variables should be passed without a DKML compile spec. Error code: %s\n" "$autodetect_compiler_SPECBITS" >&2
            exit 107
        fi
    elif [ "${DKML_COMPILE_SPEC:-}" = 1 ]; then
        case "${DKML_COMPILE_TYPE:-}" in
            VS)
                if [ ! "$autodetect_compiler_SPECBITS" = "1234" ]; then
                    printf "DKML compile spec 1 for Visual Studio (VS) was not followed. Error code: %s\n" "$autodetect_compiler_SPECBITS" >&2
                    exit 107
                fi
                ;;
            CM)
                if [ ! "$autodetect_compiler_SPECBITS" = "abcde" ]; then
                    printf "DKML compile spec 1 for CMake (CM) was not followed. Error code: %s\n" "$autodetect_compiler_SPECBITS" >&2
                    exit 107
                fi
                ;;
            *)
                printf "DKML compile spec 1 was not followed. DKML_COMPILE_TYPE must be VS or CM" >&2
                exit 107
            ;;
        esac
    else
        printf "Only DKML compile spec 1 is supported\n" >&2
        exit 107
    fi

    # Set DKML_POSIX_SHELL if not already set
    autodetect_posix_shell
    # Set DKML_SYSTEM_PATH
    autodetect_system_path

    # Set DKMLSYS_*
    autodetect_system_binaries

    # Initialize output script and variables in case of failure
    if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
        printf '()' > "$autodetect_compiler_OUTPUTFILE".tmp
        "$DKMLSYS_MV" "$autodetect_compiler_OUTPUTFILE".tmp "$autodetect_compiler_OUTPUTFILE"
    elif [ "$autodetect_compiler_OUTPUTMODE" = MSVS_DETECT ]; then
        true > "$autodetect_compiler_OUTPUTFILE"
        "$DKMLSYS_CHMOD" +x "$autodetect_compiler_OUTPUTFILE"
    elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
        create_system_launcher "$autodetect_compiler_OUTPUTFILE"
    fi
    export VSDEV_HOME_UNIX=
    export VSDEV_HOME_BUILDHOST=

    # Host triplet:
    #   (TODO: Better link)
    #   https://gitlab.com/diskuv/diskuv-ocaml/-/blob/aabf3171af67a0a0ff4779c336867a7a43e3670f/etc/opam-repositories/diskuv-opam-repo/packages/ocaml-variants/ocaml-variants.4.12.0+options+dkml+msvc64/opam#L52-62
    export OCAML_HOST_TRIPLET=

    if [ "${DKML_COMPILE_SPEC:-}" = 1 ] && [ "${DKML_COMPILE_TYPE:-}" = VS ]; then
        autodetect_vsdev # set DKMLPARENTHOME_BUILDHOST and VSDEV_*
        autodetect_compiler_vsdev
    elif [ "${DKML_COMPILE_SPEC:-}" = 1 ] && [ "${DKML_COMPILE_TYPE:-}" = CM ]; then
        autodetect_compiler_cmake
    elif autodetect_vsdev && [ -n "$VSDEV_HOME_UNIX" ]; then
        # `autodetect_vsdev` will have set DKMLPARENTHOME_BUILDHOST and VSDEV_*
        autodetect_compiler_vsdev
    elif [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_x86_64" ] || [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_arm64" ]; then
        autodetect_compiler_darwin
    else
        autodetect_compiler_system
    fi

    # When $WORK is not defined, we have a unique directory that needs cleaning
    if [ -z "${WORK:-}" ]; then
        rm -rf "$autodetect_compiler_TEMPDIR"
    fi
}

# Each s-exp string must follow OCaml syntax (escape double-quotes and backslashes)
# Since each name/value pair is an assocation list, we replace the first `=` in each line with `" "`.
# So if the input is: NAME=VALUE
# then the output is: NAME" "VALUE
autodetect_compiler_escape_sexp() {
    "$DKMLSYS_SED" 's#\\#\\\\#g; s#"#\\"#g; s#=#" "#; ' "$@"
}

# Since we will embed each name/value pair in single quotes
# (ie. Z=hi ' there ==> 'Z=hi '"'"' there') so it can be placed
# as a single `env` argument like `env 'Z=hi '"'"' there' ...`
# we need to replace single quotes (') with ('"'"').
autodetect_compiler_escape_envarg() {
    "$DKMLSYS_CAT" "$@" | escape_stdin_for_single_quote
}

# Sets _CMAKE_C_FLAGS_FOR_CONFIG environment variable to the value of config-specific
# cflag variable like `DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG` when `DKML_COMPILE_CM_CONFIG` is
# `Debug`.
autodetect_compiler_cmake_get_config_c_flags() {
    # example command: _CMAKE_C_FLAGS_FOR_CONFIG="$DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG"
    _DKML_COMPILE_CM_CONFIG_UPPER=$(printf "%s" "$DKML_COMPILE_CM_CONFIG" | tr '[:lower:]' '[:upper:]')
    printf "_CMAKE_C_FLAGS_FOR_CONFIG=\"\$DKML_COMPILE_CM_CMAKE_C_FLAGS_%s\"" "$_DKML_COMPILE_CM_CONFIG_UPPER" > "$WORK"/cflags.source
    # shellcheck disable=SC1091
    . "$WORK"/cflags.source
}

autodetect_compiler_cmake() {
    {
        # Choose which assembler should be used
        autodetect_compiler_cmake_THE_AS=
        if [ -n "${DKML_COMPILE_CM_CMAKE_ASM_COMPILER:-}" ]; then
            autodetect_compiler_cmake_THE_AS=$DKML_COMPILE_CM_CMAKE_ASM_COMPILER
        elif [ -n "${DKML_COMPILE_CM_CMAKE_ASM_NASM_COMPILER:-}" ]; then
            autodetect_compiler_cmake_THE_AS=$DKML_COMPILE_CM_CMAKE_ASM_NASM_COMPILER
        elif [ -n "${DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER:-}" ]; then
            autodetect_compiler_cmake_THE_AS=$DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER
        fi

        # Set _CMAKE_C_FLAGS_FOR_CONFIG to $DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG if DKML_COMPILE_CM_CONFIG=Debug, etc.
        autodetect_compiler_cmake_get_config_c_flags

        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf "(\n"

            # Universal ./configure flags
            autodetect_compiler_cmake_CC=$(escape_arg_as_ocaml_string "${DKML_COMPILE_CM_CMAKE_C_COMPILER:-}")
            printf "  (\"CC\" \"%s\")\n" "$autodetect_compiler_cmake_CC"
            autodetect_compiler_cmake_CFLAGS=$(escape_arg_as_ocaml_string "${DKML_COMPILE_CM_CMAKE_C_FLAGS:-} $_CMAKE_C_FLAGS_FOR_CONFIG")
            printf "  (\"CFLAGS\" \"%s\")\n" "$autodetect_compiler_cmake_CFLAGS"
            autodetect_compiler_cmake_AS=$(escape_arg_as_ocaml_string "$autodetect_compiler_cmake_THE_AS")
            printf "  (\"AS\" \"%s\")\n" "$autodetect_compiler_cmake_AS"

            # Passthrough all DKML_COMPILE_CM_* variables.
            # The first `sed` command removes any surrounding single quotes from any values.
            # The second `sed` command adds a surrounding parenthesis and double quote ("...") to each value.
            # shellcheck disable=SC2016
            set | "$DKMLSYS_AWK" 'BEGIN{FS="="} $1 ~ /^DKML_COMPILE_CM_/ {print}' \
                | "$DKMLSYS_SED" "s/^\([^=]*\)='\(.*\)'$/\1=\2/" \
                | autodetect_compiler_escape_sexp \
                | "$DKMLSYS_SED" 's/^/  ("/; s/$/")/'
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "#!$DKML_POSIX_SHELL"
            printf "%s\n" "exec $DKMLSYS_ENV \\"

            # Universal ./configure flags
            autodetect_compiler_cmake_CC=$(escape_args_for_shell "${DKML_COMPILE_CM_CMAKE_C_COMPILER:-}")
            printf "  CC=%s \\\n" "$autodetect_compiler_cmake_CC"
            autodetect_compiler_cmake_CFLAGS=$(escape_args_for_shell "${DKML_COMPILE_CM_CMAKE_C_FLAGS:-} $_CMAKE_C_FLAGS_FOR_CONFIG")
            printf "  CFLAGS=%s \\\n" "$autodetect_compiler_cmake_CFLAGS"
            autodetect_compiler_cmake_AS=$(escape_args_for_shell "$autodetect_compiler_cmake_THE_AS")
            printf "  AS=%s \\\n" "$autodetect_compiler_cmake_AS"

            # Passthrough all DKML_COMPILE_CM_* variables
            # shellcheck disable=SC2016
            set | "$DKMLSYS_AWK" -v bslash="\\" 'BEGIN{FS="="} $1 ~ /^DKML_COMPILE_CM_/ {name=$1; value=$0; sub(/^[^=]*=/,"",value); print "  " name "=" value " " bslash}'
        fi

        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf ")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            # Add arguments
            printf "%s\n" '  "$@"'
        fi
    } > "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_CHMOD" +x "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_MV" "$autodetect_compiler_OUTPUTFILE".tmp "$autodetect_compiler_OUTPUTFILE"
}

autodetect_compiler_system() {
    {
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf "(\n"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "#!$DKML_POSIX_SHELL"
            printf "%s\n" "exec $DKMLSYS_ENV \\"
        fi

        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf ")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            # Add arguments
            printf "%s\n" '  "$@"'
        fi
    } > "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_CHMOD" +x "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_MV" "$autodetect_compiler_OUTPUTFILE".tmp "$autodetect_compiler_OUTPUTFILE"
}

autodetect_compiler_darwin() {
    {
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf "(\n"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "#!$DKML_POSIX_SHELL"
        fi

        if [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            if [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_x86_64" ] ; then
                printf "exec %s AS='%s' ASPP='%s' CC='%s' PARTIALLD='%s' " "$DKMLSYS_ENV" \
                        "clang -arch x86_64 -Wno-trigraphs -c" \
                        "clang -arch x86_64 -Wno-trigraphs -c" \
                        "clang -arch x86_64" \
                        "ld -r -arch x86_64"
            elif [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_arm64" ]; then
                if [ "$BUILDHOST_ARCH" = "darwin_arm64" ]; then
                    printf "exec %s AS='%s' ASPP='%s' CC='%s' PARTIALLD='%s' " "$DKMLSYS_ENV" \
                        "clang -arch arm64 -Wno-trigraphs -c" \
                        "clang -arch arm64 -Wno-trigraphs -c" \
                        "clang -arch arm64" \
                        "ld -r -arch arm64"
                else
                    printf "%s\n" "FATAL: Only Apple Silicon (darwin_arm64) build machines can target Apple Silicon binaries." >&2
                    printf "%s\n" "       Apple does not provide Rosetta emulation on Intel macOS machines." >&2
                    exit 107
                fi
            else
                printf "%s\n" "FATAL: check_state autodetect_compiler_darwin + unsupported arch=$autodetect_compiler_PLATFORM_ARCH" >&2
                exit 107
            fi
        fi

        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf ")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            # Add arguments
            printf "%s\n" '  "$@"'
        fi
    } > "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_CHMOD" +x "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_MV" "$autodetect_compiler_OUTPUTFILE".tmp "$autodetect_compiler_OUTPUTFILE"
}

autodetect_compiler_vsdev() {
    # Implementation note: You can use `autodetect_compiler_` as the prefix for your variables,
    # and read the variables created by `autodetect_compiler()`

    # The vsdevcmd.bat is at /c/DiskuvOCaml/BuildTools/Common7/Tools/VsDevCmd.bat.
    if [ -e "$VSDEV_HOME_UNIX"/Common7/Tools/VsDevCmd.bat ]; then
        autodetect_compiler_VSDEVCMD="$VSDEV_HOME_UNIX/Common7/Tools/VsDevCmd.bat"
    else
        echo "FATAL: No Common7/Tools/VsDevCmd.bat was detected at $VSDEV_HOME_UNIX" >&2
        exit 107
    fi

    # FIRST, create a file that calls vsdevcmd.bat and then adds a `set` dump.
    # Example:
    #     @call "C:\DiskuvOCaml\BuildTools\Common7\Tools\VsDevCmd.bat" %*
    #     set > "C:\the-WORK-directory\vcvars.txt"
    # to the bottom of it so we can inspect the environment variables.
    # (Less hacky version of https://help.appveyor.com/discussions/questions/18777-how-to-use-vcvars64bat-from-powershell)
    if [ -x /usr/bin/cygpath ]; then
        autodetect_compiler_VSDEVCMDFILE_WIN=$(/usr/bin/cygpath -aw "$autodetect_compiler_VSDEVCMD")
        autodetect_compiler_TEMPDIR_WIN=$(/usr/bin/cygpath -aw "$autodetect_compiler_TEMPDIR")
    else
        autodetect_compiler_VSDEVCMDFILE_WIN="$autodetect_compiler_VSDEVCMD"
        autodetect_compiler_TEMPDIR_WIN="$autodetect_compiler_TEMPDIR"
    fi
    {
        printf "@call %s%s%s %s\n" '"' "$autodetect_compiler_VSDEVCMDFILE_WIN" '"' '%*'
        printf "%s\n" 'if %ERRORLEVEL% neq 0 ('
        printf "%s\n" 'echo.'
        printf "%s\n" 'echo.FATAL: VsDevCmd.bat failed to find a Visual Studio compiler.'
        printf "%s\n" 'echo.'
        printf "%s\n" 'exit /b %ERRORLEVEL%'
        printf "%s\n" ')'
        printf "set > %s%s%s%s\n" '"' "$autodetect_compiler_TEMPDIR_WIN" '\vcvars.txt' '"'
    } > "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat

    # SECOND, construct a function that will call Microsoft's vsdevcmd.bat script.
    # We will use DKML_SYSTEM_PATH for reproducibility.
    if   [ "${DKML_BUILD_TRACE:-ON}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 4 ]; then
        autodetect_compiler_VSCMD_DEBUG=3
    elif [ "${DKML_BUILD_TRACE:-ON}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 3 ]; then
        autodetect_compiler_VSCMD_DEBUG=2
    elif [ "${DKML_BUILD_TRACE:-ON}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
        autodetect_compiler_VSCMD_DEBUG=1
    else
        autodetect_compiler_VSCMD_DEBUG=
    fi
    if [ -x /usr/bin/cygpath ]; then
        autodetect_compiler_vsdev_SYSTEMPATHUNIX=$(/usr/bin/cygpath --path "$DKML_SYSTEM_PATH")
    else
        autodetect_compiler_vsdev_SYSTEMPATHUNIX="$DKML_SYSTEM_PATH"
    fi
    # https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-160#vcvarsall-syntax
    # Notice that for MSVC the build machine is always x86 or x86_64, never ARM or ARM64.
    # And:
    #  * we follow the first triple of Rust naming of aarch64-pc-windows-msvc for the OCAML_HOST_TRIPLET on ARM64
    #  * we use armv7-pc-windows on ARM32 because OCaml's ./configure needs the ARM model (v6, v7, etc.).
    #    WinCE 7.0 and 8.0 support ARMv7, but don't mandate it; WinCE 8.0 extended support from MS is in
    #    2023 so ARMv7 should be fine.
    autodetect_compiler_vsdev_dump_vars_helper() {
        "$DKMLSYS_ENV" PATH="$autodetect_compiler_vsdev_SYSTEMPATHUNIX" __VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1 VSCMD_DEBUG="$autodetect_compiler_VSCMD_DEBUG" \
            "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat -no_logo -vcvars_ver="$VSDEV_VCVARSVER" -winsdk="$VSDEV_WINSDKVER" \
            "$@" >&2
    }
    if [ "$BUILDHOST_ARCH" = windows_x86 ]; then
        # The build host machine is 32-bit ...
        if [ "$autodetect_compiler_PLATFORM_ARCH" = dev ] || [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -arch=x86
            }
            OCAML_HOST_TRIPLET=i686-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="ml.exe"
            autodetect_compiler_vsdev_MSVS_ML="ml"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86_64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x86 -arch=x64
            }
            OCAML_HOST_TRIPLET=x86_64-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="ml64.exe"
            autodetect_compiler_vsdev_MSVS_ML="ml64"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm32 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x86 -arch=arm
            }
            OCAML_HOST_TRIPLET=aarch64-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="armasm64.exe"
            autodetect_compiler_vsdev_MSVS_ML="armasm64"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x86 -arch=arm64
            }
            OCAML_HOST_TRIPLET=armv7-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="armasm.exe"
            autodetect_compiler_vsdev_MSVS_ML="armasm"
        else
            printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
            exit 107
        fi
    elif [ "$BUILDHOST_ARCH" = windows_x86_64 ]; then
        # The build host machine is 64-bit ...
        if [ "$autodetect_compiler_PLATFORM_ARCH" = dev ] || [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86_64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -arch=x64
            }
            OCAML_HOST_TRIPLET=x86_64-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="ml64.exe"
            autodetect_compiler_vsdev_MSVS_ML="ml64"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                if [ "${DKML_PREFER_CROSS_OVER_NATIVE:-OFF}" = ON ]; then
                    autodetect_compiler_vsdev_dump_vars_helper -host_arch=x64 -arch=x86
                else
                    autodetect_compiler_vsdev_dump_vars_helper -arch=x86
                fi
            }
            OCAML_HOST_TRIPLET=i686-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="ml.exe"
            autodetect_compiler_vsdev_MSVS_ML="ml"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x64 -arch=arm64
            }
            OCAML_HOST_TRIPLET=aarch64-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="armasm64.exe"
            autodetect_compiler_vsdev_MSVS_ML="armasm64"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm32 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x64 -arch=arm
            }
            OCAML_HOST_TRIPLET=armv7-pc-windows
            autodetect_compiler_vsdev_VALIDATECMD="armasm.exe"
            autodetect_compiler_vsdev_MSVS_ML="armasm"
        else
            printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
            exit 107
        fi
    else
        printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
        exit 107
    fi

    # THIRD, we run the batch file
    autodetect_compiler_vsdev_dump_vars

    # FOURTH, capture everything we will need in the launcher environment except:
    # - PATH (we need to cygpath this, and we need to replace any existing PATH)
    # - MSVS_PREFERENCE (we will add our own)
    # - INCLUDE (we actually add this, but we also add our own vcpkg include path)
    # - LIB (we actually add this, but we also add our own vcpkg library path)
    # - _
    # - !ExitCode
    # - TEMP, TMP
    # - PWD
    # - PROMPT
    # - LOGON* (LOGONSERVER)
    # - *APPDATA (LOCALAPPDATA, APPDATA)
    # - ALLUSERSPROFILE
    # - CYGWIN
    # - CYGPATH
    # - CI_* (CI_JOB_JWT, CI_JOB_TOKEN, CI_REGISTRY_PASSWORD) on GitLab CI / GitHub Actions
    # - *_DEPLOY_TOKEN (DKML_PACKAGE_PUBLISH_PRIVATE_DEPLOY_TOKEN)
    # - PG* (PGUSER, PGPASSWORD) on GitHub Actions
    # - HOME* (HOME, HOMEDRIVE, HOMEPATH)
    # - USER* (USERNAME, USERPROFILE, USERDOMAIN, USERDOMAIN_ROAMINGPROFILE)
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="}

    $1 != "PATH" &&
    $1 != "MSVS_PREFERENCE" &&
    $1 != "INCLUDE" &&
    $1 != "LIB" &&
    $1 !~ /^!ExitCode/ &&
    $1 !~ /^_$/ && $1 != "TEMP" && $1 != "TMP" && $1 != "PWD" &&
    $1 != "PROMPT" && $1 !~ /^LOGON/ && $1 !~ /APPDATA$/ &&
    $1 != "ALLUSERSPROFILE" && $1 != "CYGWIN" && $1 != "CYGPATH" &&
    $1 !~ /^CI_/ && $1 !~ /_DEPLOY_TOKEN$/ && $1 !~ /^PG/ &&
    $1 !~ /^HOME/ &&
    $1 !~ /^USER/ {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" value}

    $1 == "INCLUDE" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" value}
    $1 == "LIB" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/mostvars.eval.sh

    # FIFTH, set autodetect_compiler_COMPILER_PATH to the provided PATH
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="}

    $1 == "PATH" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/winpath.txt
    if [ -x /usr/bin/cygpath ]; then
        # shellcheck disable=SC2086
        /usr/bin/cygpath --path -f - < "$autodetect_compiler_TEMPDIR/winpath.txt" > "$autodetect_compiler_TEMPDIR"/unixpath.txt
    else
        cp "$autodetect_compiler_TEMPDIR/winpath.txt" "$autodetect_compiler_TEMPDIR"/unixpath.txt
    fi
    # shellcheck disable=SC2034
    autodetect_compiler_COMPILER_PATH_UNIX=$("$DKMLSYS_CAT" "$autodetect_compiler_TEMPDIR"/unixpath.txt)
    autodetect_compiler_COMPILER_PATH_WIN=$("$DKMLSYS_CAT" "$autodetect_compiler_TEMPDIR"/winpath.txt)

    # VERIFY: make sure VsDevCmd.bat gave us the correct target assembler (which have unique names per target architecture)
    # shellcheck disable=SC2016
    autodetect_compiler_TGTARCH=$("$DKMLSYS_AWK" '
        BEGIN{FS="="} $1 == "VSCMD_ARG_TGT_ARCH" {name=$1; value=$0; sub(/^[^=]*=/,"",value);                print value}
        ' "$autodetect_compiler_TEMPDIR"/vcvars.txt)
    if ! PATH="$autodetect_compiler_COMPILER_PATH_UNIX" "$autodetect_compiler_vsdev_VALIDATECMD" -help >/dev/null 2>/dev/null; then
        echo "FATAL: The Visual Studio installation \"$VSDEV_HOME_BUILDHOST\" did not place '$autodetect_compiler_vsdev_VALIDATECMD' in its PATH." >&2
        echo "       It should be present for the target ABI $autodetect_compiler_PLATFORM_ARCH ($autodetect_compiler_TGTARCH) on a build host $BUILDHOST_ARCH." >&2
        echo "  Fix? Run the Visual Studio Installer and then:" >&2
        echo "       1. Make sure you have the MSVC v$VSDEV_VCVARSVER $autodetect_compiler_TGTARCH Build Tools component." >&2
        echo "       2. Also make sure you have the Windows SDK $VSDEV_WINSDKVER component." >&2
        exit 107
    fi

    # SIXTH, set autodetect_compiler_COMPILER_UNIQ_PATH so that it is only the _unique_ entries
    # (the set {autodetect_compiler_COMPILER_UNIQ_PATH} - {DKML_SYSTEM_PATH}) are used. But maintain the order
    # that Microsoft places each path entry.
    printf "%s\n" "$autodetect_compiler_COMPILER_PATH_UNIX" | "$DKMLSYS_AWK" 'BEGIN{RS=":"} {print}' > "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.txt
    "$DKMLSYS_SORT" -u "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.txt > "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.sortuniq.txt
    printf "%s\n" "$DKML_SYSTEM_PATH" | "$DKMLSYS_AWK" 'BEGIN{RS=":"} {print}' | "$DKMLSYS_SORT" -u > "$autodetect_compiler_TEMPDIR"/path.sortuniq.txt
    "$DKMLSYS_COMM" \
        -23 \
        "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.sortuniq.txt \
        "$autodetect_compiler_TEMPDIR"/path.sortuniq.txt \
        > "$autodetect_compiler_TEMPDIR"/vcvars_uniq.txt
    autodetect_compiler_COMPILER_UNIX_UNIQ_PATH=
    while IFS='' read -r autodetect_compiler_line; do
        # if and only if the $autodetect_compiler_line matches one of the lines in vcvars_uniq.txt
        if ! printf "%s\n" "$autodetect_compiler_line" | "$DKMLSYS_COMM" -12 - "$autodetect_compiler_TEMPDIR"/vcvars_uniq.txt | "$DKMLSYS_AWK" 'NF>0{exit 1}'; then
            if [ -z "$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH" ]; then
                autodetect_compiler_COMPILER_UNIX_UNIQ_PATH="$autodetect_compiler_line"
            else
                autodetect_compiler_COMPILER_UNIX_UNIQ_PATH="$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH:$autodetect_compiler_line"
            fi
        fi
    done < "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.txt
    autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH=$(printf "%s\n" "$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH" | /usr/bin/cygpath -w --path -f -)

    # SEVENTH, make the launcher script or s-exp
    if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
        autodetect_compiler_escape() {
            autodetect_compiler_escape_sexp "$@"
        }
    elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ] || [ "$autodetect_compiler_OUTPUTMODE" = MSVS_DETECT ]; then
        autodetect_compiler_escape() {
            autodetect_compiler_escape_envarg "$@"
        }
    fi
    {
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf "(\n"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "#!$DKML_POSIX_SHELL"
            if [ "${DKML_BUILD_TRACE:-}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
                printf "%s\n" "set -x"
            fi
            printf "%s\n" "exec $DKMLSYS_ENV \\"
        fi

        # Add all but PATH and MSVS_PREFERENCE, CMAKE_GENERATOR_RECOMMENDED and CMAKE_GENERATOR_INSTANCE_RECOMMENDED to launcher environment
        autodetect_compiler_escape "$autodetect_compiler_TEMPDIR"/mostvars.eval.sh | while IFS='' read -r autodetect_compiler_line; do
            if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
                printf "%s\n" "  (\"$autodetect_compiler_line\")";
            elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
                printf "%s\n" "  '$autodetect_compiler_line' \\";
            fi
        done

        # Add MSVS_PREFERENCE
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf "%s\n" "  (\"MSVS_PREFERENCE\" \"$VSDEV_MSVSPREFERENCE\")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "  MSVS_PREFERENCE='$VSDEV_MSVSPREFERENCE' \\"
        fi

        # Add CMAKE_GENERATOR_RECOMMENDED and CMAKE_GENERATOR_INSTANCE_RECOMMENDED
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            autodetect_compiler_VSDEV_HOME_BUILDHOST_QUOTED=$(printf "%s" "$VSDEV_HOME_BUILDHOST" | autodetect_compiler_escape_sexp)
            printf "%s\n" "  (\"CMAKE_GENERATOR_RECOMMENDED\" \"$VSDEV_CMAKEGENERATOR\")"
            printf "%s\n" "  (\"CMAKE_GENERATOR_INSTANCE_RECOMMENDED\" \"$autodetect_compiler_VSDEV_HOME_BUILDHOST_QUOTED\")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "  CMAKE_GENERATOR_RECOMMENDED='$VSDEV_CMAKEGENERATOR' \\"
            printf "%s\n" "  CMAKE_GENERATOR_INSTANCE_RECOMMENDED='$VSDEV_HOME_BUILDHOST' \\"
        fi

        # Add PATH
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            autodetect_compiler_COMPILER_PATH_WIN_QUOTED=$(printf "%s" "$autodetect_compiler_COMPILER_PATH_WIN" | autodetect_compiler_escape_sexp)
            autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH_QUOTED=$(printf "%s" "$autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH" | autodetect_compiler_escape_sexp)
            printf "%s\n" "  (\"PATH\" \"$autodetect_compiler_COMPILER_PATH_WIN_QUOTED\")"
            printf "%s\n" "  (\"PATH_COMPILER\" \"$autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH_QUOTED\")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            autodetect_compiler_COMPILER_ESCAPED_UNIX_UNIQ_PATH=$(printf "%s\n" "$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH" | autodetect_compiler_escape_envarg)
            printf "%s\n" "  PATH='$autodetect_compiler_COMPILER_ESCAPED_UNIX_UNIQ_PATH':\"\$PATH\" \\"
        fi

        # For MSVS_DETECT-only
        if [ "$autodetect_compiler_OUTPUTMODE" = MSVS_DETECT ]; then
            # MSVS_NAME
            # shellcheck disable=SC2016
            "$DKMLSYS_AWK" '
            BEGIN{FS="="} $1 == "VSCMD_VER" {name=$1; value=$0; sub(/^[^=]*=/,"",value);                print "Visual Studio " value}
            ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs1.txt
            # shellcheck disable=SC2016
            "$DKMLSYS_AWK" '
            BEGIN{FS="="}
            $1 == "VCToolsVersion" {name=$1; value=$0; sub(/^[^=]*=/,"",value);                         print "VC Tools " value}
            ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs2.txt
            # shellcheck disable=SC2016
            "$DKMLSYS_AWK" '
            BEGIN{FS="="}
            $1 == "WindowsSDKVersion" {name=$1; value=$0; sub(/^[^=]*=/,"",value); sub(/\\$/,"",value); print "Windows SDK " value}
            ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs3.txt
            # shellcheck disable=SC2016
            "$DKMLSYS_AWK" '
            BEGIN{FS="="} $1 == "VSCMD_ARG_HOST_ARCH" {name=$1; value=$0; sub(/^[^=]*=/,"",value);      print "Host " value}
            ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs4.txt
            # shellcheck disable=SC2016
            "$DKMLSYS_AWK" '
            BEGIN{FS="="} $1 == "VSCMD_ARG_TGT_ARCH" {name=$1; value=$0; sub(/^[^=]*=/,"",value);       print "Target " value}
            ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs5.txt
            autodetect_compiler_MSVS1=$(cat "$autodetect_compiler_TEMPDIR"/msvs1.txt)
            autodetect_compiler_MSVS2=$(cat "$autodetect_compiler_TEMPDIR"/msvs2.txt)
            autodetect_compiler_MSVS3=$(cat "$autodetect_compiler_TEMPDIR"/msvs3.txt)
            autodetect_compiler_MSVS4=$(cat "$autodetect_compiler_TEMPDIR"/msvs4.txt)
            autodetect_compiler_MSVS5=$(cat "$autodetect_compiler_TEMPDIR"/msvs5.txt)
            printf "MSVS_NAME='%s %s %s %s %s in %s'\n" "$autodetect_compiler_MSVS1" \
                "$autodetect_compiler_MSVS4" "$autodetect_compiler_MSVS5" \
                "$autodetect_compiler_MSVS2" "$autodetect_compiler_MSVS3" "$VSDEV_HOME_BUILDHOST"

            # MSVS_PATH which must be in Unix PATH format with a trailing colon
            if [ ! -x /usr/bin/cygpath ]; then
                echo "FATAL: No /usr/bin/cygpath which is needed for MSVS_PATH variable" >&2
                exit 107
            fi
            printf "MSVS_PATH='%s:'\n" "$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH"

            # MSVS_INC which must have a trailing semicolon
            # shellcheck disable=SC2016
            "$DKMLSYS_AWK" -v singlequote="'" '
            BEGIN{FS="="} $1 == "INCLUDE" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print "MSVS_INC=" singlequote value ";" singlequote}
            ' "$autodetect_compiler_TEMPDIR"/vcvars.txt

            # MSVS_LIB which must have a trailing semicolon
            # shellcheck disable=SC2016
            "$DKMLSYS_AWK" -v singlequote="'" '
            BEGIN{FS="="} $1 == "LIB" {name=$1; value=$0; sub(/^[^=]*=/,"",value);     print "MSVS_LIB=" singlequote value ";" singlequote}
            ' "$autodetect_compiler_TEMPDIR"/vcvars.txt

            # MSVS_ML
            printf "MSVS_ML='%s'\n" "$autodetect_compiler_vsdev_MSVS_ML"
        fi

        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf ")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            # Add arguments
            printf "%s\n" '  "$@"'
        elif [ "$autodetect_compiler_OUTPUTMODE" = MSVS_DETECT ]; then
            # Dump variables to standard output with proper quoting (which `set` does for us)
            printf "set | awk '%s'\n" '/^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=/{print}'
        fi
    } > "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_CHMOD" +x "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_MV" "$autodetect_compiler_OUTPUTFILE".tmp "$autodetect_compiler_OUTPUTFILE"
}

# A function that will execute the shell command with error detection enabled and trace
# it on standard error if DKML_BUILD_TRACE=ON (which is default)
#
# Output:
#   - env:DKML_POSIX_SHELL - The path to the POSIX shell. Only set if it wasn't already
#     set.
log_shell() {
    autodetect_system_binaries
    autodetect_posix_shell
    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then
        printf "%s\n" "@+ $DKML_POSIX_SHELL $*" >&2
        # If trace level > 2 and the first argument is a _non binary_ file then print contents
        if [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ] && [ -e "$1" ] && "$DKMLSYS_GREP" -qI . "$1"; then
            log_shell_1="$1"
            shift
            # print args with prefix ... @+:
            escape_args_for_shell "$@" | "$DKMLSYS_SED" 's/^/@+: /' >&2
            printf "\n" >&2
            # print file with prefix ... @+| . Also make sure each line is newline terminated using awk.
            "$DKMLSYS_SED" 's/^/@+| /' "$log_shell_1" | "$DKMLSYS_AWK" '{print}' >&2
            "$DKML_POSIX_SHELL" -eufx "$log_shell_1" "$@"
        else
            "$DKML_POSIX_SHELL" -eufx "$@"
        fi
    else
        "$DKML_POSIX_SHELL" -euf "$@"
    fi
}

# A function that will print the command and possibly time it (if and only if it uses a full path to
# an executable, so that 'time' does not fail on internal shell functions).
# If --return-error-code is the first argument or LOG_TRACE_RETURN_ERROR_CODE=ON, then instead of exiting the
# function will return the error code.
log_trace() {
    log_trace_RETURN=${LOG_TRACE_RETURN_ERROR_CODE:-OFF}

    log_trace_1="$1"
    if [ "$log_trace_1" = "--return-error-code" ]; then
        shift
        log_trace_RETURN=ON
    fi

    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then
        printf "%s\n" "+ $*" >&2
        if [ -x "$1" ]; then
            time "$@"
        else
            "$@"
        fi
    else
        "$@"
    fi
    log_trace_ec="$?"
    if [ "$log_trace_ec" -ne 0 ]; then
        if [ "$log_trace_RETURN" = ON ]; then
            return "$log_trace_ec"
        else
            printf "FATAL: Command failed with exit code %s: %s\n" "$log_trace_ec" "$*"
            exit "$log_trace_ec"
        fi
    fi
}

# [sha256compute FILE] writes the SHA256 checksum (hex encoded) of file FILE to the standard output.
sha256compute() {
    sha256compute_FILE="$1"
    shift
    if [ -x /usr/bin/shasum ]; then
        /usr/bin/shasum -a 256 "$sha256compute_FILE" | awk '{print $1}'
    elif [ -x /usr/bin/sha256sum ]; then
        /usr/bin/sha256sum "$sha256compute_FILE" | awk '{print $1}'
    else
        printf "FATAL: %s\n" "No sha256 checksum utility found" >&2
        exit 107
    fi
}

# [sha256check FILE SUM] checks that the file FILE has a SHA256 checksum (hex encoded) of SUM.
# The function will return nonzero (and exit with failure if `set -e` is enabled) if the checksum does not match.
sha256check() {
    sha256check_FILE="$1"
    shift
    sha256check_SUM="$1"
    shift
    if [ -x /usr/bin/shasum ]; then
        printf "%s  %s" "$sha256check_SUM" "$sha256check_FILE" | /usr/bin/shasum -a 256 -c
    elif [ -x /usr/bin/sha256sum ]; then
        printf "%s  %s" "$sha256check_SUM" "$sha256check_FILE" | /usr/bin/sha256sum -c
    else
        printf "FATAL: %s\n" "No sha256 checksum utility found" >&2
        exit 107
    fi
}

# [downloadfile URL FILE SUM] downloads from URL into FILE and verifies the SHA256 checksum of SUM.
# If the FILE already exists with the correct checksum it is not redownloaded.
# The function will exit with failure if the checksum does not match.
downloadfile() {
    downloadfile_URL="$1"
    shift
    downloadfile_FILE="$1"
    shift
    downloadfile_SUM="$1"
    shift

    # Set DKMLSYS_*
    autodetect_system_binaries

    if [ -e "$downloadfile_FILE" ]; then
        if sha256check "$downloadfile_FILE" "$downloadfile_SUM"; then
            return 0
        else
            $DKMLSYS_RM -f "$downloadfile_FILE"
        fi
    fi
    if [ "${CI:-}" = true ]; then
        log_trace "$DKMLSYS_CURL" -L -s "$downloadfile_URL" -o "$downloadfile_FILE".tmp
    else
        log_trace "$DKMLSYS_CURL" -L "$downloadfile_URL" -o "$downloadfile_FILE".tmp
    fi
    if ! sha256check "$downloadfile_FILE".tmp "$downloadfile_SUM"; then
        printf "%s\n" "FATAL: Encountered a corrupted or compromised download from $downloadfile_URL" >&2
        exit 1
    fi
    $DKMLSYS_MV "$downloadfile_FILE".tmp "$downloadfile_FILE"
}

cmake_flag_on() {
    # Definition at https://cmake.org/cmake/help/latest/command/if.html#basic-expressions
    case "$1" in
        1|ON|On|on|YES|Yes|yes|TRUE|True|true|Y|y|1*|2*|3*|4*|5*|6*|7*|8*|9*) return 0 ;;
        *) return 1 ;;
    esac
}

cmake_flag_off() {
    # Definition at https://cmake.org/cmake/help/latest/command/if.html#basic-expressions
    case "$1" in
        1|ON|On|on|YES|Yes|yes|TRUE|True|true|Y|y|1*|2*|3*|4*|5*|6*|7*|8*|9*) return 1 ;;
        *) return 0 ;;
    esac
}

# DEPRECATED
#
# [escape_string_for_shell STR] takes the string STR and escapes it for use in a shell.
# For example,
#  in Bash: STR="hello singlequote=' doublequote=\" world" --> 'hello singlequote='\'' doublequote=" world'
#  in Dash: STR="hello singlequote=' doublequote=\" world" --> 'hello singlequote='"'"' doublequote=" world'
#
# (deprecated) Use escape_args_for_shell() instead
escape_string_for_shell() {
    # shellcheck disable=SC2034
    escape_string_for_shell_STR="$1"
    shift
    # We'll use the bash or dash builtin `set` which escapes spaces and quotes correctly.
    set | grep ^escape_string_for_shell_STR= | sed 's/[^=]*=//'
}

# escape_args_for_shell ARG1 ARG2 ...
#
# If `escape_args_for_shell asd sdfs 'hello there'` then prints `asd sdfs hello\ there`
#
# Prereq: autodetect_system_binaries
escape_args_for_shell() {
    # Confer %q in https://www.gnu.org/software/bash/manual/bash.html#Shell-Builtin-Commands
    bash -c 'printf "%q " "$@"' -- "$@" | $DKMLSYS_SED 's/ $//'
}

# Make the standard input embeddable in single quotes
# (ex. <stdin>=hi ' there ==> <stdout>=hi '"'"' there).
# That is, replace single quotes (') with ('"'"').
#
# It is your responsibility to place outer single quotes around the stdout.
#
# Prereq: autodetect_system_binaries
escape_stdin_for_single_quote() {
    "$DKMLSYS_SED" "s#'#'\"'\"'#g"
}

# Make the standard input work as an OCaml string.
#
# This currently only escapes backslashes and double quotes.
#
# Prereq: autodetect_system_binaries
escape_arg_as_ocaml_string() {
    escape_arg_as_ocaml_string_ARG=$1
    shift
    printf "%s" "$escape_arg_as_ocaml_string_ARG" | "$DKMLSYS_SED" 's#\\#\\\\#g; s#"#\\"#g;'
}

# Convert a path into an absolute path appropriate for the build host machine. That is, Windows
# paths for a Windows host machine and Unix paths for Unix host machines.
#
# Output:
#  env:buildhost_pathize_RETVAL - The absolute path
buildhost_pathize() {
    buildhost_pathize_PATH="$1"
    shift
    if [ -x /usr/bin/cygpath ]; then
        # Trim any trailing backslash because `cygpath -aw .` gives us trailing slash
        buildhost_pathize_RETVAL=$(/usr/bin/cygpath -aw "$buildhost_pathize_PATH" | sed 's#\\$##')
    else
        case "$buildhost_pathize_PATH" in
            /*)
                buildhost_pathize_RETVAL="$buildhost_pathize_PATH" ;;
            ?:*)
                # ex. C:\Windows
                buildhost_pathize_RETVAL="$buildhost_pathize_PATH" ;;
            *)
                # shellcheck disable=SC2034
                buildhost_pathize_RETVAL="$PWD/$buildhost_pathize_PATH" ;;
        esac
    fi
}

# [system_tar ARGS] runs the `tar` command with a system PATH and logging
system_tar() {
    # Set DKML_SYSTEM_PATH
    autodetect_system_path

    PATH=$DKML_SYSTEM_PATH log_trace tar "$@"
}

# [autodetect_system_powershell]
# Outputs:
# - env:DKML_SYSTEM_POWERSHELL
# Return Code: 0 if found, 1 if not found
autodetect_system_powershell() {
    # Set DKML_SYSTEM_PATH (which will include legacy `powershell.exe` if it exists)
    autodetect_system_path

    # Try pwsh first
    system_powershell_PWSH=$(PATH="$DKML_SYSTEM_PATH" command -v pwsh || true)
    if [ -n "$system_powershell_PWSH" ]; then
        DKML_SYSTEM_POWERSHELL="$system_powershell_PWSH"
        return 0
    fi

    # Then powershell first
    system_powershell_POWERSHELL=$(PATH="$DKML_SYSTEM_PATH" command -v powershell || true)
    if [ -n "$system_powershell_POWERSHELL" ]; then
        # shellcheck disable=SC2034
        DKML_SYSTEM_POWERSHELL="$system_powershell_POWERSHELL"
        return 0
    fi

    return 1
}

# [system_powershell ARGS] runs `pwsh` or `powershell` with a system PATH and logging
system_powershell() {
    # Set DKML_SYSTEM_PATH (which will include legacy `powershell.exe` if it exists)
    autodetect_system_path

    # Set DKML_SYSTEM_POWERSHELL
    if ! autodetect_system_powershell; then
        printf "FATAL: No pwsh or powershell available in the system PATH %s\n" "$DKML_SYSTEM_PATH" >&2
        exit 107
    fi

    PATH="$DKML_SYSTEM_PATH" log_trace "$DKML_SYSTEM_POWERSHELL" "$@"
}
