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
# reproducible-fetch-ocaml-opam-repo-9-trim.sh -d DKMLDIR -t TARGETDIR
#
# Remove unneeded package versions

set -euf

# Compiler specific package versions.
# These are required for the compiler version DKML supports.
export PREPINNED_4_12_0_PACKAGE_VERSIONS=(
    "camlp4:4.12+system"
    "merlin:4.3.1-412"
    "ocaml:4.12.0"
    "ocamlbrowser:4.12.0"
    "ocaml-src:4.12.0"
)
export PREPINNED_4_12_1_PACKAGE_VERSIONS=(
    "camlp4:4.12+system"
    "merlin:4.3.1-412"
    "ocaml:4.12.1"
    "ocamlbrowser:4.12.0"
    "ocaml-src:4.12.1"
)
export PREPINNED_4_13_1_PACKAGE_VERSIONS=(
    "camlp4:4.13+system"
    "merlin:4.3.2~4.13preview"
    "ocaml:4.13.1"
    "ocamlbrowser:4.13.0" # not a typo! 4.13.0 is latest
    "ocaml-src:4.13.1"
)

# Compiler agnostic package versions.
#
# The first section:
# * These are packages that are pinned because they are not lexographically the latest
# The second section:
# * The $*FlavorPackages in installtime\windows\setup-userprofile.ps1 except:
#     any in PINNED_PACKAGES_DKML_PATCHES or PINNED_PACKAGES_OPAM in installtime\unix\create-opam-switch.sh
export PREPINNED_AGNOSTIC_PACKAGE_VERSIONS=(
    "seq:base"

    "bos:0.2.0"
    "dune:2.9.0"
    "jingoo:1.4.3"
    "lsp:1.8.2"
    "ocaml-lsp-server:1.8.2"
    "ocamlfind:1.9.1"
    "ocamlformat:0.18.0"
    "ocamlformat-rpc:0.18.0"
    "ocamlformat-rpc-lib:0.18.0"
    # "ocp-indent:1.8.2-windowssupport" in PINNED_PACKAGES_DKML_PATCHES
    "sexplib:v0.14.0"
    "sha:1.14"
    "utop:2.8.0"
)

# The first section:
# * depext is unnecessary as of Opam 2.1
# The last two sections correspond to PINNED_PACKAGES_DKML_PATCHES and PINNED_PACKAGES_OPAM in installtime\unix\create-opam-switch.sh
# and MUST BE IN SYNC.
export PACKAGES_TO_REMOVE="
    depext

    dune-configurator
    bigstringaf
    ppx_expect
    digestif
    ocp-indent
    mirage-crypto
    mirage-crypto-ec
    mirage-crypto-pk
    mirage-crypto-rng
    mirage-crypto-rng-async
    mirage-crypto-rng-mirage
    ocamlbuild
    core_kernel
    feather
    ctypes
    ctypes-foreign
    ocamlfind

    dune-build-info
    jst-config
    ocaml-compiler-libs
    ocaml-variants
"

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    reproducible-fetch-ocaml-opam-repo-9-trim.sh" >&2
    echo "        -h                                      Display this help message." >&2
    echo "        -d DIR -t DIR -a ARCH -b OCAMLVERSION   Create target repository without unneeded package versions." >&2
    echo "Options" >&2
    echo "   -d DIR:     DKML directory containing a .dkmlroot file" >&2
    echo "   -t DIR:     Target directory" >&2
    echo "   -n:         Dry run" >&2
    echo "   -p PACKAGE: Consider only the named package" >&2
    echo "   -a ARCH: Docker architecture that was downloaded. Ex. amd64" >&2
    echo "   -b OCAMLVERSION: OCaml language version. Ex. 4.12.1" >&2
}

DKMLDIR=
TARGETDIR=
DOCKER_ARCH=
SINGLEPACKAGE=
OCAML_LANG_VERSION=
export DRYRUN=OFF
while getopts ":d:t:np:a:b:h" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        n )
            DRYRUN=ON
        ;;
        d )
            DKMLDIR="$OPTARG"
            if [ ! -e "$DKMLDIR/.dkmlroot" ]; then
                echo "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2;
                usage
                exit 1
            fi
        ;;
        t )
            TARGETDIR="$OPTARG"
        ;;
        p )
            SINGLEPACKAGE="$OPTARG"
        ;;
        a )
            DOCKER_ARCH="$OPTARG"
        ;;
        b )
            OCAML_LANG_VERSION="$OPTARG"
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$DKMLDIR" ] || [ -z "$TARGETDIR" ] || [ -z "$DOCKER_ARCH" ] || [ -z "$OCAML_LANG_VERSION" ]; then
    echo "Missing required options" >&2
    usage
    exit 1
fi

# END Command line processing
# ------------------

