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
# reproducible-compile-opam-1-setup.sh -d DKMLDIR -t TARGETDIR -g GIT_COMMITID_OR_TAG [-a PLATFORM]
#
# Sets up the source code for a reproducible build of Opam

set -euf

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
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    reproducible-compile-opam-1-setup.sh" >&2
    printf "%s\n" "        -h                       Display this help message." >&2
    printf "%s\n" "        -d DIR -t DIR -v COMMIT  Setup compilation of Opam." >&2
    printf "%s\n" "Options" >&2
    printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    printf "%s\n" "   -t DIR: Target directory" >&2
    printf "%s\n" "   -u URL: Git repository url. Defaults to https://github.com/ocaml/opam" >&2
    printf "%s\n" "   -v COMMIT: Git commit or tag for the git repository. Strongly prefer a commit id for much stronger" >&2
    printf "%s\n" "      reproducibility guarantees" >&2
    printf "%s\n" "   -a PLATFORM: Target platform for bootstrapping an OCaml compiler." >&2
    printf "%s\n" "      Defaults to 'dev' (deprecated). Ex. dev, windows_x86, windows_x86_64" >&2
    printf "%s\n" "   -b PREF: The msvs-tools MSVS_PREFERENCE setting, needed only for Windows." >&2
    printf "%s\n" "      Defaults to '$OPT_MSVS_PREFERENCE' which, because it does not include '@'," >&2
    printf "%s\n" "      will not choose a compiler based on environment variables." >&2
    printf "%s\n" "      Confer with https://github.com/metastack/msvs-tools#msvs-detect" >&2
    printf "%s\n" "   -c OCAMLHOME: Optional. The home directory for OCaml containing bin/ocamlc and other OCaml binaries" >&2
    printf "%s\n" "      and libraries. If not specified will bootstrap its own OCaml home" >&2
    printf "%s\n" "   -e ON|OFF: Optional; default is OFF. If ON will preserve .git folders in the target directory" >&2
}

DKMLDIR=
GIT_URL=https://github.com/ocaml/opam
GIT_COMMITID_OR_TAG=
TARGETDIR=
PRESERVEGIT=OFF
PLATFORM=dev
while getopts ":d:u:v:t:a:b:c:e:h" opt; do
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
        u )
            GIT_URL="$OPTARG"
            SETUP_ARGS+=( -u "$GIT_URL" )
        ;;
        v )
            GIT_COMMITID_OR_TAG="$OPTARG"
            SETUP_ARGS+=( -v "$GIT_COMMITID_OR_TAG" )
        ;;
        t )
            TARGETDIR="$OPTARG"
            BUILD_ARGS+=( -t . )
            TRIM_ARGS+=( -t . )
            SETUP_ARGS+=( -t . )
        ;;
        a )
            PLATFORM="$OPTARG"
            BUILD_ARGS+=( -a "$OPTARG" )
            SETUP_ARGS+=( -a "$OPTARG" )
        ;;
        b )
            BUILD_ARGS+=( -b "$OPTARG" )
            SETUP_ARGS+=( -b "$OPTARG" )
        ;;
        c )
            BUILD_ARGS+=( -c "$OPTARG" )
            SETUP_ARGS+=( -c "$OPTARG" )
        ;;
        e )
            PRESERVEGIT="$OPTARG"
            SETUP_ARGS+=( -e "$PRESERVEGIT" )
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

BUILD_ARGS+=( -e "$PRESERVEGIT" )
TRIM_ARGS+=( -e "$PRESERVEGIT" )

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

# Get Opam if not present already
if [ ! -e "$OPAMSRC_UNIX/Makefile" ] || [ ! -e "$OPAMSRC_UNIX/.git" ]; then
    install -d "$OPAMSRC_UNIX"
    log_trace rm -rf "$OPAMSRC_UNIX" # clean any partial downloads
    log_trace git clone "$GIT_URL" "$OPAMSRC_MIXED"
    log_trace git -C "$OPAMSRC_MIXED" -c advice.detachedHead=false checkout "$GIT_COMMITID_OR_TAG"
else
    if git -C "$OPAMSRC_MIXED" tag -l "$GIT_COMMITID_OR_TAG" | awk 'BEGIN{nonempty=0} NF>0{nonempty+=1} END{exit nonempty==0}'; then git -C "$OPAMSRC_MIXED" tag -d "$GIT_COMMITID_OR_TAG"; fi # allow tag to move (for development and for emergency fixes)
    log_trace git -C "$OPAMSRC_MIXED" fetch --tags
    log_trace git -C "$OPAMSRC_MIXED" -c advice.detachedHead=false checkout "$GIT_COMMITID_OR_TAG"
fi

# REPLACE - msvs-detect
if [ ! -e "$OPAMSRC_UNIX"/shell/msvs-detect ] || [ ! -e "$OPAMSRC_UNIX"/shell/msvs-detect.complete ]; then
    if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
        if is_dev_platform; then
            # Set BUILDHOST_ARCH
            build_machine_arch
            DKML_TARGET_PLATFORM=$BUILDHOST_ARCH autodetect_compiler --msvs-detect "$WORK"/msvs-detect
        else
            DKML_TARGET_PLATFORM=$PLATFORM autodetect_compiler --msvs-detect "$WORK"/msvs-detect
        fi
    else
        DKML_TARGET_PLATFORM=$PLATFORM autodetect_compiler --msvs-detect "$WORK"/msvs-detect
    fi
    install "$WORK"/msvs-detect "$OPAMSRC_UNIX"/shell/msvs-detect
    touch "$OPAMSRC_UNIX"/shell/msvs-detect.complete
fi

# Copy self into share/dkml-bootstrap/110-compile-opam
export BOOTSTRAPNAME=110-compile-opam
export DEPLOYDIR_UNIX="$TARGETDIR_UNIX"
# shellcheck disable=SC2016
COMMON_ARGS=(-d '"$PWD/'"$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME"'"')
install_reproducible_common
install_reproducible_readme           installtime/unix/private/reproducible-compile-opam-README.md
install_reproducible_system_packages  installtime/unix/private/reproducible-compile-opam-0-system.sh
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-opam-1-setup.sh "${COMMON_ARGS[@]}" "${SETUP_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-opam-2-build.sh "${COMMON_ARGS[@]}" "${BUILD_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-compile-opam-9-trim.sh  "${COMMON_ARGS[@]}" "${TRIM_ARGS[@]}"
