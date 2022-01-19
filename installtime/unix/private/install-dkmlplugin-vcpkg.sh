#!/bin/sh
# -------------------------------------------------------
# install-dkmlplugin-vcpkg.sh PLATFORM
#
# Purpose:
# 1. Install vcpkg into the plugins/diskuvocaml/ of the OPAMROOT.
# 2. For bootstrapping CMake, can install vcpkg into any target directory.
#
# When invoked?
# As part of ./makeit initvcpkg or as part of Gradle to bootstrap CMake + DKSDK
#
# Prerequisites:
# - init-opam-root.sh
# - create-tools-switch.sh
#
# -------------------------------------------------------
set -euf

VCPKG_VER="2021.12.01"
VCPKG_CHECKSUM="2794f9b1f4d7f3d7a4948c7c0585315b45303cfc19fbd4c02c03e412654cf217"
run_with_vcpkg_pkgs() {
    run_with_vcpkg_pkgs_CMD="$1"
    shift
    if is_unixy_windows_build_machine; then
        "$run_with_vcpkg_pkgs_CMD" pkgconf libffi libuv
    else
        "$run_with_vcpkg_pkgs_CMD" libffi libuv
    fi
}

# ------------------
# BEGIN Command line processing

usage() {
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    install-dkmlplugin-vcpkg.sh -h                   Display this help message" >&2
    printf "%s\n" "    install-dkmlplugin-vcpkg.sh [-d STATEDIR] [-p DKMLPLATFORM]  Configure the Diskuv Opam plugins" >&2
    printf "%s\n" "      Without '-d' the Opam root will be the Opam 2.2 default" >&2
    printf "%s\n" "Options:" >&2
    printf "%s\n" "    -p DKMLPLATFORM: The DKML platform (not 'dev'). Defaults to the host native platform" >&2
    printf "%s\n" "    -d STATEDIR: If specified, use <STATEDIR>/opam as the Opam root" >&2
    printf "%s\n" "    -t TARGETDIR: If specified, place vcpkg in the target directory" >&2
    printf "%s\n" "    -o OPAMHOME: Optional. Home directory for Opam containing bin/opam or bin/opam.exe" >&2
    printf "%s\n" "    -x: If specified, no packages are installed; vcpkg is only bootstrapped" >&2
}

PLATFORM=
STATEDIR=
USERMODE=ON
TARGETDIR=
BOOTSTRAP_ONLY=OFF
OPAMHOME=
while getopts ":hp:d:t:o:x" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            PLATFORM=$OPTARG
            if [ "$PLATFORM" = dev ]; then
                usage
                exit 0
            fi
        ;;
        d )
            # shellcheck disable=SC2034
            STATEDIR=$OPTARG
            # shellcheck disable=SC2034
            USERMODE=OFF
        ;;
        t )
            TARGETDIR=$OPTARG
        ;;
        o )
            # shellcheck disable=SC2034
            OPAMHOME=$OPTARG
            ;;
        x )
            BOOTSTRAP_ONLY=ON
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

