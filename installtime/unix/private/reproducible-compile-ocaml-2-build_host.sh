#!/bin/sh
#
# This file has parts that are governed by one license and other parts that are governed by a second license (both apply).
# The first license is:
#   Licensed under https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/LICENSE - LGPL 2.1 with special linking exceptions
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
# reproducible-compile-ocaml-2-build.sh -d DKMLDIR -t TARGETDIR -h HOSTABICOMPILER -c TARGETABICOMPILER
#
# Purpose:
# 1. Build an OCaml environment including an OCaml native compiler that generates machine code for the
#    host ABI. Much of that follows
#    https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/shell/bootstrap-ocaml.sh,
#    especially the Windows knobs.
# 2. Optionally layer on top a cross-compiling OCaml environment using techniques pioneered by
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

# ------------------
# BEGIN Command line processing

HOSTCOMPILERARCH=auto
usage() {
    {
        printf "%s\n" "Usage:"
        printf "%s\n" "    reproducible-compile-ocaml-2-build.sh"
        printf "%s\n" "        -h             Display this help message."
        printf "%s\n" "        -d DIR -t DIR  Compile OCaml."
        printf "\n"
        printf "%s\n" "See 'reproducible-compile-ocaml-1-setup.sh -h' for more comprehensive docs."
        printf "\n"
        printf "%s\n" "Options"
        printf "%s\n" "   -d DIR: DKML directory containing a .dkmlroot file"
        printf "%s\n" "   -t DIR: Target directory for the reproducible directory tree"
        printf "%s\n" "   -a TARGETABICOMPILER: Optional. See reproducible-compile-ocaml-1-setup.sh"
        printf "%s\n" "   -b PREF: Required and used only for the MSVC compiler. See reproducible-compile-ocaml-1-setup.sh"
        printf "%s\n" "   -c HOSTCOMPILERARCH: Useful only for the MSVC compiler. Defaults to auto. mingw64, mingw, msvc64, msvc or auto"
        printf "%s\n" "   -e DKMLHOSTABI: Optional. Use the Diskuv OCaml compiler detector find a compiler matching the ABI."
        printf "%s\n" "   -f CONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure"
    } >&2
}

DKMLDIR=
TARGETDIR=
TARGETABICOMPILER=
HOSTCOMPILERARCH=
DKMLHOSTABI=
BOOTSTRAP_EXTRA_OPTS=
export MSVS_PREFERENCE=
while getopts ":d:t:a:b:c:e:fh" opt; do
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
            TARGETABICOMPILER="$OPTARG"
        ;;
        b )
            MSVS_PREFERENCE="$OPTARG"
        ;;
        c )
            HOSTCOMPILERARCH="$OPTARG"
        ;;
        e )
            DKMLHOSTABI="$OPTARG"
        ;;
        f )
            BOOTSTRAP_EXTRA_OPTS="$OPTARG"
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
if [ -x /usr/bin/cygpath ]; then
    OCAMLSRC_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/src/ocaml")
else
    OCAMLSRC_UNIX="$TARGETDIR_UNIX/src/ocaml"
fi

# ------------------
# BEGIN Select Host Compiler

if [ -n "${DKMLHOSTABI:-}" ]; then
  # Detect the compiler matching the host ABI
  _SAVE_DTP="${DKML_TARGET_PLATFORM:-}"
  DKML_TARGET_PLATFORM="$DKMLHOSTABI"
  # Sets OCAML_HOST_TRIPLET that corresponds to DKMLHOSTABI, and creates the specified script
  autodetect_compiler "$WORK"/env-with-host-compiler.sh
  autodetect_compiler --msvs "$WORK"/env-with-host-compiler.msvs
  # shellcheck disable=SC2034
  DKML_TARGET_PLATFORM=$_SAVE_DTP

  # When we run OCaml's ./configure, the DKML compiler must be available
  with_environment_for_ocaml_configure() {
    tail -n -200 "$WORK"/env-with-host-compiler.sh >&2
    dash -x "$WORK"/env-with-host-compiler.sh "$@"
  }
  # Override msvs-detect so that the DKML compiler is used instead, and all msvs-detect options are ignored
  msvs_detect() {
    cat "$WORK"/env-with-host-compiler.msvs
  }
