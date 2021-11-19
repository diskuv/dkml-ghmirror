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
# @jonahbeckford: 2021-10-26
# - This file is licensed differently than the rest of the Diskuv OCaml distribution.
#   Keep the Apache License in this file since this file is part of the reproducible
#   build files.
#
######################################
# reproducible-compile-ocaml-1-setup.sh -d DKMLDIR -t TARGETDIR \
#      -v COMMIT [-a TARGETABIS] [-c OPT_WIN32_ARCH]
#
# Sets up the source code for a reproducible compilation of OCaml

set -euf

# ------------------
# BEGIN Command line processing

# Since installtime/windows/Machine/Machine.psm1 has minimum VS14 we only select that version
# or greater. We'll ignore '10.0' (Windows SDK 10) which may bundle Visual Studio 2015, 2017 or 2019.
# Also we do _not_ use the environment (ie. no '@' in MSVS_PREFERENCE) since that isn't reproducible,
# and also because it sets MSVS_* variables to empty if it thinks the environment is correct (but we
# _always_ want MSVS_* set since OCaml ./configure script branches on MSVS_* being non-empty).
OPT_MSVS_PREFERENCE='VS16.*;VS15.*;VS14.0' # KEEP IN SYNC with 2-build.sh

usage() {
    {
        printf "%s\n" "Usage:"
        printf "%s\n" "    reproducible-compile-ocaml-1-setup.sh"
        printf "%s\n" "        -h                       Display this help message."
        printf "%s\n" "        -d DIR -t DIR -v COMMIT  Setup compilation of OCaml."
        printf "\n"
        printf "%s\n" "The compiler for the host machine ('ABI') comes from the PATH (like /usr/bin/gcc) as detected by OCaml's ./configure"
        printf "%s\n" "script, except on Windows machines where https://github.com/metastack/msvs-tools#msvs-detect is used to search"
        printf "%s\n" "for Visual Studio compiler installations."
        printf "\n"
        printf "%s\n" "The expectation we place on any user of this script who wants to cross-compile is that they understand what an ABI is,"
        printf "%s\n" "and how to obtain a SYSROOT for their target ABI. If you want an OCaml cross-compiler, you will need to use"
        printf "%s\n" "the '-a TARGETABIS' option."
        printf "\n"
        printf "%s\n" "To generate 32-bit machine code from OCaml, the host ABI for the OCaml native compiler must be 32-bit. And to generate"
        printf "%s\n" "64-bit machine code from OCaml, the host ABI for the OCaml native compiler must be 64-bit. In practice this means you"
        printf "%s\n" "may want to pick a 32-bit cross compiler for your _host_ ABI (for example a GCC compiler in 32-bit mode on a 64-bit"
        printf "%s\n" "Intel host) and then set your _target_ ABI to be a different cross compiler (for example a GCC in 32-bit mode on a 64-bit"
        printf "%s\n" "ARM host). **You can and should use** a 32-bit or 64-bit cross compiler for your host ABI as long as it generates executables"
        printf "%s\n" "that can be run on your host platform. Apple Silicon is a common architecture where you cannot run 32-bit executables, so your"
        printf "%s\n" "choices for where to run 32-bit ARM executables are QEMU (slow) or a ARM64 board (limited memory; Raspberry Pi 4, RockPro 64,"
        printf "%s\n" "NVidia Jetson) or a ARM64 Snapdragon Windows PC with WSL2 Linux (limited memory) or AWS Graviton2 (cloud). ARM64 servers for"
        printf "%s\n" "individual resale are also becoming available."
        printf "\n"
        printf "%s\n" "Options"
        printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file"
        printf "%s\n" "   -t DIR: Target directory for the reproducible directory tree"
        printf "%s\n" "   -v COMMIT: Git commit or tag for https://github.com/ocaml/ocaml. Strongly prefer a commit id for much stronger"
        printf "%s\n" "      reproducibility guarantees"
        printf "%s\n" "   -a TARGETABIS: Optional. A named list of self-contained Posix shell script that can be sourced to set the"
        printf "%s\n" "      compiler environment variables for the target ABI. If not specified then the OCaml environment"
        printf "%s\n" "      will be purely for the host ABI. All path should use the native host platform's path"
        printf "%s\n" "      conventions like '/usr' on Unix and 'C:\VS2019' on Windows."
        printf "%s\n" "      The format of TARGETABIS is: <DKML_TARGET_ABI1>=/path/to/script1;<DKML_TARGET_ABI2>=/path/to/script2;..."
        printf "%s\n" "      where:"
        printf "%s\n" "        DKML_TARGET_ABI - The target ABI"
        printf "%s\n" "          Values include: windows_x86, windows_x86_64, android_arm64v8a, darwin_x86_64, etc."
        printf "%s\n" "          Others are/will be documented on https://diskuv.gitlab.io/diskuv-ocaml"
        printf "%s\n" "      The Posix shell script will have an unexported \$DKMLDIR environment variable containing the directory"
        printf "%s\n" "        of .dkmlroot, and an unexported \$DKML_TARGET_ABI containing the name specified in the TARGETABIS option"
        printf "%s\n" "      The Posix shell script should set some or all of the following compiler environment variables:"
        printf "%s\n" "        PATH - The PATH environment variable. You can use \$PATH to add to the existing PATH. On Windows"
        printf "%s\n" "          which uses MSYS2, the PATH should be colon separated with each PATH entry a UNIX path like /usr/a.out"
        printf "%s\n" "        AS - The assembly language compiler that targets machine code for the target ABI. On Windows this"
        printf "%s\n" "          must be a MASM compiler like ml/ml64.exe"
        printf "%s\n" "        ASPP - The assembly language compiler and preprocessor that targets machine code for the target ABI."
        printf "%s\n" "          On Windows this must be a MASM compiler like ml/ml64.exe"
        printf "%s\n" "        CC - The C cross compiler that targets machine code for the target ABI"
        printf "%s\n" "        INCLUDE - For the MSVC compiler, the semicolon-separated list of standard C and Windows header"
        printf "%s\n" "          directories that should be based on the target ABI sysroot"
        printf "%s\n" "        LIB - For the MSVC compiler, the semicolon-separated list of C and Windows library directories"
        printf "%s\n" "          that should be based on the target ABI sysroot"
        printf "%s\n" "        COMPILER_PATH - For the GNU compiler (GCC), the colon-separated list of system header directories"
        printf "%s\n" "          that should be based on the target ABI sysroot"
        printf "%s\n" "        CPATH - For the CLang compiler (including Apple CLang), the colon-separated list of system header"
        printf "%s\n" "          directories that should be based on the target ABI sysroot"
        printf "%s\n" "        LIBRARY_PATH - For the GNU compiler (GCC) and CLang compiler (including Apple CLang), the"
        printf "%s\n" "          colon-separated list of system library directory that should be based on the target ABI sysroot"
        printf "%s\n" "        PARTIALLD - The linker and flags to use for packaging (ocamlopt -pack) and for partial links"
        printf "%s\n" "          (ocamlopt -output-obj); only used while compiling the OCaml environment. This value"
        printf "%s\n" "          forms the basis of the 'native_pack_linker' of https://ocaml.org/api/compilerlibref/Config.html"
        printf "%s\n" "   -b PREF: Required and used only for the MSVC compiler. This is the msvs-tools MSVS_PREFERENCE setting"
        printf "%s\n" "      needed to detect the Windows compiler for the host ABI. Not used when '-e DKMLHOSTABI' is specified."
        printf "%s\n" "      Defaults to '$OPT_MSVS_PREFERENCE' which, because it does not include '@',"
        printf "%s\n" "      will not choose a compiler based on environment variables that would disrupt reproducibility."
        printf "%s\n" "      Confer with https://github.com/metastack/msvs-tools#msvs-detect"
        printf "%s\n" "   -c ARCH: Useful only for Windows. Defaults to auto. mingw64, mingw, msvc64, msvc or auto"
        printf "%s\n" "   -e DKMLHOSTABI: Optional. Use the Diskuv OCaml compiler detector find a host ABI compiler."
        printf "%s\n" "      Especially useful to find a 32-bit Windows host compiler that can use 64-bits of memory for the compiler."
        printf "%s\n" "      Values include: windows_x86, windows_x86_64, android_arm64v8a, darwin_x86_64, etc."
        printf "%s\n" "      Others are/will be documented on https://diskuv.gitlab.io/diskuv-ocaml"
        printf "%s\n" "   -g CONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure. --with-flexdll and --host will have already"
        printf "%s\n" "      been set appropriately, but you can override the --host heuristic by adding it to -f CONFIGUREARGS"
    } >&2
}