# shellcheck disable=SC2034
PLATFORM=dev # not actually in the dev platform but we are just pulling the "common" tool functions (so we can choose whatever platform we like)

# shellcheck disable=SC1091
. "$DKMLDIR/runtime/unix/_common_tool.sh"

disambiguate_filesystem_paths

# Bootstrapping vars
TARGETDIR_UNIX=$(install -d "$TARGETDIR" && cd "$TARGETDIR" && pwd) # better than cygpath: handles TARGETDIR=. without trailing slash, and works on Unix/Windows
if [ -x /usr/bin/cygpath ]; then
    OOREPO_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/$SHARE_OCAML_OPAM_REPO_RELPATH/$OCAML_LANG_VERSION")
else
    OOREPO_UNIX="$TARGETDIR_UNIX/$SHARE_OCAML_OPAM_REPO_RELPATH/$OCAML_LANG_VERSION"
fi
export OOREPO_UNIX
REPODIR_UNIX=${TARGETDIR_UNIX}/full-opam-root
BASEDIR_IN_FULL_OPAMROOT=${REPODIR_UNIX}/msvc-"$DOCKER_ARCH"


# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

# Install files and directories into $OOREPO_UNIX:
# - /packages/
if [[ "$DRYRUN" = OFF ]]; then
    install -d "$OOREPO_UNIX"
    log_trace spawn_rsync -a --delete --delete-excluded \
        --exclude '.git*' --exclude '.travis*' --exclude 'Dockerfile' --exclude '*.md' --exclude 'COPYING' \
        "$BASEDIR_IN_FULL_OPAMROOT"/cygwin64/home/opam/opam-repository/packages/ "$OOREPO_UNIX"/packages
else
    echo "Would have synchronized the '$BASEDIR_IN_FULL_OPAMROOT'/cygwin64/home/opam/opam-repository/packages/ directory with $OOREPO_UNIX/packages/"
fi

export PINFILE="$WORK"/pins
true > "$WORK"/pins
install -d "$WORK"/pin-assembly

# [assemble_prepins] populates PREPINNED_PACKAGES and PREPINNED_VERSIONS from
# PREPINNED_AGNOSTIC_PACKAGE_VERSIONS and PREPINNED_4_12_0_PACKAGE_VERSIONS, and fills in PACKAGES_PREPINNED and VERSIONS_PREPINNED
assemble_prepins() {
    assemble_prepins_PREPINNED_PACKAGES=()
    assemble_prepins_PREPINNED_VERSIONS=()
    case "$OCAML_LANG_VERSION" in
        4.12.0)
            assemble_prepins_PPVS=("${PREPINNED_AGNOSTIC_PACKAGE_VERSIONS[@]}" "${PREPINNED_4_12_0_PACKAGE_VERSIONS[@]}")
            ;;
        4.12.1)
            assemble_prepins_PPVS=("${PREPINNED_AGNOSTIC_PACKAGE_VERSIONS[@]}" "${PREPINNED_4_12_1_PACKAGE_VERSIONS[@]}")
            ;;
        4.13.1)
            assemble_prepins_PPVS=("${PREPINNED_AGNOSTIC_PACKAGE_VERSIONS[@]}" "${PREPINNED_4_13_1_PACKAGE_VERSIONS[@]}")
            ;;
        *)
            echo "FATAL: Unsupported OCaml version: $OCAML_LANG_VERSION" >&2
            exit 2
            ;;
    esac
    for ppv in "${assemble_prepins_PPVS[@]}"; do
        PPKG="${ppv%%:*}"
        PVER="${ppv##*:}"
        assemble_prepins_PREPINNED_PACKAGES+=("$PPKG")
        assemble_prepins_PREPINNED_VERSIONS+=("$PVER")
    done
    export PACKAGES_PREPINNED="${assemble_prepins_PREPINNED_PACKAGES[*]}"
    export VERSIONS_PREPINNED="${assemble_prepins_PREPINNED_VERSIONS[*]}"
}

PACKAGES=()
PACKAGE_VERSIONS=()

# [find_packages] resets PACKAGES to the packages in the OOREPO repository.
# Ex. (alcotest ansicolor dune)
find_packages() {
    PACKAGES=()
    while IFS='' read -r find_packages_line; do PACKAGES+=("$find_packages_line"); done < <(find "$OOREPO_UNIX/packages" -mindepth 1 -maxdepth 1 -type d | sed 's#.*/##')
}

# [find_package_versions PKG] resets PACKAGE_VERSIONS to the versions of the specified package PKG in the OOREPO repository.
# Ex. (v0.14.0 v0.14.1)
find_package_versions() {
    find_package_versions_PACKAGE="$1"
    shift
    PACKAGE_VERSIONS=()
    while IFS='' read -r find_package_versions_line; do PACKAGE_VERSIONS+=("$find_package_versions_line"); done < <(find "$OOREPO_UNIX/packages/$find_package_versions_PACKAGE" -mindepth 1 -maxdepth 1  -type d | sed "s#.*/##; s#^${find_package_versions_PACKAGE}[.]##")
}

