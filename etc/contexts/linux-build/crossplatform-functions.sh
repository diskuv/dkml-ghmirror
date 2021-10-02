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

export SHARE_OCAML_OPAM_REPO_RELPATH=share/diskuv-ocaml/ocaml-opam-repo
export SHARE_REPRODUCIBLE_BUILD_RELPATH=share/diskuv-ocaml/reproducible-builds

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
    elif [ -e /bin/dash ]; then
        DKML_POSIX_SHELL=/bin/dash
    else
        DKML_POSIX_SHELL=/bin/sh
    fi
    if [ -x /usr/bin/cygpath ]; then
        DKML_HOST_POSIX_SHELL=$(/usr/bin/cygpath -aw "$DKML_POSIX_SHELL")
    else
        DKML_HOST_POSIX_SHELL="$DKML_POSIX_SHELL"
    fi
}

# A function that will execute the shell command with error detection enabled and trace
# it on standard error if DKML_BUILD_TRACE=ON (which is default)
#
# Output:
#   - env:DKML_POSIX_SHELL - The path to the POSIX shell. Only set if it wasn't already
#     set.
log_shell() {
    if [ -z "${DKML_POSIX_SHELL:-}" ]; then
        autodetect_posix_shell
    fi
    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then
        printf "%s\n" "@+ $DKML_POSIX_SHELL $*" >&2
        "$DKML_POSIX_SHELL" -eufx "$@"
    else
        "$DKML_POSIX_SHELL" -euf "$@"
    fi
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

is_arg_windows_platform() {
    case "$1" in
        windows_x86)    return 0;;
        windows_x86_64) return 0;;
        dev)            if is_unixy_windows_build_machine; then return 0; else return 1; fi ;;
        *)              return 1;;
    esac
}

# Install files that will always be in a reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 100-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
install_reproducible_common() {
    install_reproducible_common_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$install_reproducible_common_BOOTSTRAPDIR"
    install_reproducible_file .dkmlroot
    install_reproducible_file installtime/none/emptytop/dune-project
    install_reproducible_file etc/contexts/linux-build/crossplatform-functions.sh
    install_reproducible_file runtime/unix/_common_tool.sh
}

# Install any non-common files that go into your reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 100-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the script that will be installed.
#       It will be deployed relative to $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
install_reproducible_file() {
    _install_reproducible_file_RELFILE="$1"
    shift
    _install_reproducible_file_RELDIR=$(dirname "$_install_reproducible_file_RELFILE")
    _install_reproducible_file_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
    install "$DKMLDIR"/"$_install_reproducible_file_RELFILE" "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
}

# Install any deterministically generated files that go into your
# reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 100-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path to the generated script.
#  $2 - The location of the script that will be installed.
#       It must be specified relative to $DEPLOYDIR_UNIX.
install_reproducible_generated_file() {
    install_reproducible_generated_file_SRCFILE="$1"
    shift
    install_reproducible_generated_file_RELFILE="$1"
    shift
    install_reproducible_generated_file_RELDIR=$(dirname "$install_reproducible_generated_file_RELFILE")
    install_reproducible_generated_file_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELDIR"/
    rm -f "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELFILE" # ensure if exists it is a regular file or link but not a directory
    install "$install_reproducible_generated_file_SRCFILE" "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELFILE"
}

# Install a README.md file that go into your reproducible build.
#
# The @@BOOTSTRAPDIR_UNIX@@ is a macro you can use inside the Markdown file
# which will be replaced with the relative path to the BOOTSTRAPNAME folder;
# it will have a trailing slash.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 100-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the .md file that will be installed.
#       It will be deployed as 'README.md' in the bootstrap folder of $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
install_reproducible_readme() {
    install_reproducible_readme_RELFILE="$1"
    shift
    install_reproducible_readme_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$install_reproducible_readme_BOOTSTRAPDIR"
    sed "s,@@BOOTSTRAPDIR_UNIX@@,$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME/,g" "$DKMLDIR"/"$install_reproducible_readme_RELFILE" > "$install_reproducible_readme_BOOTSTRAPDIR"/README.md
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
    printf "%s" "$change_suffix_TEXT" | awk -v REPLACE="$change_suffix_NEW_SUFFIX" "{ gsub(/$change_suffix_OLD_SUFFIX/,REPLACE); print }"
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
    replace_all_TEXT="$1"
    shift
    replace_all_SEARCH="$1"
    shift
    replace_all_REPLACE="$1"
    shift
    replace_all_REPLACE=$(printf "%s" "$replace_all_REPLACE" | sed 's#\\#\\\\#g') # escape all backslashes for awk
    printf "%s" "$replace_all_TEXT" | awk -v REPLACE="$replace_all_REPLACE" "{ gsub(/$replace_all_SEARCH/,REPLACE); print }"
}