SETUP_ARGS=()
BUILD_HOST_ARGS=()
BUILD_CROSS_ARGS=()

DKMLDIR=
GIT_COMMITID_OR_TAG=
TARGETDIR=
OPT_WIN32_ARCH=auto
TARGETABIS=
MSVS_PREFERENCE="$OPT_MSVS_PREFERENCE"
while getopts ":d:v:t:a:b:c:e:g:h" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        d )
            DKMLDIR="$OPTARG"
            if [ ! -e "$DKMLDIR/.dkmlroot" ]; then
                printf "%s\n" "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2;
                usage
                exit 1
            fi
        ;;
        v )
            GIT_COMMITID_OR_TAG="$OPTARG"
            SETUP_ARGS+=( -v "$GIT_COMMITID_OR_TAG" )
        ;;
        t )
            TARGETDIR="$OPTARG"
            SETUP_ARGS+=( -t . )
            BUILD_HOST_ARGS+=( -t . )
            BUILD_CROSS_ARGS+=( -t . )
        ;;
        a )
            TARGETABIS="$OPTARG"
        ;;
        b )
            MSVS_PREFERENCE="$OPTARG"
            SETUP_ARGS+=( -b "$OPTARG" )
        ;;
        c )
            OPT_WIN32_ARCH="$OPTARG"
            SETUP_ARGS+=( -c "$OPTARG" )
        ;;
        e )
            SETUP_ARGS+=( -e "$OPTARG" )
            BUILD_HOST_ARGS+=( -e "$OPTARG" )
        ;;
        g )
            SETUP_ARGS+=( -g "$OPTARG" )
            BUILD_HOST_ARGS+=( -g "$OPTARG" )
            BUILD_CROSS_ARGS+=( -g "$OPTARG" )
        ;;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$DKMLDIR" ] || [ -z "$GIT_COMMITID_OR_TAG" ] || [ -z "$TARGETDIR" ]; then
    printf "%s\n" "Missing required options" >&2
    usage
    exit 1
