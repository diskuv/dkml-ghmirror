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
# Fix up symlinks like those pointing to Opam roots in C:\Opam, and also C:\Windows if
# your $env:SYSTEMROOT is non-standard.
#
# Not only do we not maintain a C:\Opam directory, we want relative symlinks since we'll be cloning those Opam roots.
#
# Example 1:
#         Actual: $PWD/build/_tools/common/ocaml-opam/msvc-amd64/opam/.opam/plugins/bin/opam-depext.exe -> /cygdrive/c/opam/.opam/4.12/bin/opam-depext.exe
#   1. C:\ Move : $PWD     # (1)/(2) make an absolute path to (Actual). This value does not need to be $PWD but it does need to be absolute.
#   2. C:\ Move :      build/_tools/common/ocaml-opam/msvc-amd64/     # Originally there was a file C:/opam/.opam/plugins/bin/opam-depext.exe but we moved C:\
#   3. C:\ Clone: /cygdrive/c/                        # We cloned opam/.opam/4.12/bin/opam-depext.exe which is everything on the right hand side except /c/
#        Desired: $PWD/build/_tools/common/ocaml-opam/msvc-amd64/opam/.opam/plugins/bin/opam-depext.exe -> ../../../4.12/bin/opam-depext.exe
#
# Terminology in analogy with Example 1:
#         Actual: REFEREE -> ABSOLUTE_REFERENT
#   1. Move Base: BASE_MOVEDIR
#   2.  Move Rel: RELATIVE_MOVEDIR
#   3.     Clone: ABSOLUTE_CLONEDIR
#        Desired: REFEREE -> RELATIVE_REFERENT
#
# Example 2: if your $env:SYSTEMROOT was Z:\Windows
#         Actual: $PWD/build/_tools/common/ocaml-opam/msvc-amd64/cygwin64/etc/hosts -> /cygdrive/c/Windows/System32/drivers/etc/hosts
#        Desired: $PWD/build/_tools/common/ocaml-opam/msvc-amd64/cygwin64/etc/hosts -> /cygdrive/z/Windows/System32/drivers/etc/hosts
#
# Usage: <this_script> REFEREE BASE_MOVEDIR RELATIVE_MOVEDIR ABSOLUTE_CLONEDIR
# Outcome:
#  * No REFEREE will change if ABSOLUTE_REFERENT does not start with ABSOLUTE_CLONEDIR (this is idempotency)
#  * Otherwise:
#    a) if ABSOLUTE_REFERENT points to C:\Windows and is dangling (does not point to real file), this script
#       will change REFERREE as in Example 2
#    b) else this script will change REFEREE to RELATIVE_REFERENT as in Example 1

set -euf -o pipefail

REFEREE=$1
shift
BASE_MOVEDIR=$1
shift
RELATIVE_MOVEDIR=$1
shift
ABSOLUTE_CLONEDIR=$1
shift

REFEREE_DIRNAME=$(dirname "$REFEREE")
# echo "REFEREE = $REFEREE"
# echo "REFEREE_DIRNAME = $REFEREE_DIRNAME"
# echo "BASE_MOVEDIR = $BASE_MOVEDIR"
# echo "RELATIVE_MOVEDIR = $RELATIVE_MOVEDIR"
# echo "ABSOLUTE_CLONEDIR = $ABSOLUTE_CLONEDIR"

shopt -s nocasematch # Windows is case insensitive! Could be /cygdrive/c/windows/ or /cygdrive/c/WINDOWS/

ABSOLUTE_REFERENT=$(readlink "$REFEREE")
case "$ABSOLUTE_REFERENT" in
    /cygdrive/c/windows/*)
        # Example 2
        ###########

        # Only proceed if the referent is not dangling (idempotency, and edge case if
        # $env:SYSTEMROOT were C:\Windows\NonStandardSubDirectory instead of customary C:\Windows).
        if [ -e $ABSOLUTE_REFERENT ]; then #TODO
            exit 0
        fi
        # manual testing 20210807: both cygpath -a 'Z:\Windows\' and cygpath -a 'Z:\Windows\\' gave /cygdrive/z/Windows/
        DESIRED_SYSTEMROOT=$(cygpath -a "$SYSTEMROOT\\")
        # Tricky thing is getting quoting correct while only replacing the first /cygdrive/c.
        # we delegate to Bash to do it right.
        # shellcheck disable=SC1090
        source <(set | grep ^ABSOLUTE_REFERENT= | sed "s,/cygdrive/c/windows/,$DESIRED_SYSTEMROOT,i")

        ln -sf "$ABSOLUTE_REFERENT" "$REFEREE"
        ;;
    "$ABSOLUTE_CLONEDIR"*)
        # Example 1
        ###########

        RELATIVE_REFERENT="${BASE_MOVEDIR}/${RELATIVE_MOVEDIR}/${ABSOLUTE_REFERENT#$ABSOLUTE_CLONEDIR}"
        # echo "RELATIVE_REFERENT = $RELATIVE_REFERENT"

        SYMLINK_PATH=$(realpath --no-symlinks --relative-to="$REFEREE_DIRNAME" "$RELATIVE_REFERENT")
        # echo "SYMLINK_PATH = $SYMLINK_PATH"

        ln -sf "$SYMLINK_PATH" "$REFEREE"
        ;;
esac

