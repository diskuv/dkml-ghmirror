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
# reproducible-fetch-ocaml-opam-repo-1-setup.sh -d DKMLDIR -t TARGETDIR -g DOCKER_IMAGE [-a HOST] [-b GIT_EXE]
#
# Sets up the source code for a reproducible build

set -euf -o pipefail

# ------------------
# BEGIN Command line processing

SETUP_ARGS=()
BUILD_ARGS=()

function usage () {
    echo "Usage:" >&2
    echo "    reproducible-fetch-ocaml-opam-repo-1-setup.sh" >&2
    echo "        -h                              Display this help message." >&2
    echo "        -d DIR -t DIR -v IMAGE -a ARCH  Setup fetching of ocaml/opam repository." >&2
    echo "Options" >&2
    echo "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    echo "   -t DIR: Target directory" >&2
    echo "   -v IMAGE: Docker image" >&2
    echo "   -a ARCH: Docker architecture. Ex. amd64" >&2
}

DKMLDIR=
DOCKER_IMAGE=
DOCKER_ARCH=
TARGETDIR=
while getopts ":d:v:t:a:h" opt; do
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
            DOCKER_IMAGE="$OPTARG"
            SETUP_ARGS+=( -v "$DOCKER_IMAGE" )
            BUILD_ARGS+=( -v "$DOCKER_IMAGE" )
        ;;
        t ) 
            TARGETDIR="$OPTARG"
            SETUP_ARGS+=( -t . )
            BUILD_ARGS+=( -t . )
        ;;
        a )
            DOCKER_ARCH="$OPTARG"
            SETUP_ARGS+=( -a "$DOCKER_ARCH" )
            BUILD_ARGS+=( -a "$DOCKER_ARCH" )
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [[ -z "$DKMLDIR" || -z "$DOCKER_IMAGE" || -z "$TARGETDIR" || -z "$DOCKER_ARCH" ]]; then
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

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

installtime/unix/private/download-moby-downloader.sh "$WORK"

# Copy self into share/dkml-bootstrap/200-fetch-ocaml-opam-repo
export BOOTSTRAPNAME=200-fetch-ocaml-opam-repo
export DEPLOYDIR_UNIX="$TARGETDIR_UNIX"
COMMON_ARGS=(-d '"'"$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME"'"')
install_reproducible_common
install_reproducible_readme           installtime/unix/private/reproducible-fetch-ocaml-opam-repo-README.md
install_reproducible_system_packages  installtime/unix/private/reproducible-fetch-ocaml-opam-repo-0-system.sh
install_reproducible_script_with_args installtime/unix/private/reproducible-fetch-ocaml-opam-repo-1-setup.sh "${COMMON_ARGS[@]}" "${SETUP_ARGS[@]}"
install_reproducible_script_with_args installtime/unix/private/reproducible-fetch-ocaml-opam-repo-2-build.sh "${COMMON_ARGS[@]}" "${BUILD_ARGS[@]}"
install_reproducible_file             installtime/unix/private/download-moby-downloader.sh
install_reproducible_file             installtime/unix/private/moby-download-docker-image.sh
install_reproducible_file             installtime/unix/private/moby-extract-opam-root.sh
if is_cygwin_build_machine; then
    install_reproducible_file         installtime/cygwin/idempotent-fix-symlink.sh
fi
install_reproducible_generated_file   "$WORK"/download-frozen-image-v2.sh installtime/unix/private/download-frozen-image-v2.sh