fi

# Add options that have defaults
SETUP_ARGS+=( -b "'$MSVS_PREFERENCE'" )
BUILD_HOST_ARGS+=( -b "'$MSVS_PREFERENCE'" -c "$OPT_WIN32_ARCH" )
BUILD_CROSS_ARGS+=( -c "$OPT_WIN32_ARCH" )

# END Command line processing
# ------------------

# Need feature flag and usermode and statedir until all legacy code is removed in _common_tool.sh
# shellcheck disable=SC2034
DKML_FEATUREFLAG_CMAKE_PLATFORM=ON
# shellcheck disable=SC2034
USERMODE=ON
# shellcheck disable=SC2034
STATEDIR=

# shellcheck disable=SC1091
. "$DKMLDIR/runtime/unix/_common_tool.sh"

disambiguate_filesystem_paths

# Bootstrapping vars
TARGETDIR_UNIX=$(install -d "$TARGETDIR" && cd "$TARGETDIR" && pwd) # better than cygpath: handles TARGETDIR=. without trailing slash, and works on Unix/Windows
if [ -x /usr/bin/cygpath ]; then
    OCAMLSRC_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/src/ocaml")
    OCAMLSRC_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/src/ocaml")
    TARGETDIR_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX")
else
    OCAMLSRC_UNIX="$TARGETDIR_UNIX/src/ocaml"
    OCAMLSRC_MIXED="$OCAMLSRC_UNIX"
    TARGETDIR_MIXED="$TARGETDIR_UNIX"
