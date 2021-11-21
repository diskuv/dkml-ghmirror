#!/bin/sh
#
# This file has parts that are governed by one license and other parts that are governed by a second license (both apply).
# The first license is:
#   Licensed under https://github.com/EduardoRFS/reason-mobile/blob/7ba258319b87943d2eb0d8fb84562d0afeb2d41f/LICENSE#L1 - MIT License
# The second license (Apache License, Version 2.0) is below.
#
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
# reproducible-compile-ocaml-3-build_cross.sh -d DKMLDIR -t TARGETDIR
#
# Purpose:
# 1. Optional layer on top of a host OCaml environment a cross-compiling OCaml environment using techniques pioneered by
#    @EduardoRFS:
#    a) the OCaml native libraries use the target ABI
#    b) the OCaml native compiler generates the target ABI
#    c) the OCaml compiler-library package uses the target ABI and generate the target ABI
#    d) the remainder (especially the OCaml toplevel) use the host ABI
#    See https://github.com/anmonteiro/nix-overlays/blob/79d36ea351edbaf6ee146d9bf46b09ee24ed6ece/cross/ocaml.nix for
#    reference material and an alternate way of doing it on nix.
#
# -------------------------------------------------------
set -euf

# Location of this script
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "$SCRIPTDIR" && pwd)
SCRIPTFILE="$SCRIPTDIR"/$(basename "$0")

# ------------------
# BEGIN Command line processing

OPT_WIN32_ARCH=auto
usage() {
    {
        printf "%s\n" "Usage:"
        printf "%s\n" "    reproducible-compile-ocaml-3-build_cross.sh"
        printf "%s\n" "        -h             Display this help message."
        printf "%s\n" "        -d DIR -t DIR  Compile OCaml."
        printf "\n"
        printf "%s\n" "See 'reproducible-compile-ocaml-1-setup.sh -h' for more comprehensive docs."
        printf "\n"
        printf "%s\n" "If not '-a TARGETABIS' is specified, this script does nothing"
        printf "\n"
        printf "%s\n" "Options"
        printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file"
        printf "%s\n" "   -t DIR: Target directory for the reproducible directory tree"
        printf "%s\n" "   -a TARGETABIS: Optional. See reproducible-compile-ocaml-1-setup.sh"
        printf "%s\n" "   -c ARCH: Useful only for Windows. Defaults to auto. mingw64, mingw, msvc64, msvc or auto"
        printf "%s\n" "   -g CONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure"
    } >&2
}

DKMLDIR=
TARGETDIR=
TARGETABIS=
OPT_WIN32_ARCH=auto
CONFIGUREARGS=
while getopts ":d:t:a:c:g:h" opt; do
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
        t )
            TARGETDIR="$OPTARG"
        ;;
        a )
            TARGETABIS="$OPTARG"
        ;;
        c )
            OPT_WIN32_ARCH="$OPTARG"
        ;;
        g )
            CONFIGUREARGS="$OPTARG"
        ;;
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
TARGETDIR_UNIX=$(cd "$TARGETDIR" && pwd) # better than cygpath: handles TARGETDIR=. without trailing slash, and works on Unix/Windows

# Quick exit
if [ -z "$TARGETABIS" ]; then
  exit 0
fi

# ------------------
# BEGIN Target ABI OCaml
#
# Most of this section was adapted from
# https://github.com/EduardoRFS/reason-mobile/blob/7ba258319b87943d2eb0d8fb84562d0afeb2d41f/patches/ocaml/files/make.cross.sh
# and https://github.com/anmonteiro/nix-overlays/blob/79d36ea351edbaf6ee146d9bf46b09ee24ed6ece/cross/ocaml.nix
# after discussion from authors at https://discuss.ocaml.org/t/cross-compiling-implementations-how-they-work/8686 .
# Portable shell linting (shellcheck) fixes applied.

# Prereqs for reproducible-compile-ocaml-functions.sh
autodetect_system_binaries
autodetect_system_path

# shellcheck disable=SC1091
. "$DKMLDIR/installtime/unix/private/reproducible-compile-ocaml-functions.sh"

# Set NUMCPUS
autodetect_cpus

# Set DKML_POSIX_SHELL
autodetect_posix_shell

## Parameters
OCAML_HOST=$TARGETDIR_UNIX

# Determine ext_exe from compiler (although the filename extensions on the host should be the same as well)
if [ -e "$OCAML_HOST/bin/ocamlc.exe" ]; then
  # shellcheck disable=SC2016
  EXE_EXT=$("$OCAML_HOST"/bin/ocamlc.exe -config | $DKMLSYS_AWK '$1=="ext_exe:"{print $2}')
