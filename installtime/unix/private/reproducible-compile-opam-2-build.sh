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
# reproducible-compile-windows-opam-2-build.sh -d DKMLDIR -t TARGETDIR
#
# Sets up the source code for a reproducible build

set -euf

# ------------------
# BEGIN Command line processing

OPT_MSVS_PREFERENCE='VS16.*;VS15.*;VS14.0' # KEEP IN SYNC with 1-setup.sh

usage() {
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    reproducible-compile-opam-2-build.sh" >&2
    printf "%s\n" "        -h                       Display this help message." >&2
    printf "%s\n" "        -d DIR -t DIR [-n NUM]   Do compilation of Opam." >&2
    printf "%s\n" "Options" >&2
    printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file" >&2
    printf "%s\n" "   -t DIR: Target directory" >&2
    printf "%s\n" "   -n NUM: Number of CPUs. Autodetected with max of 8." >&2
    printf "%s\n" "   -a PLATFORM: Target platform for bootstrapping an OCaml compiler." >&2
    printf "%s\n" "      Defaults to 'dev'. Ex. dev, windows_x86, windows_x86_64" >&2
    printf "%s\n" "   -b PREF: The msvs-tools MSVS_PREFERENCE setting, needed only for Windows." >&2
    printf "%s\n" "      Defaults to '$OPT_MSVS_PREFERENCE' which, because it does not include '@'," >&2
    printf "%s\n" "      will not choose a compiler based on environment variables." >&2
    printf "%s\n" "      Confer with https://github.com/metastack/msvs-tools#msvs-detect" >&2
    printf "%s\n" "   -c OCAMLHOME: Optional. The home directory for OCaml containing bin/ocamlc and other OCaml binaries" >&2
    printf "%s\n" "      and libraries. If not specified will bootstrap its own OCaml home" >&2
    printf "%s\n" "   -e ON|OFF: Optional; default is OFF. If ON will preserve .git folders in the target directory" >&2
}

DKMLDIR=
TARGETDIR=
OCAMLHOME=
NUMCPUS=
PRESERVEGIT=OFF
export PLATFORM=dev
while getopts ":d:t:n:a:b:c:e:h" opt; do
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
        t ) TARGETDIR="$OPTARG";;
        n ) NUMCPUS="$OPTARG";;
        a ) PLATFORM="$OPTARG";;
        b ) OPT_MSVS_PREFERENCE="$OPTARG";;
        c ) OCAMLHOME="$OPTARG";;
        e ) PRESERVEGIT="$OPTARG";;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$DKMLDIR" ] || [ -z "$TARGETDIR" ]; then
    printf "%s\n" "Missing required options" >&2
    usage
    exit 1
fi

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
OPAMSRC_UNIX=$TARGETDIR_UNIX/src/opam
if [ -x /usr/bin/cygpath ]; then
    TARGETDIR_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX")
else
    TARGETDIR_MIXED="$TARGETDIR_UNIX"