# [list_contains LST ITEM] checks if the item ITEM is in the space separated list LST
list_contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1
}

# [semver VER] converts the version VER into a lexographically sortable string.
# The output format was designed to be easy when parsing.
# The goal is not to be a perfect semver parser; instead the goal is to pick out the highest version number.
# Ex. VER=v0.14.1        -> 0000000000_0000000014_0000000001_v0.14.1
# Ex. VER=20150820       -> 0020150820_0000000000_0000000000_20150820
# Ex. VER=0.9.6-4        -> 0000000000_0000000009_0000000006_0.9.6-4
# Ex. VER=3.0.0-20150830 -> 0000000003_0000000000_0000000000_3.0.0-20150830
# Ex. VER=8.00~alpha05   -> 0000000008_0000000000_0000000000_8.00~alpha05
# Ex. VER=2.02pl1        -> 0000000002_0000000002_0000000000_2.02pl1
# Ex. VER=sk0.23-0.3.1   -> 0000000000_0000000023_0000000000_sk0.23-0.3.1
# Ex. VER=transition     -> 0000000000_0000000000_0000000000_transition (the example is depext. another is seq's "base" version)
# Ex. VER=4.10.2+flambda+mingw32c -> 0000000004_0000000010_0000000002_4.10.2+flambda+mingw32c

semver_TERMS=()
semver() {
    semver_VER="$1"
    shift
    # replace all non-numbers with spaces, then stuff into array.
    # the 0 0 0 makes sure there are at least 3 array terms.
    # the 1st sed expression converts 8.00~alpha05 -> 8.00 (when a number is followed by a non-number/non-dot, then the remainder is thrown away for semver comparison)
    # the 2nd sed expression convert 08 0 05 -> 8 0 5 so the subsequent printf does not interpret it as an octal number
    read -ra semver_TERMS < <(printf "%s" "$semver_VER" | sed 's#\([0-9]\)[^0-9.].*#\1#' | tr -C '0-9' ' ' | sed 's#\b0*\([1-9]\)#\1#g'; echo ' 0 0 0')
    printf "%010d_%010d_%010d_%s\n" "${semver_TERMS[0]}" "${semver_TERMS[1]}" "${semver_TERMS[2]}" "$semver_VER"
}

assert_semver() {
    assert_semver_VER="$1"
    shift
    assert_semver_EXPECTED="$1"
    shift
    assert_semver_ACTUAL=$(semver "$assert_semver_VER")
    if [ "$assert_semver_ACTUAL" = "$assert_semver_EXPECTED" ]; then # we want _literal_ rather than pattern matching, so we do not use [[ ... ]]
        return
    else
        echo "FATAL. The version '$assert_semver_VER' was expected to be: $assert_semver_EXPECTED. Actual: $assert_semver_ACTUAL" >&2
        exit 1
    fi
}

test_semver() {
    assert_semver v0.14.1        0000000000_0000000014_0000000001_v0.14.1
    assert_semver 20150820       0020150820_0000000000_0000000000_20150820
    assert_semver 0.9.6-4        0000000000_0000000009_0000000006_0.9.6-4
    assert_semver 3.0.0-20150830 0000000003_0000000000_0000000000_3.0.0-20150830
    assert_semver 8.00~alpha05   0000000008_0000000000_0000000000_8.00~alpha05
    assert_semver 2.02pl1        0000000002_0000000002_0000000000_2.02pl1
    assert_semver sk0.23-0.3.1   0000000000_0000000023_0000000000_sk0.23-0.3.1
    assert_semver transition     0000000000_0000000000_0000000000_transition
    assert_semver 4.10.2+flambda+mingw32c 0000000004_0000000010_0000000002_4.10.2+flambda+mingw32c
}