else
  # shellcheck disable=SC2016
  EXE_EXT=$("$OCAML_HOST"/bin/ocamlc -config | $DKMLSYS_AWK '$1=="ext_exe:"{print $2}')
fi

OCAMLRUN="$OCAML_HOST/bin/ocamlrun$EXE_EXT"
OCAMLLEX="$OCAML_HOST/bin/ocamllex$EXE_EXT"
OCAMLYACC="$OCAML_HOST/bin/ocamlyacc$EXE_EXT"
OCAMLDOC="$OCAML_HOST/bin/ocamldoc$EXE_EXT"
CAMLDEP="$OCAML_HOST/bin/ocamlc$EXE_EXT -depend"

genWrapper() {
  genWrapper_NAME="$1"
  genWrapper_CAMLBIN="$2"

  genWrapper_DIRNAME=$(dirname "$genWrapper_NAME")
  install -d "$genWrapper_DIRNAME"

  $DKMLSYS_CAT > "$genWrapper_NAME".tmp <<EOF
#!$DKML_POSIX_SHELL

NEW_ARGS=""
for ARG in "\$@"; do NEW_ARGS="\$NEW_ARGS \"\$ARG\""; done
eval "$genWrapper_CAMLBIN \$NEW_ARGS"
EOF

  $DKMLSYS_CHMOD +x "$genWrapper_NAME".tmp
  $DKMLSYS_MV "$genWrapper_NAME".tmp "$genWrapper_NAME"
}

make_caml () {
  ocaml_make -j"$NUMCPUS" -l"$NUMCPUS" \
    CAMLDEP="$CAMLDEP -depend" \
    CAMLLEX="$OCAMLLEX" OCAMLLEX="$OCAMLLEX" \
    CAMLYACC="$OCAMLYACC" OCAMLYACC="$OCAMLYACC" \
    CAMLRUN="$OCAMLRUN" OCAMLRUN="$OCAMLRUN" \
    CAMLC="$CAMLC" OCAMLC="$CAMLC" \
    CAMLOPT="$CAMLOPT" OCAMLOPT="$CAMLOPT" \
    OCAMLDOC_RUN="$OCAMLDOC" \
    "$@"
}

HOST_MAKEFILE_CONFIG="$OCAML_HOST/lib/ocaml/Makefile.config"
get_host_variable () {
  # shellcheck disable=SC2016
  grep "$1=" "$HOST_MAKEFILE_CONFIG" | $DKMLSYS_AWK -F '=' '{print $2}'
}

NATDYNLINK=$(get_host_variable "NATDYNLINK")
NATDYNLINKOPTS=$(get_host_variable "NATDYNLINKOPTS")

make_host () {
  make_host_BUILD_ROOT=$1
  shift
  CAMLC="$make_host_BUILD_ROOT/bin/ocamlcHost.wrapper"
  CAMLOPT="$make_host_BUILD_ROOT/bin/ocamloptHost.wrapper"

  make_caml \
    NATDYNLINK="$NATDYNLINK" \
    NATDYNLINKOPTS="$NATDYNLINKOPTS" \
    "$@"
}

make_target () {
  make_target_BUILD_ROOT=$1
  shift
  CAMLC="$make_target_BUILD_ROOT/bin/ocamlcTarget.wrapper"
  CAMLOPT="$make_target_BUILD_ROOT/bin/ocamloptTarget.wrapper"

  make_caml BUILD_ROOT="$make_target_BUILD_ROOT" "$@"
}

checksum_crosscompile_inputs() {
  checksum_host_OUT="$1"
  shift
  {
    # this script
    sha256compute "$SCRIPTFILE"

    # only do bytecode since native code is indeterministic (randomization during optimization;
    # address space layout randomization; etc.)
    find "$OCAML_HOST"/bin -name 'ocaml*.byte'"$EXE_EXT" | while IFS= read -r checksum_host_LINE; do
      sha256compute "$checksum_host_LINE"
    done | LC_ALL=C sort # we sort since bin/ocaml* may come in any order
  } > "$checksum_host_OUT"
}