elif is_msys2_msys_build_machine && [ -x /usr/bin/cygpath ]; then
  # We will use MSVS to detect Visual Studio
  with_environment_for_ocaml_configure() {
    env "$@"
  }
  # There is a nasty bug (?) with MSYS2's dash.exe (probably _all_ dash) which will not accept the 'ProgramFiles(x86)' environment,
  # presumably because of the parentheses in it may or may not violate the POSIX standard. Typically that means that dash cannot
  # propagate that variable to a subprocess like bash or another dash.
  # So we use `cygpath -w --folder 42` which gets the value of CSIDL_PROGRAM_FILESX86.
  msvs_detect() {
    msvs_detect_PF86=$(/usr/bin/cygpath -w --folder 42)
    if [ -n "${msvs_detect_PF86}" ]; then
      env 'ProgramFiles(x86)'="$msvs_detect_PF86" "$OCAMLSRC_UNIX"/msvs-detect "$@"
    else
      "$OCAMLSRC_UNIX"/msvs-detect "$@"
    fi
  }
else
  # We will be using the operating system C compiler
  with_environment_for_ocaml_configure() {
    env "$@"
  }
  msvs_detect() {
    "$OCAMLSRC_UNIX"/msvs-detect "$@"
  }
fi

# END Select Host Compiler
# ------------------

# ------------------
# BEGIN Host ABI OCaml
#
# Most of this section comes from
# https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/shell/bootstrap-ocaml.sh
# with portable shell linting (shellcheck) fixes applied.

BOOTSTRAP_OPT_TARGET=${BOOTSTRAP_OPT_TARGET:-opt.opt}
FLEXDLL=flexdll.tar.gz

PREFIX="$TARGETDIR_UNIX"

cd "$OCAMLSRC_UNIX"
PATH_PREPEND=
LIB_PREPEND=
INC_PREPEND=

windows_host_configure_and_make() {
  windows_host_configure_and_make_HOST="$1"
  shift

  case "$(uname -m)" in
    'i686')
      BUILD=i686-pc-cygwin
    ;;
    'x86_64')
      BUILD=x86_64-pc-cygwin
    ;;
  esac

  WINPREFIX=$(printf "%s\n" "${PREFIX}" | cygpath -f - -m)
  with_environment_for_ocaml_configure PATH="${PATH_PREPEND}${PREFIX}/bin:${PATH}" \
  Lib="${LIB_PREPEND}${Lib:-}" \
  Include="${INC_PREPEND}${Include:-}" \
    ./configure --prefix "$WINPREFIX" \
                --build=$BUILD --host="$windows_host_configure_and_make_HOST" \
                --disable-stdlib-manpages \
                $BOOTSTRAP_EXTRA_OPTS
  if [ ! -e flexdll ]; then # OCaml 4.13.x has a git submodule for flexdll
    tar -xzf "${FLEXDLL}"
    rm -rf flexdll
    mv flexdll-* flexdll
  fi
  PATH="${PATH_PREPEND}${PREFIX}/bin:${PATH}" Lib="${LIB_PREPEND}${Lib:-}" Include="${INC_PREPEND}${Include:-}" make -j flexdll
  PATH="${PATH_PREPEND}${PREFIX}/bin:${PATH}" Lib="${LIB_PREPEND}${Lib:-}" Include="${INC_PREPEND}${Include:-}" make -j world
  PATH="${PATH_PREPEND}${PREFIX}/bin:${PATH}" Lib="${LIB_PREPEND}${Lib:-}" Include="${INC_PREPEND}${Include:-}" make -j "$BOOTSTRAP_OPT_TARGET"
  PATH="${PATH_PREPEND}${PREFIX}/bin:${PATH}" Lib="${LIB_PREPEND}${Lib:-}" Include="${INC_PREPEND}${Include:-}" make install
}

if [ -n "${DKMLHOSTABI:-}" ] && [ -n "${COMSPEC}" ] && [ -x "${COMSPEC}" ] ; then
  # msvs_detect() has been setup with full DKMLHOSTABI specs already
  msvs_detect > "$WORK"/msvs.source
  # shellcheck disable=SC1091
  . "$WORK"/msvs.source
  if [ -z "${MSVS_NAME}" ] ; then
    printf "%s\n" "No appropriate C compiler was found -- unable to build OCaml"
    exit 1
  else
    PATH_PREPEND="${MSVS_PATH}"
    LIB_PREPEND="${MSVS_LIB};"
    INC_PREPEND="${MSVS_INC};"
  fi

  # do ./configure and make using host triplet assigned in Select Host Compiler step
  windows_host_configure_and_make "$OCAML_HOST_TRIPLET"
