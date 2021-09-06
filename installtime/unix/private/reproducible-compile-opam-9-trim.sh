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
# reproducible-compile-windows-opam-9-trim.sh -d DKMLDIR -t TARGETDIR
#
# Remove intermediate files from reproducible target directory

set -euf -o pipefail

# ------------------
# BEGIN Command line processing

function usage () {
    echo "Usage:" >&2
    echo "    reproducible-compile-opam-9-trim.sh" >&2
    echo "        -h                     Display this help message." >&2
    echo "        -d DIR -t DIR          Do trimming of Opam install." >&2
    echo "Options" >&2
    echo "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    echo "   -t DIR: Target directory" >&2
}

DKMLDIR=
TARGETDIR=
while getopts ":d:t:h" opt; do
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
        t ) TARGETDIR="$OPTARG";;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [[ -z "$DKMLDIR" || -z "$TARGETDIR" ]]; then
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
OPAMSRC="$TARGETDIR_UNIX/src/opam"

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

if [[ "${DKML_BUILD_TRACE:-ON}" = ON ]]; then set -x; fi

# Opam already includes a command to get rid of all build files
if [[ -e "$OPAMSRC/Makefile"  ]]; then
    make -C "$OPAMSRC" distclean
fi

# Also get rid of Git files
if [[ -e "$OPAMSRC/.git" ]]; then
    rm -rf "$OPAMSRC/.git"
fi