# Install a script that can re-install necessary system packages.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 100-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the script that will be created, relative to $DEPLOYDIR_UNIX.
#       Must end with `.sh`.
#  $@ - All remaining arguments are how to invoke the run script ($1).
install_reproducible_system_packages() {
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
    install -d "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTDIR"/

    if is_msys2_msys_build_machine; then
        # https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#List_of_installed_packages
        pacman -Qqet > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        printf "#!/usr/bin/env bash\nexec pacman -S \"\$@\" --needed - < '%s'\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE" > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif is_cygwin_build_machine; then
        cygcheck.exe -c -d > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            printf "%s\n" "#!/usr/bin/env bash"
            printf "%s\n" "if [ ! -e /usr/local/bin/cyg-get ]; then wget -O /usr/local/bin/cyg-get 'https://gitlab.com/cogline.v3/cygwin/-/raw/2049faf4b565af81937d952292f8ae5008d38765/cyg-get?inline=false'; fi"
            printf "%s\n" "if [ ! -x /usr/local/bin/cyg-get ]; then chmod +x /usr/local/bin/cyg-get; fi"
            printf "readarray -t pkgs < <(awk 'display==1{print \$1} \$1==\"Package\"{display=1}' '%s')\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE"
            # shellcheck disable=SC2016
            printf "%s\n" 'set -x ; /usr/local/bin/cyg-get install ${pkgs[@]}'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    else
        printf "%s\n" "TODO: install_reproducible_system_packages for non-Windows platforms" >&2
        exit 1
    fi
    chmod 755 "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
}

# Install a script that can relaunch itself in a relocated position.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 100-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the pre-existing script that should be run.
#       It will be deployed relative to $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
#       Must end with `.sh`.
#  $@ - All remaining arguments are how to invoke the run script ($1).
install_reproducible_script_with_args() {
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
    install -d "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEDIR"/
    printf "#!/usr/bin/env bash\nexec env TOPDIR=\"\$PWD/%s/installtime/none/emptytop\" %s %s\n" \
        "$install_reproducible_script_with_args_BOOTSTRAPRELDIR" \
        "$install_reproducible_script_with_args_BOOTSTRAPRELDIR/$install_reproducible_script_with_args_SCRIPTFILE" \
        "$*" > "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEFILE"
    chmod 755 "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEFILE"
}

# Tries to find the ARCH (defined in TOPDIR/Makefile corresponding to the build machine)
# For now only tested in Linux/Windows x86/x86_64.
# Outputs:
# - env:BUILDHOST_ARCH will contain the correct ARCH
build_machine_arch() {
    build_machine_arch_MACHINE=$(uname -m)
    build_machine_arch_SYSTEM=$(uname -s)
    # list from https://en.wikipedia.org/wiki/Uname and https://stackoverflow.com/questions/45125516/possible-values-for-uname-m
    case "${build_machine_arch_SYSTEM}-${build_machine_arch_MACHINE}" in
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
                printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $build_machine_arch_SYSTEM and $build_machine_arch_MACHINE" >&2
                exit 1
            fi
            ;;
        *-x86_64)
            if is_unixy_windows_build_machine; then
                BUILDHOST_ARCH=windows_x86_64
            else
                printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $build_machine_arch_SYSTEM and $build_machine_arch_MACHINE" >&2
                exit 1
            fi
            ;;
        *)
            printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $build_machine_arch_SYSTEM and $build_machine_arch_MACHINE" >&2
            exit 1
            ;;
    esac
}