fi

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the DKMLDIR (just like the container
# sets the directory to be /work)
cd "$DKMLDIR"

# Start PATH from scratch. This is supposed to be reproducible. Also
# we don't want a prior DiskuvOCamlHome installation to be used (ex.
# if `flexlink` is in the PATH then `make compiler / ./shell/bootstrap-ocaml.sh` will fail
# because it won't include the boostrap/ocaml-x.y.z/flexdll/ headers).
if [ -x /usr/bin/cygpath ]; then
    # include /c/Windows/System32 at end which is necessary for (at minimum) OCaml's shell/msvs-detect
    PATH=/usr/bin:/bin:$(/usr/bin/cygpath -S)
else
    PATH=/usr/bin:/bin
fi
if [ -n "$OCAMLHOME" ]; then
    if [ -x /usr/bin/cygpath ]; then
        OCAMLHOME_UNIX=$(/usr/bin/cygpath -au "$OCAMLHOME")
    else
        OCAMLHOME_UNIX="$OCAMLHOME"
    fi
    POST_BOOTSTRAP_PATH="$OCAMLHOME_UNIX"/bin:"$PATH"
else
    POST_BOOTSTRAP_PATH="$OPAMSRC_UNIX"/bootstrap/ocaml/bin:"$PATH"
fi

# Set NUMCPUS if unset from autodetection of CPUs
autodetect_cpus

# Autodetect compiler like Visual Studio on Windows.
autodetect_compiler "$WORK"/launch-compiler.sh
if [ -n "$OCAML_HOST_TRIPLET" ]; then
    BOOTSTRAP_EXTRA_OPTS="--host=$OCAML_HOST_TRIPLET"
else
    BOOTSTRAP_EXTRA_OPTS=""
fi

if is_unixy_windows_build_machine; then
    printf "%s" "cl.exe, if detected: "
    "$WORK"/launch-compiler.sh which cl.exe
    "$WORK"/launch-compiler.sh printf "%s\n" "INCLUDE: ${INCLUDE:-}"
    "$WORK"/launch-compiler.sh printf "%s\n" "LIBS: ${LIBS:-}"
fi

# Running through the `make compiler`, `make lib-pkg` + `configure` process should be done
# as one atomic unit. A failure in an intermediate step can cause subsequent `make compiler`
# or `make lib-pkg` or `configure` to fail. So we completely clean (`distclean`) until
# we have successfully completed a single run all the way to `configure`.
if [ ! -e "$OPAMSRC_UNIX/src/ocaml-flags-configure.sexp" ]; then
    # Clear out all intermediate build files
    log_trace installtime/unix/private/reproducible-compile-opam-9-trim.sh -d . -t "$TARGETDIR_UNIX" -e "$PRESERVEGIT"

    # If no OCaml home, let Opam create its own Ocaml compiler which Opam will use to compile
    # all of its required Ocaml dependencies
    if [ -z "$OCAMLHOME" ]; then
        # No OCaml home. Do Opam bootstrap
        # --------------------------------

        # Make sure at least flexdll is available for the upcoming 'make compiler'
        log_trace make -C "$OPAMSRC_UNIX"/src_ext cache-archives

        # We do what the following does (with customization): `make -C "$OPAMSRC_UNIX" compiler -j "$NUMCPUS"`
        pushd "$OPAMSRC_UNIX"
        if ! log_trace "$WORK"/launch-compiler.sh \
            BOOTSTRAP_EXTRA_OPTS="$BOOTSTRAP_EXTRA_OPTS" BOOTSTRAP_OPT_TARGET=opt.opt BOOTSTRAP_ROOT=.. BOOTSTRAP_DIR=bootstrap \
            ./shell/bootstrap-ocaml.sh auto;
        then
            # dump the `configure` script and display it with a ==> marker and line numbers (config.log reports the offending line numbers)
            marker="=-=-=-=-=-=-=-= configure script that errored =-=-=-=-=-=-=-="
            find bootstrap -maxdepth 2 -name configure | while read -r b; do
                printf "%s\n" "$marker" >&2
                awk '{print NR,$0}' "$b" >&2
            done
            # dump the config.log and display it with a ==> marker
            printf "\n" >&2
            find bootstrap -maxdepth 2 -name config.log -exec tail -n+0 {} \; >&2
            # tell how to get real error
            printf "%s\n" "FATAL: Failed ./shell/bootstrap-ocaml.sh. Original error should be above the numbered script that starts with: $marker"
            exit 1
        fi
        popd

        # Install Opam's dependencies as findlib packages to the bootstrap compiler
        # Note: We could add `OPAM_0INSTALL_SOLVER_ENABLED=true` but unclear if that is a good idea.
        log_trace "$WORK"/launch-compiler.sh make -C "$OPAMSRC_UNIX" lib-pkg -j "$NUMCPUS"
    fi

    # Standard autotools ./configure
    # - MSVS_PREFERENCE is used by OCaml's shell/msvs-detect, and is not used for non-Windows systems.
    pushd "$OPAMSRC_UNIX"
    log_trace env PATH="$POST_BOOTSTRAP_PATH" MSVS_PREFERENCE="$OPT_MSVS_PREFERENCE" ./configure --prefix="$TARGETDIR_MIXED"
    popd
fi

if [ -n "$OCAMLHOME" ]; then
    # OCaml home. Install Opam dependencies needed to create `opam.exe`
    log_trace env PATH="$POST_BOOTSTRAP_PATH" make -C "$OPAMSRC_UNIX" lib-ext # OCAML="$OCAMLHOME/bin/ocaml"
fi

# At this point we have compiled _all_ of Opam dependencies ...
# Now we need to build Opam itself.

log_trace env PATH="$POST_BOOTSTRAP_PATH" make -C "$OPAMSRC_UNIX" # parallelism does not work here
log_trace env PATH="$POST_BOOTSTRAP_PATH" make -C "$OPAMSRC_UNIX" install
