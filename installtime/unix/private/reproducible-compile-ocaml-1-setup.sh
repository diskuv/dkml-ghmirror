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
#      -v COMMIT [-a TARGETABICOMPILER] [-c HOSTCOMPILERARCH]
#
# Sets up the source code for a reproducible compilation of OCaml

set -euf

# ------------------
# BEGIN Command line processing

SETUP_ARGS=()
BUILD_ARGS=()

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
        printf "%s\n" "the '-a TARGETABICOMPILER' option."
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
        printf "%s\n" "   -a TARGETABICOMPILER: Optional. A self-contained Posix shell script that can be sourced to set the"
        printf "%s\n" "      compiler environment variables for the target ABI. If not specified then the OCaml environment"
        printf "%s\n" "      will be purely for the host ABI. All path should use the native host platform's path"
        printf "%s\n" "      conventions like '/usr' on Unix and 'C:\VS2019' on Windows. The compiler environment variables include:"
        printf "%s\n" "        ASM - The assembly language compiler that targets machine code for the target ABI. On Windows this"
        printf "%s\n" "          must be a MASM compiler like ml/ml64.exe"
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
        printf "%s\n" "   -b PREF: Required and used only for the MSVC compiler. This is the msvs-tools MSVS_PREFERENCE setting"
        printf "%s\n" "      needed to detect the Windows compiler for the host ABI. Not used when '-e DKMLHOSTABI' is specified."
        printf "%s\n" "      Defaults to '$OPT_MSVS_PREFERENCE' which, because it does not include '@',"
        printf "%s\n" "      will not choose a compiler based on environment variables that would disrupt reproducibility."
        printf "%s\n" "      Confer with https://github.com/metastack/msvs-tools#msvs-detect"
        printf "%s\n" "   -c HOSTCOMPILERARCH: Useful only for the MSVC compiler. Defaults to auto. mingw64, mingw, msvc64, msvc or auto"
        printf "%s\n" "   -e DKMLHOSTABI: Optional. Use the Diskuv OCaml compiler detector find a compiler matching the ABI."
        printf "%s\n" "      Especially useful to find a 32-bit Windows host compiler that can use 64-bits of memory for the compiler."
        printf "%s\n" "      Values include: windows_x86, windows_x86_64; others are/will be documented on https://diskuv.gitlab.io/diskuv-ocaml"
        printf "%s\n" "   -f CONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure. --with-flexdll and --host will have already"
        printf "%s\n" "      been set appropriately, but you can override the --host heuristic by adding it to -f CONFIGUREARGS"
    } >&2
}

DKMLDIR=
GIT_COMMITID_OR_TAG=
TARGETDIR=
HOSTCOMPILERARCH=auto
MSVS_PREFERENCE="$OPT_MSVS_PREFERENCE"
while getopts ":d:v:t:a:b:c:e:f:h" opt; do
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
            BUILD_ARGS+=( -t . )
            SETUP_ARGS+=( -t . )
        ;;
        a )
            BUILD_ARGS+=( -a "$OPTARG" )
            SETUP_ARGS+=( -a "$OPTARG" )
        ;;
        b )
            MSVS_PREFERENCE="$OPTARG"
        ;;
        c )
            HOSTCOMPILERARCH="$OPTARG"
            SETUP_ARGS+=( -c "$OPTARG" )
        ;;
        e )
            SETUP_ARGS+=( -e "$OPTARG" )
            BUILD_ARGS+=( -e "$OPTARG" )
        ;;
        f )
            SETUP_ARGS+=( -f "$OPTARG" )
            BUILD_ARGS+=( -f "$OPTARG" )
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
BUILD_ARGS+=( -b "'$MSVS_PREFERENCE'" -c "$HOSTCOMPILERARCH" )

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
else
    OCAMLSRC_UNIX="$TARGETDIR_UNIX/src/ocaml"
    OCAMLSRC_MIXED="$OCAMLSRC_UNIX"
fi