trim_package() {
    set -eu # `read -ra` is broken if `set -f`
    read -r -a trim_package_PREPINNED_PACKAGES <<< "$PACKAGES_PREPINNED"
    read -r -a trim_package_PREPINNED_VERSIONS <<< "$VERSIONS_PREPINNED"
    trim_package_PKG="$1"
    if list_contains "$PACKAGES_TO_REMOVE" "$trim_package_PKG"; then
        if [[ "$DRYRUN" = OFF ]]; then
            echo "[$trim_package_PKG] Removing package since on the predefined removal list"
            rm -rf "$OOREPO_UNIX/packages/$trim_package_PKG"
        else
            echo "[$trim_package_PKG] Would have removed package at $OOREPO_UNIX/packages/$trim_package_PKG since on the predefined removal list"
        fi
    else
        if list_contains "$PACKAGES_PREPINNED" "$trim_package_PKG"; then
            # find the version that was pinned
            echo "[$trim_package_PKG] Matches the prepinned list"
            trim_package_CHOSEN_VER=
            for trim_package_PKGIDX in "${!trim_package_PREPINNED_PACKAGES[@]}"; do
                if [ "${trim_package_PREPINNED_PACKAGES[$trim_package_PKGIDX]}" = "$trim_package_PKG" ]; then
                    trim_package_CHOSEN_VER="${trim_package_PREPINNED_VERSIONS[$trim_package_PKGIDX]}"
                fi
            done
        else
            # find the latest version
            find_package_versions "$trim_package_PKG"
            echo "[$trim_package_PKG] Considering versions: ${PACKAGE_VERSIONS[*]}"
            for trim_package_VER in "${PACKAGE_VERSIONS[@]}"; do
                # 1. only respect version directories that have an 'opam' file. Ex. frama-c-base.20160502 does not have one.
                if [[ -e "$OOREPO_UNIX/packages/$trim_package_PKG/$trim_package_PKG.$trim_package_VER/opam" ]]; then
                    # 2. only respect Jane Street packages that start with a 'v' (like v0.14.0), rather than 113.33.03.
                    if grep -q "Jane Street" "$OOREPO_UNIX/packages/$trim_package_PKG/$trim_package_PKG.$trim_package_VER/opam"; then
                        if [[ "$trim_package_VER" = v* ]]; then
                            semver "$trim_package_VER"
                        fi
                    else
                        semver "$trim_package_VER"
                    fi
                fi
            done | sort -r | tee "$WORK"/"$trim_package_PKG"-versions | awk -v P="$trim_package_PKG" '{print "    [" P "] " $0}'
            if [[ -s "$WORK"/"$trim_package_PKG"-versions ]]; then
                trim_package_CHOSEN_VER=$(head -n1 "$WORK"/"$trim_package_PKG"-versions | cut -c34-)
            else
                trim_package_CHOSEN_VER=
            fi
        fi
        if [[ -z "$trim_package_CHOSEN_VER" ]]; then
            if [[ "$DRYRUN" = OFF ]]; then
                echo "[$trim_package_PKG] Removing package since no valid opam-containing versions were found"
                rm -rf "$OOREPO_UNIX/packages/$trim_package_PKG"
            else
                echo "[$trim_package_PKG] Would have removed package at $OOREPO_UNIX/packages/$trim_package_PKG since no valid opam-containing versions were found"
            fi
        else
            if [[ "$DRYRUN" = OFF ]]; then
                echo "    [$trim_package_PKG] Chose version $trim_package_CHOSEN_VER. Removing all others"
                find "$OOREPO_UNIX/packages/$trim_package_PKG" -mindepth 1 -maxdepth 1 ! -name "$trim_package_PKG.$trim_package_CHOSEN_VER" -type d -exec rm -rf {} +
            else
                echo "    [$trim_package_PKG] Would have chosen version $trim_package_CHOSEN_VER and removed all others"
            fi
            echo opam pin add --yes --no-action -k version "$trim_package_PKG" "$trim_package_CHOSEN_VER" > "$WORK"/pin-assembly/"$trim_package_PKG"
        fi
    fi
}

# run test cases
test_semver

# init
assemble_prepins "$OCAML_LANG_VERSION"
find_packages

# exports for `parallel`. note that Bash cannot export arrays
export -f trim_package
export -f list_contains
export -f find_package_versions
export -f semver
export WORK

# do the transformations
# * `parallel` does not work on Cygwin:
#   https://cygwin.cygwin.narkive.com/TNtfRS5K/how-to-get-gnu-parallel-working-with-cygwin
#   so we use xargs instead
if [[ -n "$SINGLEPACKAGE" ]]; then
    trim_package "$SINGLEPACKAGE"
else
    echo "${PACKAGES[@]}" | xargs -n1 | xargs -P 4 -I {} bash -c 'trim_package "$@"' _ {}
fi

# aggregate all of the pin statements
set +f
cat "$WORK"/pin-assembly/* >> "$PINFILE"
set -f

# Install files and directories into $OOREPO_UNIX:
# - /repo
# - /version
# - /pins.txt
if [[ "$DRYRUN" = OFF ]]; then
    install -d "$OOREPO_UNIX"
    install -v "$BASEDIR_IN_FULL_OPAMROOT"/cygwin64/home/opam/opam-repository/repo "$BASEDIR_IN_FULL_OPAMROOT"/cygwin64/home/opam/opam-repository/version "$OOREPO_UNIX"
    install -v "$PINFILE" "$OOREPO_UNIX/pins.txt"
else
    echo "Would have added the following pins at $OOREPO_UNIX/pins.txt :"
    awk '{print "    " $0}' "$PINFILE"
fi