DKMLDIR=$(PATH=/usr/bin:/bin dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/../../.." && PATH=/usr/bin:/bin pwd)

# shellcheck disable=SC1091
. "$DKMLDIR"/vendor/dkml-runtime-common/unix/_common_tool.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# BEGIN         ON-DEMAND OPAM ROOT INSTALLATIONS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# We use the Opam plugin directory to hold our root-specific installations.
# http://opam.ocaml.org/doc/Manual.html#opam-root
#
# In Diskuv OCaml each architecture gets its own Opam root.

# Set DKMLSYS_*
autodetect_system_binaries

# Set default for PLATFORM
if [ -z "$PLATFORM" ]; then
    # Set BUILDHOST_ARCH
    autodetect_buildhost_arch

    PLATFORM=$BUILDHOST_ARCH
fi

# -----------------------
# BEGIN install vcpkg

# Q: Why is vcpkg here rather than in DiskuvOCamlHome?
#
# (Updated) vcpkg is set in SDK Projects in the CMake toolchain, which will cause
# the `VCPKG_TOOLCHAIN` CMake variable to be ON. It will also put vcpkg_installed into
# the build directory, which is 1-1 with an architecture. Per
# https://github.com/microsoft/vcpkg/blob/3bcdecedb57dc66ab1d7b1b3ce6028c5143318b1/docs/specifications/scripts-extraction.md#naming-variables
# `VCPKG_TOOLCHAIN` is a public global variable so we can rely on it being there.

INSTALL_VCPKG_PACKAGES=OFF

# Set BUILDHOST_ARCH and DKML_VCPKG_HOST_TRIPLET.
# We need DKML_VCPKG_HOST_TRIPLET especially for Windows since Windows vcpkg defaults
# to x86-windows.
vcpkg_triplet_arg_platform "$PLATFORM"

# Locate vcpkg and the vcpkg package installation directory
if [ -n "$TARGETDIR" ]; then
    VCPKG_UNIX="$TARGETDIR"
else
    # Set DKMLPLUGIN_BUILDHOST; uses OPAMHOME if set
    set_opamrootdir

    # shellcheck disable=SC2154
    VCPKG_UNIX="$DKMLPLUGIN_BUILDHOST/vcpkg/$dkml_root_version"
fi

if [ -x /usr/bin/cygpath ]; then VCPKG_UNIX=$(/usr/bin/cygpath -au "$VCPKG_UNIX"); fi
if [ -x /usr/bin/cygpath ]; then VCPKG_BUILDHOST=$(/usr/bin/cygpath -aw "$VCPKG_UNIX"); fi
if [ -e vcpkg.json ]; then
    # Manifest projects use the local vcpkg_installed/ directory
    VCPKG_INSTALLED_UNIX=vcpkg_installed
else
    VCPKG_INSTALLED_UNIX="$VCPKG_UNIX"/installed
fi

$DKMLSYS_INSTALL -d "$VCPKG_UNIX"

if is_unixy_windows_build_machine || [ "${DKML_VENDOR_VCPKG:-OFF}" = ON ]; then
    if [ ! -e "$VCPKG_UNIX"/bootstrap-vcpkg.sh ] || [ ! -e "$VCPKG_UNIX"/scripts/bootstrap.ps1 ]; then
        # Download vcpkg
        downloadfile "https://github.com/microsoft/vcpkg/archive/refs/tags/$VCPKG_VER.tar.gz" "$VCPKG_UNIX"/src.tar.gz "$VCPKG_CHECKSUM"

        # Expand archive
        system_tar xCfz "$VCPKG_UNIX" "$VCPKG_UNIX"/src.tar.gz --strip-components=1
        $DKMLSYS_RM -f "$VCPKG_UNIX"/src.tar.gz
    fi

    if [ ! -e "$VCPKG_UNIX"/vcpkg ] && [ ! -e "$VCPKG_UNIX"/vcpkg.exe ]; then
        if is_unixy_windows_build_machine; then
            # 2021-08-05: Ultimately invokes src\build-tools\vendor\vcpkg\scripts\bootstrap.ps1 which you can peek at
            #             for command line arguments. Only -disableMetrics is recognized.
            log_trace "$VCPKG_UNIX/bootstrap-vcpkg.bat" -disableMetrics
        else
            exec_in_platform "$VCPKG_UNIX/bootstrap-vcpkg.sh" -disableMetrics
        fi
    fi
    INSTALL_VCPKG_PACKAGES=ON
fi

# END install vcpkg
# -----------------------

# -----------------------
# BEGIN install vcpkg packages

if [ "$BOOTSTRAP_ONLY" = OFF ] && [ "$INSTALL_VCPKG_PACKAGES" = ON ]; then
    # For some reason vcpkg stalls during installation in a Windows Server VM (Paris Locale).
    # There are older bug reports of vcpkg hanging because of non-English installs (probably "Y" [Yes/No] versus
    # "O" [Oui/Non] prompting); not sure what it is. Use undocumented vcpkg hack to stop stalling on user input.
    # https://github.com/Microsoft/vcpkg/issues/645 .
    # Note: This doesn't fix the stalling but keeping it!
    $DKMLSYS_INSTALL -d "$VCPKG_UNIX"/downloads
    PATH=/usr/bin:/bin touch "$VCPKG_UNIX"/downloads/AlwaysAllowEverything

    # Set DKMLPARENTHOME_BUILDHOST and autodetect VSDEV_HOME_BUILDHOST
    autodetect_vsdev

    # Set VCPKG_VISUAL_STUDIO_PATH
    if is_unixy_windows_build_machine; then
        VCPKG_VISUAL_STUDIO_PATH="${VSDEV_HOME_BUILDHOST:-}"
    else
        VCPKG_VISUAL_STUDIO_PATH=""
    fi

    # Set DKMLHOME_UNIX if available
    autodetect_dkmlvars || true

    # Set PATH for vcpkg
    if [ -n "${DKMLHOME_UNIX:-}" ]; then
        # We don't want vcpkg installing cmake again if we have a modern one
        # shellcheck disable=SC2154
        VCPKG_PATH="$DKMLHOME_UNIX/tools/cmake/bin:$DKMLHOME_UNIX/tools/ninja:$PATH"
    else
        VCPKG_PATH="$PATH"
    fi

    # shellcheck disable=SC2120
    install_vcpkg_pkgs() {
        # Reference: Visual Studio detection logic for vcpkg is at https://github.com/microsoft/vcpkg/blob/2020.11/toolsrc/src/vcpkg/visualstudio.cpp#L191-L345

        if is_unixy_windows_build_machine; then
            # Set DKML_SYSTEM_POWERSHELL or fail
            autodetect_system_powershell

            # Use Windows PowerShell to create a completely detached process (not a child process). This will work around
            # stalls when running vcpkg directly in MSYS2.
            # Also, vcpkg uses an environment variable 'ProgramFiles(x86)' which is not present in dash.exe because of
            # the parentheses (see https://github.com/microsoft/vcpkg/issues/12433#issuecomment-928165257). That makes vcpkg
            # unable to locate vswhere.exe, and hence unable to locate most VS Studio installations. So we recreate the
            # variable in PowerShell using CSIDL_PROGRAM_FILESX86 (https://docs.microsoft.com/en-us/windows/win32/shell/csidl).
            install_vcpkg_pkgs_COMMAND_AND_ARGS="& { if ([Environment]::Is64BitOperatingSystem) { \${env:ProgramFiles(x86)} = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86) }; \$proc = Start-Process -NoNewWindow -FilePath '$VCPKG_BUILDHOST\\vcpkg.exe' -Wait -PassThru -ArgumentList (@('install') + ( '$*'.split().Where({ '' -ne \$_ }) ) + @('--triplet=$DKML_VCPKG_HOST_TRIPLET', '--debug')); if (\$proc.ExitCode -ne 0) { throw 'vcpkg failed' } }"
            log_trace "$DKMLSYS_ENV" --unset=TEMP --unset=TMP VCPKG_VISUAL_STUDIO_PATH="$VCPKG_VISUAL_STUDIO_PATH" PATH="$VCPKG_PATH" "$DKML_SYSTEM_POWERSHELL" -Command "$install_vcpkg_pkgs_COMMAND_AND_ARGS"
        else
            # Note: Without CLICOLOR=0 `vcpkg --install` on Linux (vcpkg 2021.12.01) will give:
            #       Failed to parse CMake console output to locate port start/end markers
            # Confer: https://github.com/microsoft/vcpkg/issues/20430
            if [ "${DKML_BUILD_TRACE:-}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
                log_trace "$DKMLSYS_ENV" CLICOLOR=0 VCPKG_VISUAL_STUDIO_PATH="$VCPKG_VISUAL_STUDIO_PATH" PATH="$VCPKG_PATH" "$VCPKG_UNIX"/vcpkg install "$@" --triplet="$DKML_VCPKG_HOST_TRIPLET" --debug
            else
                log_trace "$DKMLSYS_ENV" CLICOLOR=0 VCPKG_VISUAL_STUDIO_PATH="$VCPKG_VISUAL_STUDIO_PATH" PATH="$VCPKG_PATH" "$VCPKG_UNIX"/vcpkg install "$@" --triplet="$DKML_VCPKG_HOST_TRIPLET"
            fi
        fi
    }

    # Install vcpkg packages
    if [ -e vcpkg.json ]; then
        # https://vcpkg.io/en/docs/users/manifests.html
        # The project in $TOPDIR is a vcpkg manifest project; these are now recommended
        # by vcpkg. The dependencies are listed in vcpkg.json, with no tool to edit it.

        # 1. Install the project dependencies using the triplet we need.
        install_vcpkg_pkgs

        # 2. Validate we have all necessary dependencies
        # | awk -v PKGNAME=sqlite3 -v TRIPLET=x64-windows '$1==(PKGNAME ":" TRIPLET) {print $1}'
        # shellcheck disable=SC2016
        "$VCPKG_UNIX"/vcpkg list | $DKMLSYS_AWK '{print $1}' | $DKMLSYS_GREP ":$DKML_VCPKG_HOST_TRIPLET$" | $DKMLSYS_SED 's,:[^:]*,,' | $DKMLSYS_SORT -u > "$WORK"/vcpkg.have
        run_with_vcpkg_pkgs echo | PATH=/usr/bin:/bin xargs -n1 | $DKMLSYS_SORT -u > "$WORK"/vcpkg.need
        $DKMLSYS_COMM -13 "$WORK"/vcpkg.have "$WORK"/vcpkg.need > "$WORK"/vcpkg.missing
        if [ -s "$WORK"/vcpkg.missing ]; then
            ERRFILE=$TOPDIR/vcpkg.json
            if is_unixy_windows_build_machine; then ERRFILE=$(cygpath -aw "$ERRFILE"); fi
            printf "%s\n" "FATAL: The following vcpkg dependencies are required for Diskuv OCaml but missing from $ERRFILE:" >&2
            cat "$WORK"/vcpkg.missing >&2
            printf "%s\n" ">>> Please add in the missing dependencies. Docs at https://vcpkg.io/en/docs/users/manifests.html"
            exit 1
        fi
    else
        # Non vcpkg-manifest project. All packages will be installed in the
        # "system" ($VCPKG_UNIX).
        run_with_vcpkg_pkgs install_vcpkg_pkgs
    fi

    # ---fixup pkgconf----

    # (Windows) Copy pkgconf.exe to pkg-config.exe since not provided
    # automatically. https://github.com/pkgconf/pkgconf#pkg-config-symlink

    if [ -e "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/tools/pkgconf/pkgconf.exe ]; then
        $DKMLSYS_INSTALL "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/tools/pkgconf/pkgconf.exe \
            "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/tools/pkgconf/pkg-config.exe
    fi

    # ---fixup libuv----

    # If you use official CMake build of libuv, it produces uv.lib not libuv.lib used by vcpkg.

    if [ -e "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/lib/libuv.lib ]; then
        $DKMLSYS_INSTALL "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/lib/libuv.lib \
            "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/lib/uv.lib
    fi
    if [ -e "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/lib/liblibuv.a ]; then
        $DKMLSYS_INSTALL "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/lib/liblibuv.a \
            "$VCPKG_INSTALLED_UNIX"/"$DKML_VCPKG_HOST_TRIPLET"/lib/libuv.a
    fi
fi

# END install vcpkg packages
# -----------------------

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END           ON-DEMAND OPAM ROOT INSTALLATIONS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