# To be portable whether we build scripts in a container or not, we
# change the directory to always be in the DKMLDIR (just like a container
# sets the directory to be /work)
cd "$DKMLDIR"

# Get OCaml if not present already
if [ ! -e "$OCAMLSRC_UNIX/Makefile" ] || [ ! -e "$OCAMLSRC_UNIX/.git" ]; then
    install -d "$OCAMLSRC_UNIX"
    rm -rf "$OCAMLSRC_UNIX" # clean any partial downloads
    git clone --recurse-submodules https://github.com/ocaml/ocaml "$OCAMLSRC_MIXED"
    git -C "$OCAMLSRC_MIXED" -c advice.detachedHead=false checkout "$GIT_COMMITID_OR_TAG"
else
    # allow tag to move (for development and for emergency fixes), if the user chose a tag rather than a commit
    if git -C "$OCAMLSRC_MIXED" tag -l "$GIT_COMMITID_OR_TAG" | awk 'BEGIN{nonempty=0} NF>0{nonempty+=1} END{exit nonempty==0}'; then git -C "$OCAMLSRC_MIXED" tag -d "$GIT_COMMITID_OR_TAG"; fi
    git -C "$OCAMLSRC_MIXED" fetch --tags
    git -C "$OCAMLSRC_MIXED" -c advice.detachedHead=false checkout "$GIT_COMMITID_OR_TAG"
    git -C "$OCAMLSRC_MIXED" submodule update --init --recursive
fi

# Ensure we have a recent (0.5.0+) version of msvs.
# 0.5.0+ will detect Diskuv OCaml installations (and others) that use Visual Studio Build Tools.
install -d "$WORK"/msvs
MSVS_MIXED="$WORK"/msvs
ZIP_MIXED="$WORK"/msvs-tools.zip
if [ -x /usr/bin/cygpath ]; then
    # unzip and wget may be native Windows so use mixed Unix/Windows path convention
    ZIP_MIXED=$(/usr/bin/cygpath -am "$ZIP_MIXED")
    MSVS_MIXED=$(/usr/bin/cygpath -am "$MSVS_MIXED")
fi
downloadfile https://github.com/metastack/msvs-tools/archive/refs/tags/0.5.0.zip "$ZIP_MIXED" 9e0a87dd09e6663dac9396a5a7fc9ec7c0b2b22ccf1f5bd9a33bf2543324aad2
unzip -j -d "$MSVS_MIXED" "$ZIP_MIXED"
install "$WORK"/msvs/msvs-detect "$OCAMLSRC_UNIX"/msvs-detect

# Windows needs flexdll, although 4.13.x+ has a "--with-flexdll" option which relies on the `flexdll` git submodule
if [ ! -e "$OCAMLSRC_UNIX"/flexdll ]; then
    downloadfile https://github.com/alainfrisch/flexdll/archive/0.39.tar.gz "$OCAMLSRC_UNIX/flexdll.tar.gz" 51a6ef2e67ff475c33a76b3dc86401a0f286c9a3339ee8145053ea02d2fb5974
fi

# Copy self into share/dkml-bootstrap/100-compile-ocaml
export BOOTSTRAPNAME=100-compile-ocaml
export DEPLOYDIR_UNIX="$TARGETDIR_UNIX"
# shellcheck disable=SC2016
COMMON_ARGS=(-d '"$PWD/'"$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME"'"')
install_reproducible_common
install_reproducible_readme           installtime/unix/private/reproducible-compile-ocaml-README.md
install_reproducible_file             installtime/unix/private/reproducible-compile-ocaml-check_linker.sh
install_reproducible_system_packages  installtime/unix/private/reproducible-compile-ocaml-0-system.sh
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-ocaml-1-setup.sh "${COMMON_ARGS[@]}" "${SETUP_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-ocaml-2-build_host.sh "${COMMON_ARGS[@]}" "${BUILD_ARGS[@]}"
# install_reproducible_script_with_args installtime/unix/private/reproducible-compile-ocaml-2-build_target.sh "${COMMON_ARGS[@]}" "${BUILD_ARGS[@]}"
