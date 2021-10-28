#!/bin/sh
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
# reproducible-compile-ocaml-functions.sh
#
# Purpose:
# 1. Provide common functions to be sourced in the reproducible step scripts.
#
# Prereqs:
# * autodetect_system_binaries() of crossplatform-functions.sh has already been invoked
# * autodetect_system_path()  of crossplatform-functions.sh has already been invoked
# -------------------------------------------------------

# Most of this section was adapted from
# https://github.com/ocaml/opam/blob/012103bc52bfd4543f3d6f59edde91ac70acebc8/shell/bootstrap-ocaml.sh
# with portable shell linting (shellcheck) fixes applied.

# We do not want any system OCaml to leak into the configuration of the new OCaml we are compiling.
# All OCaml influencing variables should be nullified here except PATH where we will use
# autodetect_system_path() of crossplatform-functions.sh.
ocaml_configure_no_ocaml_leak_environment="OCAML_TOPLEVEL_PATH= OCAMLLIB="

windows_configure_and_define_make() {
  windows_configure_and_define_make_HOST="$1"
  shift
  windows_configure_and_define_make_PREFIX="$1"
  shift
  windows_configure_and_define_make_PATH_PREPEND="$1"
  shift
  windows_configure_and_define_make_LIB_PREPEND="$1"
  shift
  windows_configure_and_define_make_INC_PREPEND="$1"
  shift
  windows_configure_and_define_make_EXTRA_OPTS="$1"
  shift

  case "$(uname -m)" in
    'i686')
      windows_configure_and_define_make_BUILD=i686-pc-cygwin
    ;;
    'x86_64')
      windows_configure_and_define_make_BUILD=x86_64-pc-cygwin
    ;;
  esac

  # 4.13+ have --with-flexdll ./configure option. Autoselect it.
  windows_configure_and_define_make_OCAMLVER=$(awk 'NR==1{print}' VERSION)
  windows_configure_and_define_make_MAKEFLEXDLL=OFF
  case "$windows_configure_and_define_make_OCAMLVER" in
    4.00.*|4.01.*|4.02.*|4.03.*|4.04.*|4.05.*|4.06.*|4.07.*|4.08.*|4.09.*|4.10.*|4.11.*|4.12.*)
      windows_configure_and_define_make_MAKEFLEXDLL=ON
      ;;
    *)
      windows_configure_and_define_make_EXTRA_OPTS="$windows_configure_and_define_make_EXTRA_OPTS --with-flexdll"
      ;;
  esac

  windows_configure_and_define_make_WINPREFIX=$(printf "%s\n" "${windows_configure_and_define_make_PREFIX}" | /usr/bin/cygpath -f - -m)
  # With MSYS2 it is quite possible to have INCLUDE and Include in the same environment. Opam seems to use camel case, which
  # is probably fine in Cygwin.
  # shellcheck disable=SC2086
  with_environment_for_ocaml_configure --unset=LIB --unset=INCLUDE --unset=PATH --unset=Lib --unset=Include --unset=Path \
    PATH="${windows_configure_and_define_make_PATH_PREPEND}${windows_configure_and_define_make_PREFIX}/bin:$DKML_SYSTEM_PATH" \
    LIB="${windows_configure_and_define_make_LIB_PREPEND}${LIB:-}" \
    INCLUDE="${windows_configure_and_define_make_INC_PREPEND}${INCLUDE:-}" \
    $ocaml_configure_no_ocaml_leak_environment \
    ./configure --prefix "$windows_configure_and_define_make_WINPREFIX" \
                --build=$windows_configure_and_define_make_BUILD --host="$windows_configure_and_define_make_HOST" \
                --disable-stdlib-manpages \
                $windows_configure_and_define_make_EXTRA_OPTS
  if [ ! -e flexdll ]; then # OCaml 4.13.x has a git submodule for flexdll
    tar -xzf flexdll.tar.gz
    rm -rf flexdll
    mv flexdll-* flexdll
  fi

  # Define make functions
  if [ "$windows_configure_and_define_make_MAKEFLEXDLL" = ON ]; then
    OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL=ON
  else
    # shellcheck disable=SC2034
    OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL=OFF
  fi
  ocaml_make() {
    # With MSYS2 it is quite possible to have INCLUDE and Include in the same environment. Opam seems to use camel case, which
    # is probably fine in Cygwin.
    log_trace env --unset=LIB --unset=INCLUDE --unset=PATH --unset=Lib --unset=Include --unset=Path \
      PATH="${windows_configure_and_define_make_PATH_PREPEND}${windows_configure_and_define_make_PREFIX}/bin:$DKML_SYSTEM_PATH" \
      LIB="${windows_configure_and_define_make_LIB_PREPEND}${LIB:-}" \
      INCLUDE="${windows_configure_and_define_make_INC_PREPEND}${INCLUDE:-}" \
      "${MAKE:-make}" "$@"
  }
}