fi

# To be portable whether we build scripts in a container or not, we
# change the directory to always be in the DKMLDIR (just like a container
# sets the directory to be /work)
cd "$DKMLDIR"

# Set DKMLSYS_CAT and other things
autodetect_system_binaries

# Find OCaml patch
# Source: https://github.com/EduardoRFS/reason-mobile/tree/master/patches/ocaml/files or https://github.com/anmonteiro/nix-overlays/tree/master/cross
find_ocaml_crosscompile_patch() {
    find_ocaml_crosscompile_patch_VER=$1
    shift
    case "$find_ocaml_crosscompile_patch_VER" in
    4.11.*)
        OCAMLPATCHFILE=reproducible-compile-ocaml-cross_4_11.patch
        OCAMLPATCHEXTRA= # TODO
        ;;
    4.12.*)
        OCAMLPATCHFILE=reproducible-compile-ocaml-cross_4_12.patch
        OCAMLPATCHEXTRA=reproducible-compile-ocaml-cross_4_12_extra.patch
        ;;
    4.13.*)
        # shellcheck disable=SC2034
        OCAMLPATCHFILE=reproducible-compile-ocaml-cross_4_13.patch
        # shellcheck disable=SC2034
        OCAMLPATCHEXTRA= # TODO
        ;;
    *)
        echo "FATAL: There is no cross-compiling patch file yet for OCaml $find_ocaml_crosscompile_patch_VER" >&2
        exit 107
        ;;
    esac
}

apply_ocaml_crosscompile_patch() {
    apply_ocaml_crosscompile_patch_PATCHFILE=$1
    shift
    apply_ocaml_crosscompile_patch_SRCDIR=$1
    shift

    apply_ocaml_crosscompile_patch_SRCDIR_MIXED="$apply_ocaml_crosscompile_patch_SRCDIR"
    apply_ocaml_crosscompile_patch_PATCH_MIXED="$PWD"/installtime/unix/private/$apply_ocaml_crosscompile_patch_PATCHFILE
    if [ -x /usr/bin/cygpath ]; then
        apply_ocaml_crosscompile_patch_SRCDIR_MIXED=$(/usr/bin/cygpath -aw "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED")
        apply_ocaml_crosscompile_patch_PATCH_MIXED=$(/usr/bin/cygpath -aw "$apply_ocaml_crosscompile_patch_PATCH_MIXED")
    fi
    # Before packaging any of these artifacts the CI will likely do a `git clean -d -f -x` to reduce the
    # size and increase the safety of the artifacts. So we do a `git commit` after we have patched so
    # the reproducible source code has the patches applied, even after the `git clean`.
    # log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" apply --verbose "$apply_ocaml_crosscompile_patch_PATCH_MIXED"
    log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" config user.email "nobody+autopatcher@diskuv.ocaml.org"
    log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" config user.name  "Auto Patcher"
    git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" am --abort 2>/dev/null || true # clean any previous interrupted mail patch
    {
        printf "From: nobody+autopatcher@diskuv.ocaml.org\n"
        printf "Subject: OCaml cross-compiling patch %s\n" "$apply_ocaml_crosscompile_patch_PATCHFILE"
        printf "Date: 1 Jan 2000 00:00:00 +0000\n"
        printf "\n"
        printf "Reproducible patch\n"
        printf "\n"
        printf "%s\n" "---"
        $DKMLSYS_CAT "$apply_ocaml_crosscompile_patch_PATCH_MIXED"
    } | log_trace git -C "$apply_ocaml_crosscompile_patch_SRCDIR_MIXED" am --ignore-date --committer-date-is-author-date
}

