#!/usr/bin/env bash
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

# Is a Windows build machine if we are in a MSYS2 or Cygwin environment.
#
# Better alternatives
# -------------------
#
# 1. If you are checking to see if you should do a cygpath, then just guard it
#    like so:
#       if [[ -x /usr/bin/cygpath ]]; then
#           do_something $(/usr/bin/cygpath ...) ...
#       fi
#    This clearly guards what you are about to do (cygpath) with what you will
#    need (cygpath).
function is_unixy_windows_build_machine () {
    if is_msys2_msys_build_machine || is_cygwin_build_machine; then
        return 0
    fi
    return 1
}

# Is a MSYS2 environment with the MSYS subsystem? (MSYS2 can also do MinGW 32-bit
# and 64-bit subsystems)
function is_msys2_msys_build_machine () {
    if [[ -e /usr/bin/msys-2.0.dll && "${MSYSTEM:-}" = "MSYS" ]]; then
        return 0
    fi
    return 1
}

function is_cygwin_build_machine () {
    if [[ -e /usr/bin/cygwin1.dll ]]; then
        return 0
    fi
    return 1
}

# Install files that will always be in a reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 100-compile-opam
#  env:DKMLDIR - The directory with .dkmlroot
function install_reproducible_common () {
    local BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$BOOTSTRAPDIR"
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
function install_reproducible_file () {
    local RELFILE="$1"
    shift
    local RELDIR
    RELDIR=$(dirname "$RELFILE")
    local BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$BOOTSTRAPDIR"/"$RELDIR"/
    install "$DKMLDIR"/"$RELFILE" "$BOOTSTRAPDIR"/"$RELDIR"/
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
function install_reproducible_generated_file () {
    local SRCFILE="$1"
    shift
    local RELFILE="$1"
    shift
    local RELDIR
    RELDIR=$(dirname "$RELFILE")
    local BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$BOOTSTRAPDIR"/"$RELDIR"/
    rm -f "$BOOTSTRAPDIR"/"$RELFILE" # ensure if exists it is a regular file or link but not a directory
    install "$SRCFILE" "$BOOTSTRAPDIR"/"$RELFILE"
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
function install_reproducible_readme () {
    local RELFILE="$1"
    shift
    local RELDIR
    RELDIR=$(dirname "$RELFILE")
    local BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install -d "$BOOTSTRAPDIR"
    sed "s,@@BOOTSTRAPDIR_UNIX@@,$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME/,g" "$DKMLDIR"/"$RELFILE" > "$BOOTSTRAPDIR"/README.md
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
function install_reproducible_system_packages () {
    local SCRIPTFILE="$1"
    shift
    local PACKAGEFILE="${SCRIPTFILE//.sh/.packagelist.txt}"
    if [[ "$PACKAGEFILE" = "$SCRIPTFILE" ]]; then
        echo "FATAL: The run script $SCRIPTFILE must end with .sh" >&2
        exit 1
    fi
    local SCRIPTDIR
    SCRIPTDIR=$(dirname "$SCRIPTFILE")
    local BOOTSTRAPRELDIR=$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    local BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$BOOTSTRAPRELDIR
    install -d "$BOOTSTRAPDIR"/"$SCRIPTDIR"/

    if is_msys2_msys_build_machine; then
        # https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#List_of_installed_packages
        pacman -Qqet > "$BOOTSTRAPDIR"/"$PACKAGEFILE"
        printf "#!/usr/bin/env bash\nexec pacman -S \"\$@\" --needed - < '%s'\n" "$BOOTSTRAPRELDIR/$PACKAGEFILE" > "$BOOTSTRAPDIR"/"$SCRIPTFILE"
    elif is_cygwin_build_machine; then
        cygcheck.exe -c -d > "$BOOTSTRAPDIR"/"$PACKAGEFILE"
        {
            echo "#!/usr/bin/env bash"
            echo "if [[ ! -e /usr/local/bin/cyg-get ]]; then wget -O /usr/local/bin/cyg-get 'https://gitlab.com/cogline.v3/cygwin/-/raw/2049faf4b565af81937d952292f8ae5008d38765/cyg-get?inline=false'; fi"
            echo "if [[ ! -x /usr/local/bin/cyg-get ]]; then chmod +x /usr/local/bin/cyg-get; fi"
            printf "readarray -t pkgs < <(awk 'display==1{print \$1} \$1==\"Package\"{display=1}' '%s')\n" "$BOOTSTRAPRELDIR/$PACKAGEFILE"
            # shellcheck disable=SC2016
            echo 'set -x ; /usr/local/bin/cyg-get install ${pkgs[@]}'
        } > "$BOOTSTRAPDIR"/"$SCRIPTFILE"
    else
        echo "TODO: install_reproducible_system_packages for non-Windows platforms" >&2
        exit 1
    fi
    chmod 755 "$BOOTSTRAPDIR"/"$SCRIPTFILE"
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
function install_reproducible_script_with_args () {
    local SCRIPTFILE="$1"
    shift
    local RECREATEFILE="${SCRIPTFILE//.sh/-noargs.sh}"
    if [[ "$RECREATEFILE" = "$SCRIPTFILE" ]]; then
        echo "FATAL: The run script $SCRIPTFILE must end with .sh" >&2
        exit 1
    fi
    local RECREATEDIR
    RECREATEDIR=$(dirname "$SCRIPTFILE")
    local BOOTSTRAPRELDIR=$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    local BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$BOOTSTRAPRELDIR

    install_reproducible_file "$SCRIPTFILE"
    install -d "$BOOTSTRAPDIR"/"$RECREATEDIR"/
    printf "#!/usr/bin/env bash\nexec env TOPDIR=\"\$PWD/%s/installtime/none/emptytop\" %s %s\n" \
        "$BOOTSTRAPRELDIR" \
        "$BOOTSTRAPRELDIR/$SCRIPTFILE" \
        "$*" > "$BOOTSTRAPDIR"/"$RECREATEFILE"
    chmod 755 "$BOOTSTRAPDIR"/"$RECREATEFILE"
}

# Tries to find the ARCH (defined in TOPDIR/Makefile corresponding to the build machine)
# For now only tested in Linux/Windows x86/x86_64.
# Outputs:
# - env:BUILDHOST_ARCH will contain the correct ARCH
function build_machine_arch () {
    local MACHINE
    MACHINE=$(uname -m)
    # list from https://en.wikipedia.org/wiki/Uname and https://stackoverflow.com/questions/45125516/possible-values-for-uname-m
    case "${MACHINE}" in
        "armv7*")
            BUILDHOST_ARCH=linux_arm32v7;;
        "armv6*" | "arm")
            BUILDHOST_ARCH=linux_arm32v6;;
        "aarch64" | "arm64" | "armv8*")
            BUILDHOST_ARCH=linux_arm64;;
        "i386" | "i686")
            if is_unixy_windows_build_machine; then
                BUILDHOST_ARCH=windows_x86
            else
                BUILDHOST_ARCH=linux_x86
            fi
            ;;
        "x86_64")
            if is_unixy_windows_build_machine; then
                BUILDHOST_ARCH=windows_x86_64
            else
                # shellcheck disable=SC2034
                BUILDHOST_ARCH=linux_x86_64
            fi
            ;;
        *)
            echo "FATAL: Unsupported build machine type obtained from 'uname -m': $MACHINE" >&2
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
function platform_vcpkg_triplet () {
    build_machine_arch
    # TODO: This static list is brittle. Should parse the Makefile or better yet
    # place in a different file that can be used by this script and the Makefile.
    case "$PLATFORM-$BUILDHOST_ARCH" in
        "dev-windows_x86")    PLATFORM_VCPKG_TRIPLET=x86-windows ;;
        "dev-windows_x86_64") PLATFORM_VCPKG_TRIPLET=x64-windows ;;
        "dev-linux_x86")      PLATFORM_VCPKG_TRIPLET=x86-linux ;;
        "dev-linux_x86_64")
            # shellcheck disable=SC2034
            PLATFORM_VCPKG_TRIPLET=x64-linux ;;
        *)
            echo "FATAL: Unsupported vcpkg triplet for PLATFORM: $PLATFORM" >&2
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
function disambiguate_filesystem_paths () {
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
function set_dkmlparenthomedir () {
    if [[ -n "${LOCALAPPDATA:-}" ]]; then
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
function autodetect_cpus () {
    # type cast to a number (in case user gave a string)
    NUMCPUS=$(( NUMCPUS + 0 ))
    if (( NUMCPUS == 0 )); then
        NUMCPUS=1
        if [[ -n "${NUMBER_OF_PROCESSORS:-}" ]]; then
            # Windows usually has NUMBER_OF_PROCESSORS
            NUMCPUS="$NUMBER_OF_PROCESSORS"
        elif nproc --all > "$WORK"/numcpus 2>/dev/null && [[ -s "$WORK"/numcpus ]]; then
            NUMCPUS=$(< "$WORK"/numcpus)
        fi
    fi
    # type cast again to a number (in case autodetection produced a string)
    NUMCPUS=$(( NUMCPUS + 0 ))
    if (( NUMCPUS < 1 )); then
        NUMCPUS=1
    elif (( NUMCPUS > 8 )); then
        NUMCPUS=8
    fi
    export NUMCPUS
}

# Detects Visual Studio and sets its variables.
# autodetect_vsdev [EXTRA_PREFIX]
#
# Includes EXTRA_PREFIX as a prefix for /include and and /lib library paths.
#
# Example:
#  autodetect_vsdev /usr/local && env "${ENV_ARGS[@]}" PATH="$VSDEV_UNIQ_PATH:$PATH" run-something.sh
#  autodetect_vsdev /usr/local && env "${ENV_ARGS[@]}" PATH="$VSDEV_PATH" run-something.sh
#
# Inputs:
# - $1 - Optional. If provided, then $1/include and $1/lib are added to INCLUDE and LIB, respectively
# - env:PLATFORM - Optional; if missing treated as 'dev'. This variable will select the Visual Studio
#   options necessary to cross-compile (or native compile) to the target PLATFORM. 'dev' is always
#   a native compilation.
# - env:WORK - Optional. If provided will be used as temporary directory
# - env:DKML_VSSTUDIO_DIR - Optional. If provided the specified installation of Visual Studio will be used.
#   The directory should contain VC and Common7 subfolders.
# - array:ENV_ARGS - Optional. An array of environment variables which will be modified by this function
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:VSDEV_HOME_UNIX is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Empty otherwise
# - env:BUILDHOST_ARCH will contain the correct ARCH
# - env:OCAML_HOST_TRIPLET is non-empty if `--host OCAML_HOST_TRIPLET` should be passed to OCaml's ./configure script when
#   compiling OCaml. Aligns with the PLATFORM variable that was specified, especially for cross-compilation.
# - env:VSDEV_UNIQ_PATH is the text of all new PATH entries that should be prepended to the existing PATH if and
#   only if the vcvars could be detected (aka. on a Windows machine, and it is installed); otherwise it is empty.
# - env:VSDEV_PATH is new PATH if and only if the vcvars could be detected (aka. on a Windows machine, and it is
#   installed); otherwise it is the original PATH. You should use VSDEV_UNIQ_PATH instead
# - array:ENV_ARGS - An array of environment variables for Visual Studio, including any provided at
#   the start of the function
# Return Values:
# - 0: Success
# - 1: Not a Windows machine
# - 2: Windows machine without proper Diskuv OCaml installation (typically you should exit)
function autodetect_vsdev () {
    local TEMPDIR=${WORK:-$TMP}
    local PLATFORM_ARCH=${PLATFORM:-dev}

    # Initialize output variables ...
    export VSDEV_UNIQ_PATH=
    export VSDEV_PATH="$PATH"
    [[ -v ENV_ARGS[@] ]] || ENV_ARGS=() # initialize array if not exist
    export VSDEV_HOME_UNIX=
    export VSDEV_HOME_WINDOWS=

    # Host triplet:
    #   (TODO: Better link)
    #   https://gitlab.com/diskuv/diskuv-ocaml/-/blob/aabf3171af67a0a0ff4779c336867a7a43e3670f/etc/opam-repositories/diskuv-opam-repo/packages/ocaml-variants/ocaml-variants.4.12.0+options+dkml+msvc64/opam#L52-62
    export OCAML_HOST_TRIPLET=

    # Get the extra prefix with backslashes escaped for Awk, if specified
    if [[ "$#" -ge 1 ]]; then
        local EXTRA_PREFIX_ESCAPED="$1"
        if is_unixy_windows_build_machine; then EXTRA_PREFIX_ESCAPED=$(cygpath -aw "$EXTRA_PREFIX_ESCAPED"); fi
        EXTRA_PREFIX_ESCAPED=${EXTRA_PREFIX_ESCAPED//\\/\\\\}
        shift
    else
        local EXTRA_PREFIX_ESCAPED=""
    fi

    # Autodetect BUILDHOST_ARCH
    build_machine_arch
    if [[ ! "$BUILDHOST_ARCH" = windows_* ]]; then
        return 1
    fi

    # Set DKMLPARENTHOME_BUILDHOST
    set_dkmlparenthomedir

    local VSSTUDIODIR
    local VSSTUDIOVCVARSVER
    if [[ -n "${DKML_VSSTUDIO_DIR:-}" && -n "${DKML_VSSTUDIO_VCVARSVER:-}" && -n "${DKML_VSSTUDIO_MSVSPREFERENCE:-}" ]]; then
        VSSTUDIODIR=$DKML_VSSTUDIO_DIR
        VSSTUDIOVCVARSVER=$DKML_VSSTUDIO_VCVARSVER
        VSSTUDIOMSVSPREFERENCE=$DKML_VSSTUDIO_MSVSPREFERENCE
    else
        local VSSTUDIO_DIRFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.dir.txt"
        if [[ ! -e "$VSSTUDIO_DIRFILE" ]]; then
            return 2
        fi
        local VSSTUDIO_VCVARSVERFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.vcvars_ver.txt"
        if [[ ! -e "$VSSTUDIO_VCVARSVERFILE" ]]; then
            return 2
        fi
        local VSSTUDIO_MSVSPREFERENCEFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.msvs_preference.txt"
        if [[ ! -e "$VSSTUDIO_MSVSPREFERENCEFILE" ]]; then
            return 2
        fi
        VSSTUDIODIR=$(awk 'BEGIN{RS="\r\n"} {print; exit}' "$VSSTUDIO_DIRFILE")
        VSSTUDIOVCVARSVER=$(awk 'BEGIN{RS="\r\n"} {print; exit}' "$VSSTUDIO_VCVARSVERFILE")
        VSSTUDIOMSVSPREFERENCE=$(awk 'BEGIN{RS="\r\n"} {print; exit}' "$VSSTUDIO_MSVSPREFERENCEFILE")
    fi
    if [[ -x /usr/bin/cygpath ]]; then
        VSSTUDIODIR=$(/usr/bin/cygpath -au "$VSSTUDIODIR")
    fi
    VSDEV_HOME_UNIX="$VSSTUDIODIR"
    if [[ -x /usr/bin/cygpath ]]; then
        VSDEV_HOME_WINDOWS=$(/usr/bin/cygpath -aw "$VSDEV_HOME_UNIX")
    else
        VSDEV_HOME_WINDOWS="$VSDEV_HOME_UNIX"
    fi

    # MSYS2 detection. Path is /c/DiskuvOCaml/BuildTools/VC/Auxiliary/Build/vcvarsall.bat.
    # The vsdevcmd.bat is at /c/DiskuvOCaml/BuildTools/Common7/Tools/VsDevCmd.bat but
    # can't select cross-compilation for some reason.
    local USE_VSDEV=1
    if (( USE_VSDEV == 1 )); then
        if [[ -e "$VSSTUDIODIR"/Common7/Tools/VsDevCmd.bat ]]; then
            VSDEVCMD="$VSSTUDIODIR/Common7/Tools/VsDevCmd.bat"
        else
            return 2
        fi
    else
        if [[ -e "$VSSTUDIODIR"/VC/Auxiliary/Build/vcvarsall.bat ]]; then
            VSDEVCMD="$VSSTUDIODIR/VC/Auxiliary/Build/vcvarsall.bat"
        else
            return 2
        fi
    fi

    VSDEV_ARGS=(-no_logo -vcvars_ver="$VSSTUDIOVCVARSVER")
    VCVARS_ARGS=(-vcvars_ver="$VSSTUDIOVCVARSVER")
    # https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-160#vcvarsall-syntax
    if [[ "$BUILDHOST_ARCH" = windows_x86 ]]; then
        # The build host machine is 32-bit ...
        if [[ "$PLATFORM_ARCH" = dev || "$PLATFORM_ARCH" = windows_x86 ]]; then
            VSDEV_ARGS+=(-arch=x86)
            VCVARS_ARGS+=(x86)
            OCAML_HOST_TRIPLET=i686-pc-windows
        elif [[ "$PLATFORM_ARCH" = windows_x86_64 ]]; then
            # The target machine is 64-bit
            VSDEV_ARGS+=(-host_arch=x86 -arch=x64)
            VCVARS_ARGS+=(-arch=x86_amd64)
            OCAML_HOST_TRIPLET=x86_64-pc-windows
        else
            echo "FATAL: check_state autodetect_vsdev BUILDHOST_ARCH=$BUILDHOST_ARCH PLATFORM_ARCH=$PLATFORM_ARCH" >&2
            exit 1
        fi
    elif [[ "$BUILDHOST_ARCH" = windows_x86_64 ]]; then
        # The build host machine is 64-bit ...
        if [[ "$PLATFORM_ARCH" = dev || "$PLATFORM_ARCH" = windows_x86_64 ]]; then
            VSDEV_ARGS+=(-arch=x64)
            VCVARS_ARGS+=(x64)
            OCAML_HOST_TRIPLET=x86_64-pc-windows
        elif [[ "$PLATFORM_ARCH" = windows_x86 ]]; then
            # The target machine is 32-bit
            VSDEV_ARGS+=(-host_arch=x64 -arch=x86)
            VCVARS_ARGS+=(amd64_x86)
            OCAML_HOST_TRIPLET=i686-pc-windows
        else
            echo "FATAL: check_state autodetect_vsdev BUILDHOST_ARCH=$BUILDHOST_ARCH PLATFORM_ARCH=$PLATFORM_ARCH" >&2
            exit 1
        fi
    else
        echo "FATAL: check_state autodetect_vsdev BUILDHOST_ARCH=$BUILDHOST_ARCH PLATFORM_ARCH=$PLATFORM_ARCH" >&2
        exit 1
    fi

    # FIRST, create a file that calls vsdevcmd.bat and then adds a `set` dump.
    # Example:
    #     @call "C:\DiskuvOCaml\BuildTools\Common7\Tools\VsDevCmd.bat" %*
    #     set > "C:\the-WORK-directory\vcvars.txt"
    # to the bottom of it so we can inspect the environment variables.
    # (Less hacky version of https://help.appveyor.com/discussions/questions/18777-how-to-use-vcvars64bat-from-powershell)
    VSDEVCMDFILE_WIN=$(cygpath -aw "$VSDEVCMD")
    {
        echo '@call "'"$VSDEVCMDFILE_WIN"'" %*'
        # shellcheck disable=SC2046
        echo 'set > "'$(cygpath -aw "$TEMPDIR")'\vcvars.txt"'
    } > "$TEMPDIR"/vsdevcmd-and-printenv.bat

    # SECOND, we run the batch file
    PATH_UNIX=$(cygpath -au --path "$PATH")
    VSCMD_OPTS=(__VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1) # __VSCMD_ARG_NO_LOGO is for vcvars which is missing -no_logo option
    if (( USE_VSDEV == 1 )); then
        VSCMD_ARGS=("${VSDEV_ARGS[@]}")
    else
        VSCMD_ARGS=("${VCVARS_ARGS[@]}")
    fi
    if [[ "${DKML_BUILD_TRACE:-ON}" = ON ]] && [[ "${DKML_BUILD_TRACE_LEVEL:-0}" = 2 ]]; then
        env PATH="$PATH_UNIX" "${VSCMD_OPTS[@]}" VSCMD_DEBUG=1 "$TEMPDIR"/vsdevcmd-and-printenv.bat "${VSCMD_ARGS[@]}" >&2 # use stderr to not mess up stdout which calling script may care about.
    else
        env PATH="$PATH_UNIX" "${VSCMD_OPTS[@]}" "$TEMPDIR"/vsdevcmd-and-printenv.bat "${VSCMD_ARGS[@]}" > /dev/null
    fi

    # THIRD, we add everything to the environment except:
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
    # - HOME* (HOME, HOMEDRIVE, HOMEPATH)
    # - USER* (USERNAME, USERPROFILE, USERDOMAIN, USERDOMAIN_ROAMINGPROFILE)
    if [[ -n "${EXTRA_PREFIX_ESCAPED:-}" ]]; then
        local VCPKG_PREFIX_INCLUDE_ESCAPED="$EXTRA_PREFIX_ESCAPED\\\\include;"
        local VCPKG_PREFIX_LIB_ESCAPED="$EXTRA_PREFIX_ESCAPED\\\\lib;"
    else
        local VCPKG_PREFIX_INCLUDE_ESCAPED=""
        local VCPKG_PREFIX_LIB_ESCAPED=""
    fi
    awk \
        -v VCPKG_PREFIX_INCLUDE="$VCPKG_PREFIX_INCLUDE_ESCAPED" \
        -v VCPKG_PREFIX_LIB="$VCPKG_PREFIX_LIB_ESCAPED" '
    BEGIN{FS="="}

    $1 != "PATH" &&
    $1 != "MSVS_PREFERENCE" &&
    $1 != "INCLUDE" &&
    $1 != "LIB" &&
    $1 !~ /^!ExitCode/ &&
    $1 !~ /^_$/ && $1 != "TEMP" && $1 != "TMP" && $1 != "PWD" &&
    $1 != "PROMPT" && $1 !~ /^LOGON/ && $1 !~ /APPDATA$/ &&
    $1 != "ALLUSERSPROFILE" && $1 != "CYGWIN" && $1 != "CYGPATH" &&
    $1 !~ /^HOME/ &&
    $1 !~ /^USER/ {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" value}

    $1 == "INCLUDE" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" VCPKG_PREFIX_INCLUDE value}
    $1 == "LIB" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" VCPKG_PREFIX_LIB value}
    ' "$TEMPDIR"/vcvars.txt > "$TEMPDIR"/mostvars.eval.sh

    # Add all but PATH and MSVS_PREFERENCE to ENV_ARGS
    while IFS='' read -r line; do ENV_ARGS+=("$line"); done < "$TEMPDIR"/mostvars.eval.sh

    # Add MSVS_PREFERENCE
    ENV_ARGS+=(MSVS_PREFERENCE="VS$VSSTUDIOMSVSPREFERENCE")

    # FOURTH, set VSDEV_PATH to the provided PATH
    awk '
    BEGIN{FS="="}

    $1 == "PATH" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print value}
    ' "$TEMPDIR"/vcvars.txt > "$TEMPDIR"/winpath.txt
    # shellcheck disable=SC2086
    cygpath --path -f - < "$TEMPDIR/winpath.txt" > "$TEMPDIR"/unixpath.txt
    # shellcheck disable=SC2034
    VSDEV_PATH=$(< "$TEMPDIR"/unixpath.txt)

    # FIFTH, set VSDEV_UNIQ_PATH so that it is only the _unique_ entries
    # (the set {VSDEV_UNIQ_PATH} - {PATH}) are used. But maintain the order
    # that Microsoft places each path entry.
    echo "$VSDEV_PATH" | awk 'BEGIN{RS=":"} {print}' > "$TEMPDIR"/vcvars_entries.txt
    comm \
        -23 \
        <(sort -u "$TEMPDIR"/vcvars_entries.txt) \
        <(echo "$PATH" | awk 'BEGIN{RS=":"} {print}' | sort -u) \
        > "$TEMPDIR"/vcvars_uniq.txt
    while IFS='' read -r line; do
        # if and only if the $line matches one of the lines in vcvars_uniq.txt
        if ! echo "$line" | comm -12 - "$TEMPDIR"/vcvars_uniq.txt | awk 'NF>0{exit 1}'; then
            if [[ -z "$VSDEV_UNIQ_PATH" ]]; then
                VSDEV_UNIQ_PATH="$line"
            else
                VSDEV_UNIQ_PATH="$VSDEV_UNIQ_PATH:$line"
            fi
        fi
    done < "$TEMPDIR"/vcvars_entries.txt

    return 0
}

function log_trace () {
    if [[ "${DKML_BUILD_TRACE:-ON}" = ON ]]; then
        echo "+ $*" >&2
        time "$@"
    else
        "$@"
    fi
}