# Tries to find the VCPKG_TRIPLET (defined in TOPDIR/Makefile corresponding to the build machine)
# For now only tested in Linux/Windows x86/x86_64.
# Inputs:
# - env:PLATFORM
# Outputs:
# - env:BUILDHOST_ARCH will contain the correct ARCH
# - env:PLATFORM_VCPKG_TRIPLET will contain the correct vcpkg triplet
platform_vcpkg_triplet() {
    build_machine_arch
    export PLATFORM_VCPKG_TRIPLET
    # TODO: This static list is brittle. Should parse the Makefile or better yet
    # place in a different file that can be used by this script and the Makefile.
    # In fact, the list we should be using is base.mk:VCPKG_TRIPLET_*
    case "$PLATFORM-$BUILDHOST_ARCH" in
        dev-windows_x86)      PLATFORM_VCPKG_TRIPLET=x86-windows ;;
        dev-windows_x86_64)   PLATFORM_VCPKG_TRIPLET=x64-windows ;;
        dev-linux_x86)        PLATFORM_VCPKG_TRIPLET=x86-linux ;;
        dev-linux_x86_64)     PLATFORM_VCPKG_TRIPLET=x64-linux ;;
        # See base.mk:DKML_PLATFORMS for why OS/X triplet is chosen rather than iOS (which would be dev-darwin_arm64_iosdevice)
        # Caution: arm64-osx and arm64-ios triplets are Community supported. https://github.com/microsoft/vcpkg/tree/master/triplets/community
        # and https://github.com/microsoft/vcpkg/issues/12258 .
        dev-darwin_arm64)     PLATFORM_VCPKG_TRIPLET=arm64-osx ;;
        dev-darwin_x86_64)    PLATFORM_VCPKG_TRIPLET=x64-osx ;;
        windows_x86-*)        PLATFORM_VCPKG_TRIPLET=x86-windows ;;
        windows_x86_64-*)     PLATFORM_VCPKG_TRIPLET=x64-windows ;;
        *)
            printf "%s\n" "FATAL: Unsupported vcpkg triplet for PLATFORM-BUILDHOST_ARCH: $PLATFORM-$BUILDHOST_ARCH" >&2
            exit 1
            ;;
    esac
}

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