# ---------------------
# Get OCaml source code

# Set BUILDHOST_ARCH
build_machine_arch

get_ocaml_source() {
    get_ocaml_source_SRCUNIX="$1"
    shift
    get_ocaml_source_SRCMIXED="$1"
    shift
    get_ocaml_source_TARGETPLATFORM="$1"
    shift
    if [ ! -e "$get_ocaml_source_SRCUNIX/Makefile" ] || [ ! -e "$get_ocaml_source_SRCUNIX/.git" ]; then
        install -d "$get_ocaml_source_SRCUNIX"
        log_trace rm -rf "$get_ocaml_source_SRCUNIX" # clean any partial downloads
        log_trace git clone --recurse-submodules https://github.com/ocaml/ocaml "$get_ocaml_source_SRCMIXED"
        log_trace git -C "$get_ocaml_source_SRCMIXED" -c advice.detachedHead=false checkout "$GIT_COMMITID_OR_TAG"
    else
        # allow tag to move (for development and for emergency fixes), if the user chose a tag rather than a commit
        if git -C "$get_ocaml_source_SRCMIXED" tag -l "$GIT_COMMITID_OR_TAG" | awk 'BEGIN{nonempty=0} NF>0{nonempty+=1} END{exit nonempty==0}'; then git -C "$get_ocaml_source_SRCMIXED" tag -d "$GIT_COMMITID_OR_TAG"; fi
        log_trace git -C "$get_ocaml_source_SRCMIXED" fetch --tags
        log_trace git -C "$get_ocaml_source_SRCMIXED" -c advice.detachedHead=false checkout "$GIT_COMMITID_OR_TAG"
        log_trace git -C "$get_ocaml_source_SRCMIXED" reset --hard "$GIT_COMMITID_OR_TAG" # need patches to apply cleanly, so blow away any modified files tracked by Git
        log_trace git -C "$get_ocaml_source_SRCMIXED" submodule update --init --recursive
    fi

    # Install msvs-detect
    if [ ! -e "$get_ocaml_source_SRCUNIX"/msvs-detect ]; then
        DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_PLATFORM=$get_ocaml_source_TARGETPLATFORM autodetect_compiler --msvs-detect "$WORK"/msvs-detect
        install "$WORK"/msvs-detect "$get_ocaml_source_SRCUNIX"/msvs-detect
    fi

    # Windows needs flexdll, although 4.13.x+ has a "--with-flexdll" option which relies on the `flexdll` git submodule
    if [ ! -e "$get_ocaml_source_SRCUNIX"/flexdll ]; then
        log_trace downloadfile https://github.com/alainfrisch/flexdll/archive/0.39.tar.gz "$get_ocaml_source_SRCUNIX/flexdll.tar.gz" 51a6ef2e67ff475c33a76b3dc86401a0f286c9a3339ee8145053ea02d2fb5974
    fi
}

# Why multiple source directories?
# It is hard to reason about mutated source directories with different-platform object files, so we use a pristine source dir
# for the host and other pristine source dirs for each target.

get_ocaml_source "$OCAMLSRC_UNIX" "$OCAMLSRC_MIXED" "$BUILDHOST_ARCH"

# Find but do not apply the cross-compiling patches to the host ABI
_OCAMLVER=$(awk 'NR==1{print}' "$OCAMLSRC_UNIX"/VERSION)
find_ocaml_crosscompile_patch "$_OCAMLVER"