build_world() {
  build_world_BUILD_ROOT=$1
  shift
  build_world_PREFIX=$1
  shift
  build_world_CHKSUM=$1
  shift
  build_world_TARGET_ABI=$1
  shift
  build_world_PRECONFIGURE=$1
  shift

  # Idempotent shortcut: If a checksum of the inputs for cross-compiling (host binaries, this script) have
  # not changed, then no need to do a full clean + build
  if [ -e "$build_world_CHKSUM" ]; then
    checksum_crosscompile_inputs "$WORK/build_world.chksum.txt"
    if cmp -s "$build_world_CHKSUM" "$WORK/build_world.chksum.txt"; then
      echo "INFO: No changes detected in the host binaries and the cross-compiling scripts, so not recompiling. Force a recompile by erasing $build_world_CHKSUM"
      return
    fi
  fi

  # Wrappers
  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamlcHost.wrapper" "$OCAML_HOST/bin/ocamlc.opt$EXE_EXT -I $OCAML_HOST/lib/ocaml -I $OCAML_HOST/lib/ocaml/stublibs -nostdlib "
  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamloptHost.wrapper" "$OCAML_HOST/bin/ocamlopt.opt$EXE_EXT -I $OCAML_HOST/lib/ocaml -nostdlib "

  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamlcTarget.wrapper" "$build_world_BUILD_ROOT/ocamlc.opt$EXE_EXT -I $build_world_BUILD_ROOT/stdlib -I $build_world_BUILD_ROOT/otherlibs/unix -I $OCAML_HOST/lib/ocaml/stublibs -nostdlib "
  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamloptTarget.wrapper" "$build_world_BUILD_ROOT/ocamlopt.opt$EXE_EXT -I $build_world_BUILD_ROOT/stdlib -I $build_world_BUILD_ROOT/otherlibs/unix -nostdlib "

  # clean (otherwise you will 'make inconsistent assumptions' errors with a mix of host + target binaries)
  make clean

  # ./configure
  ocaml_configure "$build_world_PREFIX" "$OPT_WIN32_ARCH" "$build_world_TARGET_ABI" "$build_world_PRECONFIGURE" "$CONFIGUREARGS --disable-ocamldoc"

  # Build
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_host "$build_world_BUILD_ROOT" flexdll
  fi
  log_trace make_host "$build_world_BUILD_ROOT" runtime coreall
  log_trace make_host "$build_world_BUILD_ROOT" opt-core
  log_trace make_host "$build_world_BUILD_ROOT" ocamlc.opt
  log_trace make_host "$build_world_BUILD_ROOT" ocamlopt.opt
  log_trace make_host "$build_world_BUILD_ROOT" compilerlibs/ocamltoplevel.cma otherlibraries \
            ocamldebugger
  log_trace make_host "$build_world_BUILD_ROOT" ocamllex.opt ocamltoolsopt \
            ocamltoolsopt.opt
  log_trace find . -name '*.cm?' -exec rm {} +
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_target "$build_world_BUILD_ROOT" flexdll
  fi
  log_trace make_target "$build_world_BUILD_ROOT" -C stdlib all allopt
  log_trace make_target "$build_world_BUILD_ROOT" ocaml ocamlc
  log_trace make_target "$build_world_BUILD_ROOT" ocamlopt otherlibraries \
              otherlibrariesopt ocamltoolsopt \
              driver/main.cmx driver/optmain.cmx \
              compilerlibs/ocamlcommon.cmxa \
              compilerlibs/ocamlbytecomp.cmxa \
              compilerlibs/ocamloptcomp.cmxa
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_target "$build_world_BUILD_ROOT" flexlink.opt
  fi

  ## Install
  log_trace cp "$OCAMLRUN" runtime/ocamlrun
  log_trace make_host "$build_world_BUILD_ROOT" install
  log_trace make_host "$build_world_BUILD_ROOT" -C debugger install

  # Produce checksum
  checksum_crosscompile_inputs "$build_world_CHKSUM"
}


# Loop over each target abi script file; each file separated by semicolons, and each term with an equals
printf "%s\n" "$TARGETABIS" | sed 's/;/\n/g' | sed 's/^\s*//; s/\s*$//' > "$WORK"/tabi
while IFS= read -r _abientry
do
  _targetabi=$(printf "%s" "$_abientry" | sed 's/=.*//')
  _abiscript=$(printf "%s" "$_abientry" | sed 's/^[^=]*=//')

  _CROSS_TARGETDIR=$TARGETDIR_UNIX/opt/mlcross/$_targetabi
  _CROSS_SRCDIR=$_CROSS_TARGETDIR/src/ocaml
  _CROSS_CHKSUM=$TARGETDIR_UNIX/opt/mlcross/$_targetabi.chksum.txt
  cd "$_CROSS_SRCDIR"
  build_world "$_CROSS_SRCDIR" "$_CROSS_TARGETDIR" "$_CROSS_CHKSUM" "$_targetabi" "$_abiscript"
done < "$WORK"/tabi
