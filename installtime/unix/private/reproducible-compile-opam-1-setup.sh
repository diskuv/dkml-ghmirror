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
# reproducible-compile-opam-1-setup.sh -d DKMLDIR -t TARGETDIR -g GIT_TAG [-a PLATFORM]
#
# Sets up the source code for a reproducible build

set -euf -o pipefail

# ------------------
# BEGIN Command line processing

SETUP_ARGS=()
BUILD_ARGS=()
TRIM_ARGS=()

# Since installtime/windows/Machine/Machine.psm1 has minimum VS14 we only select that version
# or greater. We'll ignore '10.0' (Windows SDK 10) which may bundle Visual Studio 2015, 2017 or 2019.
# Also we do _not_ use the environment (ie. no '@' in MSVS_PREFERENCE) since that isn't reproducible,
# and also because it sets MSVS_* variables to empty if it thinks the environment is correct (but we
# _always_ want MSVS_* set since ./configure script branches on MSVS_* being non-empty).
OPT_MSVS_PREFERENCE='VS16.*;VS15.*;VS14.0' # KEEP IN SYNC with 2-build.sh

usage() {
    echo "Usage:" >&2
    echo "    reproducible-compile-opam-1-setup.sh" >&2
    echo "        -h                     Display this help message." >&2
    echo "        -d DIR -t DIR -v TAG   Setup compilation of Opam." >&2
    echo "Options" >&2
    echo "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    echo "   -t DIR: Target directory" >&2
    echo "   -v TAG: Git tag" >&2
    echo "   -a PLATFORM: Target platform for bootstrapping an OCaml compiler." >&2
    echo "      Defaults to 'dev'. Ex. dev, windows_x86, windows_x86_64" >&2
    echo "   -b PREF: The msvs-tools MSVS_PREFERENCE setting, needed only for Windows." >&2
    echo "      Defaults to '$OPT_MSVS_PREFERENCE' which, because it does not include '@'," >&2
    echo "      will not choose a compiler based on environment variables." >&2
    echo "      Confer with https://github.com/metastack/msvs-tools#msvs-detect" >&2
}

DKMLDIR=
GIT_TAG=
TARGETDIR=
while getopts ":d:v:t:a:b:h" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        d )
            DKMLDIR="$OPTARG"
            if [[ ! -e "$DKMLDIR/.dkmlroot" ]]; then
                echo "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2;
                usage
                exit 1
            fi
        ;;
        v )
            GIT_TAG="$OPTARG"
            SETUP_ARGS+=( -v "$GIT_TAG" )
        ;;
        t )
            TARGETDIR="$OPTARG"
            BUILD_ARGS+=( -t . )
            TRIM_ARGS+=( -t . )
            SETUP_ARGS+=( -t . )
        ;;
        a )
            BUILD_ARGS+=( -a "$OPTARG" )
            SETUP_ARGS+=( -a "$OPTARG" )
        ;;
        b )
            BUILD_ARGS+=( -b "$OPTARG" )
            SETUP_ARGS+=( -b "$OPTARG" )
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [[ -z "$DKMLDIR" || -z "$GIT_TAG" || -z "$TARGETDIR" ]]; then
    echo "Missing required options" >&2
    usage
    exit 1
fi

# END Command line processing
# ------------------

# shellcheck disable=SC2034
PLATFORM=dev # not actually in the dev platform but we are just pulling the "common" tool functions (so we can choose whatever platform we like)

# shellcheck disable=SC1091
source "$DKMLDIR/runtime/unix/_common_tool.sh"

disambiguate_filesystem_paths

# Bootstrapping vars
TARGETDIR_UNIX=$(install -d "$TARGETDIR" && cd "$TARGETDIR" && pwd) # better than cygpath: handles TARGETDIR=. without trailing slash, and works on Unix/Windows
if [[ -x /usr/bin/cygpath ]]; then
    OPAMSRC_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/src/opam")
    OPAMSRC_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/src/opam")
else
    OPAMSRC_UNIX="$TARGETDIR_UNIX/src/opam"
    OPAMSRC_MIXED="$OPAMSRC_UNIX"
fi

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

# Get Diskuv's Opam if not present already
if [[ ! -e "$OPAMSRC_UNIX/Makefile" ]] || [[ ! -e "$OPAMSRC_UNIX/.git" ]]; then
    install -d "$OPAMSRC_UNIX"
    rm -rf "$OPAMSRC_UNIX" # clean any partial downloads
    git clone -b "$GIT_TAG" https://github.com/diskuv/opam "$OPAMSRC_MIXED"
else
    if git -C "$OPAMSRC_MIXED" tag -l "$GIT_TAG" | awk 'BEGIN{nonempty=0} NF>0{nonempty+=1} END{exit nonempty==0}'; then git -C "$OPAMSRC_MIXED" tag -d "$GIT_TAG"; fi # allow tag to move (for development and for emergency fixes)
    git -C "$OPAMSRC_MIXED" fetch --tags
    git -C "$OPAMSRC_MIXED" -c advice.detachedHead=false checkout "$GIT_TAG"
fi

# PATCH - msvs-detect
# Ensure we have a recent (0.5.0+) version of msvs.
# 0.5.0+ will detect Diskuv OCaml installations (and others) that use Visual Studio Build Tools.
# Remove this patch when Opam branch is updated.
install -d "$WORK"/msvs
MSVS_MIXED="$WORK"/msvs
ZIP_MIXED="$WORK"/msvs-tools.zip
if is_unixy_windows_build_machine; then
    # unzip and wget may be native Windows
    ZIP_MIXED=$(cygpath -am "$ZIP_MIXED")
    MSVS_MIXED=$(cygpath -am "$MSVS_MIXED")
fi
wget https://github.com/metastack/msvs-tools/archive/refs/tags/0.5.0.zip -O "$ZIP_MIXED"
unzip -j -d "$MSVS_MIXED" "$ZIP_MIXED"
install "$WORK"/msvs/msvs-detect "$OPAMSRC_UNIX"/shell/msvs-detect

# Copy self into share/dkml-bootstrap/100-compile-opam
export BOOTSTRAPNAME=100-compile-opam
export DEPLOYDIR_UNIX="$TARGETDIR_UNIX"
COMMON_ARGS=(-d '"'"$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME"'"')
install_reproducible_common
install_reproducible_readme           installtime/unix/private/reproducible-compile-opam-README.md
install_reproducible_system_packages  installtime/unix/private/reproducible-compile-opam-0-system.sh
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-opam-1-setup.sh "${COMMON_ARGS[@]}" "${SETUP_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-opam-2-build.sh "${COMMON_ARGS[@]}" "${BUILD_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-opam-9-trim.sh  "${COMMON_ARGS[@]}" "${TRIM_ARGS[@]}"