if [ -n "$TARGETABIS" ]; then
    if [ -z "$OCAMLPATCHEXTRA" ]; then
        printf "WARNING: OCaml version %s does not yet have patches for cross-compiling\n" "$_OCAMLVER" >&2
    fi

    # Loop over each target abi script file; each file separated by semicolons, and each term with an equals
    printf "%s\n" "$TARGETABIS" | sed 's/;/\n/g' | sed 's/^\s*//; s/\s*$//' > "$WORK"/tabi
    while IFS= read -r _abientry
    do
        _targetabi=$(printf "%s" "$_abientry" | sed 's/=.*//')
        # git clone
        get_ocaml_source "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml" "$TARGETDIR_MIXED/opt/mlcross/$_targetabi/src/ocaml" "$_targetabi"
        # git patch src/ocaml
        apply_ocaml_crosscompile_patch "$OCAMLPATCHFILE"  "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml"
        if [ -n "$OCAMLPATCHEXTRA" ]; then
            apply_ocaml_crosscompile_patch "$OCAMLPATCHEXTRA" "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml"
        fi
        # git patch src/ocaml/flexdll
        apply_ocaml_crosscompile_patch "reproducible-compile-ocaml-cross_flexdll_0_39.patch" "$TARGETDIR_UNIX/opt/mlcross/$_targetabi/src/ocaml/flexdll"
    done < "$WORK"/tabi
fi

# ---------------------------
# Patch the sources


# ---------------------------
# Finish

# Copy self into share/dkml-bootstrap/100-compile-ocaml
export BOOTSTRAPNAME=100-compile-ocaml
export DEPLOYDIR_UNIX="$TARGETDIR_UNIX"
# shellcheck disable=SC2016
COMMON_ARGS=(-d '"$PWD/'"$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME"'"')
install_reproducible_common
install_reproducible_readme           installtime/unix/private/reproducible-compile-ocaml-README.md
install_reproducible_file             installtime/unix/private/reproducible-compile-ocaml-check_linker.sh
install_reproducible_file             installtime/unix/private/reproducible-compile-ocaml-functions.sh
install_reproducible_file             installtime/unix/private/reproducible-compile-ocaml-example_1.sh
if [ -n "$TARGETABIS" ]; then
    _accumulator=
    # Loop over each target abi script file; each file separated by semicolons, and each term with an equals
    printf "%s\n" "$TARGETABIS" | sed 's/;/\n/g' | sed 's/^\s*//; s/\s*$//' > "$WORK"/tabi
    while IFS= read -r _abientry
    do
        _targetabi=$(printf "%s" "$_abientry" | sed 's/=.*//')
        _abiscript=$(printf "%s" "$_abientry" | sed 's/^[^=]*=//')

        # Since we want the ABI scripts to be reproducible, we install them in a reproducible place and set
        # the reproducible arguments (-a) to point to that reproducible place.
        _script="\"\$PWD\"/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME/installtime/unix/private/reproducible-compile-ocaml-targetabi-$_targetabi.sh"
        if [ -n "$_accumulator" ]; then
            _accumulator="$_accumulator;$_targetabi=$_script"
        else
            _accumulator="$_targetabi=$_script"
        fi
        install_reproducible_generated_file "$_abiscript" installtime/unix/private/reproducible-compile-ocaml-targetabi-"$_targetabi".sh
    done < "$WORK"/tabi
    SETUP_ARGS+=( -a "$_accumulator" )
    BUILD_CROSS_ARGS+=( -a "$_accumulator" )
fi
install_reproducible_system_packages  installtime/unix/private/reproducible-compile-ocaml-0-system.sh
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-ocaml-1-setup.sh "${COMMON_ARGS[@]}" "${SETUP_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-ocaml-2-build_host.sh "${COMMON_ARGS[@]}" "${BUILD_HOST_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-ocaml-3-build_cross.sh "${COMMON_ARGS[@]}" "${BUILD_CROSS_ARGS[@]}"