elif [ -n "$HOSTCOMPILERARCH" ] && [ -n "${COMSPEC}" ] && [ -x "${COMSPEC}" ] ; then
  case "$HOSTCOMPILERARCH" in
    "mingw")
      HOST=i686-w64-mingw32
    ;;
    "mingw64")
      HOST=x86_64-w64-mingw32
    ;;
    "msvc")
      HOST=i686-pc-windows
      if ! command -v ml > /dev/null ; then
        msvs_detect --arch=x86 > "$WORK"/msvs.source
        # shellcheck disable=SC1091
        . "$WORK"/msvs.source
        if [ -n "${MSVS_NAME}" ] ; then
          PATH_PREPEND="${MSVS_PATH}"
          LIB_PREPEND="${MSVS_LIB};"
          INC_PREPEND="${MSVS_INC};"
        fi
      fi
    ;;
    "msvc64")
      HOST=x86_64-pc-windows
      if ! command -v ml64 > /dev/null ; then
        msvs_detect --arch=x64 > "$WORK"/msvs.source
        # shellcheck disable=SC1091
        . "$WORK"/msvs.source
        if [ -n "${MSVS_NAME}" ] ; then
          PATH_PREPEND="${MSVS_PATH}"
          LIB_PREPEND="${MSVS_LIB};"
          INC_PREPEND="${MSVS_INC};"
        fi
      fi
    ;;
    *)
      if [ "$HOSTCOMPILERARCH" != "auto" ] ; then
        printf "%s\n" "Compiler architecture $HOSTCOMPILERARCH not recognised -- mingw64, mingw, msvc64, msvc (or auto)"
      fi
      if [ -n "${PROCESSOR_ARCHITEW6432:-}" ] || [ "${PROCESSOR_ARCHITECTURE:-}" = "AMD64" ] ; then
        TRY64=1
      else
        TRY64=0
      fi

      if [ ${TRY64} -eq 1 ] && command -v x86_64-w64-mingw32-gcc > /dev/null ; then
        HOST=x86_64-w64-mingw32
      elif command -v i686-w64-mingw32-gcc > /dev/null ; then
        HOST=i686-w64-mingw32
      elif [ ${TRY64} -eq 1 ] && command -v ml64 > /dev/null ; then
        HOST=x86_64-pc-windows
        PATH_PREPEND=$(bash "$DKMLDIR"/installtime/unix/private/reproducible-compile-ocaml-check_linker.sh)
      elif command -v ml > /dev/null ; then
        HOST=i686-pc-windows
        PATH_PREPEND=$(bash "$DKMLDIR"/installtime/unix/private/reproducible-compile-ocaml-check_linker.sh)
      else
        if [ ${TRY64} -eq 1 ] ; then
          HOST=x86_64-pc-windows
          HOST_ARCH=x64
        else
          HOST=i686-pc-windows
          HOST_ARCH=x86
        fi
        msvs_detect --arch=${HOST_ARCH} > "$WORK"/msvs.source
        # shellcheck disable=SC1091
        . "$WORK"/msvs.source
        if [ -z "${MSVS_NAME}" ] ; then
          printf "%s\n" "No appropriate C compiler was found -- unable to build OCaml"
          exit 1
        else
          PATH_PREPEND="${MSVS_PATH}"
          LIB_PREPEND="${MSVS_LIB};"
          INC_PREPEND="${MSVS_INC};"
        fi
      fi
    ;;
  esac
  if [ -n "${PATH_PREPEND}" ] ; then
    PATH_PREPEND="${PATH_PREPEND}:"
  fi
  # do ./configure and make
  windows_host_configure_and_make $HOST
else
  with_environment_for_ocaml_configure ./configure --prefix "${PREFIX}" $BOOTSTRAP_EXTRA_OPTS --disable-stdlib-manpages
  ${MAKE:-make} world
  ${MAKE:-make} "$BOOTSTRAP_OPT_TARGET"
  ${MAKE:-make} install
fi