ocaml_configure() {
  ocaml_configure_PREFIX="$1"
  shift
  ocaml_configure_ARCH="$1"
  shift
  ocaml_configure_ABI="$1"
  shift
  ocaml_configure_PRECONFIGURE="$1"
  shift
  ocaml_configure_EXTRA_OPTS="$1"
  shift

  make_preconfigured_env_script() {
    make_preconfigured_env_script_SRC=$1
    shift
    make_preconfigured_env_script_DEST=$1
    shift
    {
      if [ -n "$ocaml_configure_PRECONFIGURE" ]; then
        printf "DKMLDIR='%s'\n" "$DKMLDIR"
        printf "DKML_TARGET_ABI='%s'\n" "$ocaml_configure_ABI"
        printf ". '%s'\n" "$ocaml_configure_PRECONFIGURE"
      fi
      $DKMLSYS_CAT "$make_preconfigured_env_script_SRC"
    } > "$make_preconfigured_env_script_DEST".tmp
    $DKMLSYS_CHMOD +x "$make_preconfigured_env_script_DEST".tmp
    $DKMLSYS_MV "$make_preconfigured_env_script_DEST".tmp "$make_preconfigured_env_script_DEST"
  }

  # Compiler
  # --------

  printf "%s\n" "exec env \$@" > "$WORK"/basic-env.sh
  make_preconfigured_env_script "$WORK"/basic-env.sh "$WORK"/preconfigured-env.sh

  if [ -x /usr/bin/cygpath ]; then
    # We will use MSVS to detect Visual Studio
    with_environment_for_ocaml_configure() {
      log_trace "$WORK"/preconfigured-env.sh "$@"
    }
    # There is a nasty bug (?) with MSYS2's dash.exe (probably _all_ dash) which will not accept the 'ProgramFiles(x86)' environment,
    # presumably because of the parentheses in it may or may not violate the POSIX standard. Typically that means that dash cannot
    # propagate that variable to a subprocess like bash or another dash.
    # So we use `cygpath -w --folder 42` which gets the value of CSIDL_PROGRAM_FILESX86.
    msvs_detect() {
      msvs_detect_PF86=$(/usr/bin/cygpath -w --folder 42)
      if [ -n "${msvs_detect_PF86}" ]; then
        log_trace env 'ProgramFiles(x86)'="$msvs_detect_PF86" ./msvs-detect "$@"
      else
        log_trace ./msvs-detect "$@"
      fi
    }
  else
    # We will be using the operating system C compiler
    with_environment_for_ocaml_configure() {
      log_trace "$WORK"/preconfigured-env.sh "$@"
    }
    msvs_detect() {
      log_trace ./msvs-detect "$@"
    }
  fi

  # ./configure and define make functions
  # -------------------------------------

  if [ -n "$ocaml_configure_ABI" ] && [ -n "${COMSPEC:-}" ] && [ -x "${COMSPEC:-}" ] ; then
    # Detect the compiler matching the host ABI
    ocaml_configure_SAVE_DTP="${DKML_TARGET_PLATFORM:-}"
    DKML_TARGET_PLATFORM="$ocaml_configure_ABI"
    # Sets OCAML_HOST_TRIPLET that corresponds to ocaml_configure_ABI, and creates the specified script
    autodetect_compiler "$WORK"/env-with-compiler.sh
    autodetect_compiler --msvs "$WORK"/env-with-compiler.msvs
    # shellcheck disable=SC2034
    DKML_TARGET_PLATFORM=$ocaml_configure_SAVE_DTP

    # When we run OCaml's ./configure, the DKML compiler must be available
    make_preconfigured_env_script "$WORK"/env-with-compiler.sh "$WORK"/preconfigured-env-with-compiler.sh
    with_environment_for_ocaml_configure() {
      log_trace "$WORK"/preconfigured-env-with-compiler.sh "$@"
    }

    # Get MSVS_* aligned to the DKML compiler
    # shellcheck disable=SC1091
    . "$WORK"/env-with-compiler.msvs
    if [ -z "${MSVS_NAME}" ] ; then
      printf "%s\n" "No appropriate C compiler was found -- unable to build OCaml"
      exit 1
    fi

    # do ./configure and define make using host triplet defined in compiler autodetection
    windows_configure_and_define_make "$OCAML_HOST_TRIPLET" "$ocaml_configure_PREFIX" \
      "$MSVS_PATH" "$MSVS_LIB;" "$MSVS_INC;" \
      "$ocaml_configure_EXTRA_OPTS"
  elif [ -n "$ocaml_configure_ARCH" ] && [ -n "${COMSPEC:-}" ] && [ -x "${COMSPEC:-}" ] ; then
    ocaml_configure_PATH_PREPEND=
    ocaml_configure_LIB_PREPEND=
    ocaml_configure_INC_PREPEND=

    case "$ocaml_configure_ARCH" in
      "mingw")
        ocaml_configure_HOST=i686-w64-mingw32
      ;;
      "mingw64")
        ocaml_configure_HOST=x86_64-w64-mingw32
      ;;
      "msvc")
        ocaml_configure_HOST=i686-pc-windows
        if ! command -v ml > /dev/null ; then
          msvs_detect --arch=x86 > "$WORK"/msvs.source
          # shellcheck disable=SC1091
          . "$WORK"/msvs.source
          if [ -n "${MSVS_NAME}" ] ; then
            ocaml_configure_PATH_PREPEND="${MSVS_PATH}"
            ocaml_configure_LIB_PREPEND="${MSVS_LIB};"
            ocaml_configure_INC_PREPEND="${MSVS_INC};"
          fi
        fi
      ;;
      "msvc64")
        ocaml_configure_HOST=x86_64-pc-windows
        if ! command -v ml64 > /dev/null ; then
          msvs_detect --arch=x64 > "$WORK"/msvs.source
          # shellcheck disable=SC1091
          . "$WORK"/msvs.source
          if [ -n "${MSVS_NAME}" ] ; then
            ocaml_configure_PATH_PREPEND="${MSVS_PATH}"
            ocaml_configure_LIB_PREPEND="${MSVS_LIB};"
            ocaml_configure_INC_PREPEND="${MSVS_INC};"
          fi
        fi
      ;;
      *)
        if [ "$ocaml_configure_ARCH" != "auto" ] ; then
          printf "%s\n" "Compiler architecture $ocaml_configure_ARCH not recognised -- mingw64, mingw, msvc64, msvc (or auto)"
        fi
        if [ -n "${PROCESSOR_ARCHITEW6432:-}" ] || [ "${PROCESSOR_ARCHITECTURE:-}" = "AMD64" ] ; then
          TRY64=1
        else
          TRY64=0
        fi

        if [ ${TRY64} -eq 1 ] && command -v x86_64-w64-mingw32-gcc > /dev/null ; then
          ocaml_configure_HOST=x86_64-w64-mingw32
        elif command -v i686-w64-mingw32-gcc > /dev/null ; then
          ocaml_configure_HOST=i686-w64-mingw32
        elif [ ${TRY64} -eq 1 ] && command -v ml64 > /dev/null ; then
          ocaml_configure_HOST=x86_64-pc-windows
          ocaml_configure_PATH_PREPEND=$(bash "$DKMLDIR"/installtime/unix/private/reproducible-compile-ocaml-check_linker.sh)
        elif command -v ml > /dev/null ; then
          ocaml_configure_HOST=i686-pc-windows
          ocaml_configure_PATH_PREPEND=$(bash "$DKMLDIR"/installtime/unix/private/reproducible-compile-ocaml-check_linker.sh)
        else
          if [ ${TRY64} -eq 1 ] ; then
            ocaml_configure_HOST=x86_64-pc-windows
            ocaml_configure_HOST_ARCH=x64
          else
            ocaml_configure_HOST=i686-pc-windows
            ocaml_configure_HOST_ARCH=x86
          fi
          msvs_detect --arch=${ocaml_configure_HOST_ARCH} > "$WORK"/msvs.source
          # shellcheck disable=SC1091
          . "$WORK"/msvs.source
          if [ -z "${MSVS_NAME}" ] ; then
            printf "%s\n" "No appropriate C compiler was found -- unable to build OCaml"
            exit 1
          else
            ocaml_configure_PATH_PREPEND="${MSVS_PATH}"
            ocaml_configure_LIB_PREPEND="${MSVS_LIB};"
            ocaml_configure_INC_PREPEND="${MSVS_INC};"
          fi
        fi
      ;;
    esac
    if [ -n "${ocaml_configure_PATH_PREPEND}" ] ; then
      ocaml_configure_PATH_PREPEND="${ocaml_configure_PATH_PREPEND}:"
    fi
    # do ./configure; define make function
    windows_configure_and_define_make $ocaml_configure_HOST "$ocaml_configure_PREFIX" \
      "$ocaml_configure_PATH_PREPEND" "$ocaml_configure_LIB_PREPEND" "$ocaml_configure_INC_PREPEND" \
      "$ocaml_configure_EXTRA_OPTS"
  else
    DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_PLATFORM="$ocaml_configure_ABI" autodetect_compiler "$WORK"/with-compiler.sh

    # do ./configure
    # shellcheck disable=SC2086
    with_environment_for_ocaml_configure \
      PATH="$DKML_SYSTEM_PATH" \
      $ocaml_configure_no_ocaml_leak_environment \
      "$WORK"/with-compiler.sh ./configure --prefix "$ocaml_configure_PREFIX" $ocaml_configure_EXTRA_OPTS
    # define make function
    ocaml_make() {
      log_trace env PATH="$DKML_SYSTEM_PATH" "${MAKE:-make}" "$@"
    }
    # shellcheck disable=SC2034
    OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL=OFF
  fi
}