# Get the number of CPUs available.
#
# Inputs:
# - env:NUMCPUS. Optional. If set, no autodetection occurs.
# Outputs:
# - env:NUMCPUS . Maximum of 8 if detectable; otherwise 1. Always a number from 1 to 8, even
#   if on input env:NUMCPUS was set to text.
autodetect_cpus() {
    # initialize to 0 if not set
    if [ -z "${NUMCPUS:-}" ]; then
        NUMCPUS=0
    fi
    # type cast to a number (in case user gave a string)
    NUMCPUS=$(( NUMCPUS + 0 ))
    if [ "${NUMCPUS}" -eq 0 ]; then
        NUMCPUS=1
        if [ -n "${NUMBER_OF_PROCESSORS:-}" ]; then
            # Windows usually has NUMBER_OF_PROCESSORS
            NUMCPUS="$NUMBER_OF_PROCESSORS"
        elif nproc --all > "$WORK"/numcpus 2>/dev/null && [ -s "$WORK"/numcpus ]; then
            NUMCPUS=$(cat "$WORK"/numcpus)
        fi
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

# Detects a compiler like Visual Studio and sets its variables.
# autodetect_compiler OUT_LAUNCHER.sh [EXTRA_PREFIX]
#
# Includes EXTRA_PREFIX as a prefix for /include and and /lib library subpaths.
#
# Example:
#  autodetect_compiler /tmp/launcher.sh && /tmp/launcher.sh cl.exe /help
#  autodetect_compiler /tmp/launcher.sh /usr/local && /tmp/launcher.sh DEBUG=1 cl.exe /help
#
# The generated launcher.sh behaves like a `env` command. You may place environment variable
# definitions before your target executable. Also you may use `-u name` to unset an environment
# variable. In fact, if there is no compiler detected than the generated launcher.sh is simply
# a file containing the line `exec env "$@"`
#
# Inputs:
# - $1 - Optional. If provided, then $1/include and $1/lib are added to INCLUDE and LIB, respectively
# - env:PLATFORM - Optional; if missing treated as 'dev'. This variable will select the Visual Studio
#   options necessary to cross-compile (or native compile) to the target PLATFORM. 'dev' is always
#   a native compilation.
# - env:WORK - Optional. If provided will be used as temporary directory
# - env:DKML_VSSTUDIO_DIR - Optional. If provided with all three (3) DKML_VSSTUDIO_* variables the
#   specified installation directory of Visual Studio will be used.
#   The directory should contain VC and Common7 subfolders.
# - env:DKML_VSSTUDIO_VCVARSVER - Optional. If provided it must be a version that can locate the Visual Studio
#   installation in DKML_VSSTUDIO_DIR when `vsdevcmd.bat -vcvars_ver=VERSION` is invoked. Example: `14.26`
# - env:DKML_VSSTUDIO_WINSDKVER - Optional. If provided it must be a version that can locate the Windows SDK
#   kit when `vsdevcmd.bat -winsdk=VERSION` is invoked. Example: `10.0.18362.0`
# - env:DKML_VSSTUDIO_MSVSPREFERENCE - Optional. If provided it must be a MSVS_PREFERENCE environment variable
#   value that can locate the Visual Studio installation in DKML_VSSTUDIO_DIR when
#   https://github.com/metastack/msvs-tools's or Opam's `msvs-detect` is invoked. Example: `VS16.6`
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:BUILDHOST_ARCH will contain the correct ARCH
# - env:OCAML_HOST_TRIPLET is non-empty if `--host OCAML_HOST_TRIPLET` should be passed to OCaml's ./configure script when
#   compiling OCaml. Aligns with the PLATFORM variable that was specified, especially for cross-compilation.
# - env:VSDEV_HOME_UNIX is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Empty otherwise
# - env:VSDEV_HOME_WINDOWS is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Empty otherwise
# Return Values:
# - 0: Success
# - 1: Windows machine without proper Diskuv OCaml installation (typically you should exit fatally)
autodetect_compiler() {
    autodetect_compiler_LAUNCHER="$1"
    shift
    autodetect_compiler_TEMPDIR=${WORK:-$TMP}
    autodetect_compiler_PLATFORM_ARCH=${PLATFORM:-dev}

    # Set DKML_POSIX_SHELL if not already set
    autodetect_posix_shell

    # Initialize output script and variables in case of failure
    printf '#!%s\nexec env "$@"\n' "$DKML_POSIX_SHELL" > "$autodetect_compiler_LAUNCHER".tmp
    chmod +x "$autodetect_compiler_LAUNCHER".tmp
    mv "$autodetect_compiler_LAUNCHER".tmp "$autodetect_compiler_LAUNCHER"
    export VSDEV_HOME_UNIX=
    export VSDEV_HOME_WINDOWS=

    # Host triplet:
    #   (TODO: Better link)
    #   https://gitlab.com/diskuv/diskuv-ocaml/-/blob/aabf3171af67a0a0ff4779c336867a7a43e3670f/etc/opam-repositories/diskuv-opam-repo/packages/ocaml-variants/ocaml-variants.4.12.0+options+dkml+msvc64/opam#L52-62
    export OCAML_HOST_TRIPLET=

    # Get the extra prefix with backslashes escaped for Awk, if specified
    if [ "$#" -ge 1 ]; then
        autodetect_compiler_EXTRA_PREFIX_ESCAPED="$1"
        if [ -x /usr/bin/cygpath ]; then autodetect_compiler_EXTRA_PREFIX_ESCAPED=$(/usr/bin/cygpath -aw "$autodetect_compiler_EXTRA_PREFIX_ESCAPED"); fi
        autodetect_compiler_EXTRA_PREFIX_ESCAPED=$(printf "%s\n" "${autodetect_compiler_EXTRA_PREFIX_ESCAPED}" | sed 's#\\#\\\\#g')
        shift
    else
        autodetect_compiler_EXTRA_PREFIX_ESCAPED=""
    fi

    # Set DKMLPARENTHOME_BUILDHOST
    set_dkmlparenthomedir

    # Autodetect BUILDHOST_ARCH
    build_machine_arch
    if [ "$BUILDHOST_ARCH" != windows_x86 ] && [ "$BUILDHOST_ARCH" != windows_x86_64 ]; then
        return 0
    fi

    # Set VSDEV_HOME_*
    if [ -n "${DKML_VSSTUDIO_DIR:-}" ] && [ -n "${DKML_VSSTUDIO_VCVARSVER:-}" ] && [ -n "${DKML_VSSTUDIO_WINSDKVER:-}" ] && [ -n "${DKML_VSSTUDIO_MSVSPREFERENCE:-}" ]; then
        autodetect_compiler_VSSTUDIODIR=$DKML_VSSTUDIO_DIR
        autodetect_compiler_VSSTUDIOVCVARSVER=$DKML_VSSTUDIO_VCVARSVER
        autodetect_compiler_VSSTUDIOWINSDKVER=$DKML_VSSTUDIO_WINSDKVER
        autodetect_compiler_VSSTUDIOMSVSPREFERENCE=$DKML_VSSTUDIO_MSVSPREFERENCE
    else
        autodetect_compiler_VSSTUDIO_DIRFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.dir.txt"
        if [ ! -e "$autodetect_compiler_VSSTUDIO_DIRFILE" ]; then
            return 1
        fi
        autodetect_compiler_VSSTUDIO_VCVARSVERFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.vcvars_ver.txt"
        if [ ! -e "$autodetect_compiler_VSSTUDIO_VCVARSVERFILE" ]; then
            return 1
        fi
        autodetect_compiler_VSSTUDIO_WINSDKVERFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.winsdk.txt"
        if [ ! -e "$autodetect_compiler_VSSTUDIO_WINSDKVERFILE" ]; then
            return 1
        fi
        autodetect_compiler_VSSTUDIO_MSVSPREFERENCEFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.msvs_preference.txt"
        if [ ! -e "$autodetect_compiler_VSSTUDIO_MSVSPREFERENCEFILE" ]; then
            return 1
        fi
        autodetect_compiler_VSSTUDIODIR=$(awk 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_compiler_VSSTUDIO_DIRFILE")
        autodetect_compiler_VSSTUDIOVCVARSVER=$(awk 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_compiler_VSSTUDIO_VCVARSVERFILE")
        autodetect_compiler_VSSTUDIOWINSDKVER=$(awk 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_compiler_VSSTUDIO_WINSDKVERFILE")
        autodetect_compiler_VSSTUDIOMSVSPREFERENCE=$(awk 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_compiler_VSSTUDIO_MSVSPREFERENCEFILE")
    fi
    if [ -x /usr/bin/cygpath ]; then
        autodetect_compiler_VSSTUDIODIR=$(/usr/bin/cygpath -au "$autodetect_compiler_VSSTUDIODIR")
    fi
    VSDEV_HOME_UNIX="$autodetect_compiler_VSSTUDIODIR"
    if [ -x /usr/bin/cygpath ]; then
        VSDEV_HOME_WINDOWS=$(/usr/bin/cygpath -aw "$VSDEV_HOME_UNIX")
    else
        VSDEV_HOME_WINDOWS="$VSDEV_HOME_UNIX"
    fi

    # MSYS2 detection.
    # The vsdevcmd.bat is at /c/DiskuvOCaml/BuildTools/Common7/Tools/VsDevCmd.bat.
    if [ -e "$autodetect_compiler_VSSTUDIODIR"/Common7/Tools/VsDevCmd.bat ]; then
        autodetect_compiler_VSDEVCMD="$autodetect_compiler_VSSTUDIODIR/Common7/Tools/VsDevCmd.bat"
    else
        return 1
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
        printf "set > %s%s%s%s\n" '"' "$autodetect_compiler_TEMPDIR_WIN" '\vcvars.txt' '"'
    } > "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat

    # SECOND, construct a function that will call Microsoft's vsdevcmd.bat script.
    if   [ "${DKML_BUILD_TRACE:-ON}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" = 4 ]; then
        autodetect_compiler_VSCMD_DEBUG=3
    elif [ "${DKML_BUILD_TRACE:-ON}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" = 3 ]; then
        autodetect_compiler_VSCMD_DEBUG=2
    elif [ "${DKML_BUILD_TRACE:-ON}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" = 2 ]; then
        autodetect_compiler_VSCMD_DEBUG=1
    else
        autodetect_compiler_VSCMD_DEBUG=
    fi
    if [ -x /usr/bin/cygpath ]; then
        PATH_UNIX=$(/usr/bin/cygpath --path "$PATH")
    else
        PATH_UNIX="$PATH"
    fi
    # https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-160#vcvarsall-syntax
    if [ "$BUILDHOST_ARCH" = windows_x86 ]; then
        # The build host machine is 32-bit ...
        if [ "$autodetect_compiler_PLATFORM_ARCH" = dev ] || [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86 ]; then
            autodetect_compiler_vsdev_dump_vars() {
                env PATH="$PATH_UNIX" __VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1 VSCMD_DEBUG="$autodetect_compiler_VSCMD_DEBUG" \
                    "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat -no_logo -vcvars_ver="$autodetect_compiler_VSSTUDIOVCVARSVER" -winsdk="$autodetect_compiler_VSSTUDIOWINSDKVER" \
                    -arch=x86 >&2
            }
            OCAML_HOST_TRIPLET=i686-pc-windows
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86_64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                env PATH="$PATH_UNIX" __VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1 VSCMD_DEBUG="$autodetect_compiler_VSCMD_DEBUG" \
                    "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat -no_logo -vcvars_ver="$autodetect_compiler_VSSTUDIOVCVARSVER" -winsdk="$autodetect_compiler_VSSTUDIOWINSDKVER" \
                    -host_arch=x86 -arch=x64 >&2
            }
            OCAML_HOST_TRIPLET=x86_64-pc-windows
        else
            printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
            exit 1
        fi
    elif [ "$BUILDHOST_ARCH" = windows_x86_64 ]; then
        # The build host machine is 64-bit ...
        if [ "$autodetect_compiler_PLATFORM_ARCH" = dev ] || [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86_64 ]; then
            autodetect_compiler_vsdev_dump_vars() {
                env PATH="$PATH_UNIX" __VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1 VSCMD_DEBUG="$autodetect_compiler_VSCMD_DEBUG" \
                    "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat -no_logo -vcvars_ver="$autodetect_compiler_VSSTUDIOVCVARSVER" -winsdk="$autodetect_compiler_VSSTUDIOWINSDKVER" \
                    -arch=x64 >&2
            }
            OCAML_HOST_TRIPLET=x86_64-pc-windows
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                env PATH="$PATH_UNIX" __VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1 VSCMD_DEBUG="$autodetect_compiler_VSCMD_DEBUG" \
                    "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat -no_logo -vcvars_ver="$autodetect_compiler_VSSTUDIOVCVARSVER" -winsdk="$autodetect_compiler_VSSTUDIOWINSDKVER" \
                    -host_arch=x64 -arch=x86 >&2
            }
            OCAML_HOST_TRIPLET=i686-pc-windows
        else
            printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
            exit 1
        fi
    else
        printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
        exit 1
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
    if [ -n "${autodetect_compiler_EXTRA_PREFIX_ESCAPED:-}" ]; then
        autodetect_compiler_VCPKG_PREFIX_INCLUDE_ESCAPED="$autodetect_compiler_EXTRA_PREFIX_ESCAPED\\\\include;"
        autodetect_compiler_VCPKG_PREFIX_LIB_ESCAPED="$autodetect_compiler_EXTRA_PREFIX_ESCAPED\\\\lib;"
    else
        autodetect_compiler_VCPKG_PREFIX_INCLUDE_ESCAPED=""
        autodetect_compiler_VCPKG_PREFIX_LIB_ESCAPED=""
    fi
    awk \
        -v VCPKG_PREFIX_INCLUDE="$autodetect_compiler_VCPKG_PREFIX_INCLUDE_ESCAPED" \
        -v VCPKG_PREFIX_LIB="$autodetect_compiler_VCPKG_PREFIX_LIB_ESCAPED" '
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

    $1 == "INCLUDE" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" VCPKG_PREFIX_INCLUDE value}
    $1 == "LIB" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" VCPKG_PREFIX_LIB value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/mostvars.eval.sh

    # FIFTH, set autodetect_compiler_COMPILER_PATH to the provided PATH
    awk '
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
    autodetect_compiler_COMPILER_PATH=$(cat "$autodetect_compiler_TEMPDIR"/unixpath.txt)

    # SIXTH, set autodetect_compiler_COMPILER_UNIQ_PATH so that it is only the _unique_ entries
    # (the set {autodetect_compiler_COMPILER_UNIQ_PATH} - {PATH}) are used. But maintain the order
    # that Microsoft places each path entry.
    printf "%s\n" "$autodetect_compiler_COMPILER_PATH" | awk 'BEGIN{RS=":"} {print}' > "$autodetect_compiler_TEMPDIR"/vcvars_entries.txt
    sort -u "$autodetect_compiler_TEMPDIR"/vcvars_entries.txt > "$autodetect_compiler_TEMPDIR"/vcvars_entries.sortuniq.txt
    printf "%s\n" "$PATH" | awk 'BEGIN{RS=":"} {print}' | sort -u > "$autodetect_compiler_TEMPDIR"/path.sortuniq.txt
    comm \
        -23 \
        "$autodetect_compiler_TEMPDIR"/vcvars_entries.sortuniq.txt \
        "$autodetect_compiler_TEMPDIR"/path.sortuniq.txt \
        > "$autodetect_compiler_TEMPDIR"/vcvars_uniq.txt
    autodetect_compiler_COMPILER_UNIQ_PATH=
    while IFS='' read -r autodetect_compiler_line; do
        # if and only if the $autodetect_compiler_line matches one of the lines in vcvars_uniq.txt
        if ! printf "%s\n" "$autodetect_compiler_line" | comm -12 - "$autodetect_compiler_TEMPDIR"/vcvars_uniq.txt | awk 'NF>0{exit 1}'; then
            if [ -z "$autodetect_compiler_COMPILER_UNIQ_PATH" ]; then
                autodetect_compiler_COMPILER_UNIQ_PATH="$autodetect_compiler_line"
            else
                autodetect_compiler_COMPILER_UNIQ_PATH="$autodetect_compiler_COMPILER_UNIQ_PATH:$autodetect_compiler_line"
            fi
        fi
    done < "$autodetect_compiler_TEMPDIR"/vcvars_entries.txt

    # SEVENTH, make the launcher script
    autodetect_compiler_escape_as_single_quoted_argument() {
        # Since we will embed each name/value pair in single quotes
        # (ie. Z=hi ' there ==> 'Z=hi '"'"' there') so it can be placed
        # as a single `env` argument like `env 'Z=hi '"'"' there' ...`
        # we need to replace single quotes (') with ('"'"').
        sed "s#'#'\"'\"'#g" "$@"
    }
    {
        printf "%s\n" "#!$DKML_POSIX_SHELL"
        printf "%s\n" "exec env \\"

        # Add all but PATH and MSVS_PREFERENCE to launcher environment
        autodetect_compiler_escape_as_single_quoted_argument "$autodetect_compiler_TEMPDIR"/mostvars.eval.sh | while IFS='' read -r autodetect_compiler_line; do
            printf "%s\n" "  '$autodetect_compiler_line' \\";
        done

        # Add MSVS_PREFERENCE
        printf "%s\n" "  MSVS_PREFERENCE='$autodetect_compiler_VSSTUDIOMSVSPREFERENCE' \\"

        # Add PATH
        autodetect_compiler_COMPILER_ESCAPED_UNIQ_PATH=$(printf "%s\n" "$autodetect_compiler_COMPILER_UNIQ_PATH" | autodetect_compiler_escape_as_single_quoted_argument)
        printf "%s\n" "  PATH='$autodetect_compiler_COMPILER_ESCAPED_UNIQ_PATH':\"\$PATH\" \\"

        # Add arguments
        printf "%s\n" '  "$@"'
    } > "$autodetect_compiler_LAUNCHER".tmp
    chmod +x "$autodetect_compiler_LAUNCHER".tmp
    mv "$autodetect_compiler_LAUNCHER".tmp "$autodetect_compiler_LAUNCHER"

    return 0
}

log_trace() {
    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then
        printf "%s\n" "+ $*" >&2
        time "$@"
    else
        "$@"
    fi
}
