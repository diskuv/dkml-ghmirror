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

is_abi_windows() {
  is_abi_windows_ABI=$1
  shift

  case "$is_abi_windows_ABI" in
    windows_*)  return 0 ;;
    *)          return 1 ;;
  esac
}

# Set MSVS_PATH, MSVS_LIB and MSVS_INC and ABI_IS_WINDOWS
detect_msvs() {
  detect_msvs_ABI=$1
  shift

  if is_abi_windows "$detect_msvs_ABI" ; then
    # Get MSVS_* aligned to the DKML compiler
    if [ ! -e "$WORK"/msvs-detect.out ]; then
      DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_PLATFORM="$detect_msvs_ABI" autodetect_compiler --msvs-detect "$WORK"/msvs-detect
      bash "$WORK"/msvs-detect > "$WORK"/msvs-detect.out
    fi

    # shellcheck disable=SC1091
    . "$WORK"/msvs-detect.out
    if [ -z "${MSVS_NAME:-}" ] ; then
      printf "%s\n" "No appropriate Visual Studio C compiler was found -- unable to build OCaml"
      exit 1
    fi
  else
    MSVS_PATH=
    MSVS_LIB=
    MSVS_INC=
  fi
}

ocaml_make() {
  ocaml_make_ABI=$1
  shift

  if is_abi_windows "$ocaml_make_ABI" ; then
      # Set MSVS_*
      detect_msvs "$ocaml_make_ABI"

      # With MSYS2 it is quite possible to have INCLUDE and Include in the same environment. Opam seems to use camel case, which
      # is probably fine in Cygwin.
      # Also, Windows needs IFLEXDIR=-I../flexdll makefile variable or else a prior system OCaml (or a prior OCaml in the PATH) can
      # cause IFLEXDIR=..../ocaml/bin which will can hard-to-reproduce failures (missing flexdll.h, etc.).
      log_trace env --unset=LIB --unset=INCLUDE --unset=PATH --unset=Lib --unset=Include --unset=Path \
        PATH="$MSVS_PATH$DKML_SYSTEM_PATH" \
        LIB="$MSVS_LIB;${LIB:-}" \
        INCLUDE="$MSVS_INC;${INCLUDE:-}" \
        MSYS2_ARG_CONV_EXCL='*' \
        "${MAKE:-make}" "$@" IFLEXDIR=-I../flexdll
  else
    log_trace env PATH="$DKML_SYSTEM_PATH" "${MAKE:-make}" "$@"
  fi
}

ocaml_configure_windows() {
  ocaml_configure_windows_ABI="$1"
  shift
  ocaml_configure_windows_HOST="$1"
  shift
  ocaml_configure_windows_PREFIX="$1"
  shift
  ocaml_configure_windows_EXTRA_OPTS="$1"
  shift

  # Set MSVS_*
  detect_msvs "$ocaml_configure_windows_ABI"

  case "$(uname -m)" in
    'i686')
      ocaml_configure_windows_BUILD=i686-pc-cygwin
    ;;
    'x86_64')
      ocaml_configure_windows_BUILD=x86_64-pc-cygwin
    ;;
  esac

  # 4.13+ have --with-flexdll ./configure option. Autoselect it.
  ocaml_configure_windows_OCAMLVER=$(awk 'NR==1{print}' VERSION)
  ocaml_configure_windows_MAKEFLEXDLL=OFF
  case "$ocaml_configure_windows_OCAMLVER" in
    4.00.*|4.01.*|4.02.*|4.03.*|4.04.*|4.05.*|4.06.*|4.07.*|4.08.*|4.09.*|4.10.*|4.11.*|4.12.*)
      ocaml_configure_windows_MAKEFLEXDLL=ON
      ;;
    *)
      ocaml_configure_windows_EXTRA_OPTS="$ocaml_configure_windows_EXTRA_OPTS --with-flexdll"
      ;;
  esac

  ocaml_configure_windows_WINPREFIX=$(printf "%s\n" "${ocaml_configure_windows_PREFIX}" | /usr/bin/cygpath -f - -m)

  # With MSYS2 it is quite possible to have INCLUDE and Include in the same environment. Opam seems to use camel case, which
  # is probably fine in Cygwin.
  # shellcheck disable=SC2086
  configure_environment_for_ocaml --unset=LIB --unset=INCLUDE --unset=PATH --unset=Lib --unset=Include --unset=Path \
    PATH="${MSVS_PATH}$DKML_SYSTEM_PATH" \
    LIB="${MSVS_LIB}${LIB:-}" \
    INCLUDE="${MSVS_INC}${INCLUDE:-}" \
    MSYS2_ARG_CONV_EXCL='*' \
    $ocaml_configure_no_ocaml_leak_environment \
    ./configure --prefix "$ocaml_configure_windows_WINPREFIX" \
                --build=$ocaml_configure_windows_BUILD --host="$ocaml_configure_windows_HOST" \
                --disable-stdlib-manpages \
                $ocaml_configure_windows_EXTRA_OPTS
  if [ ! -e flexdll ]; then # OCaml 4.13.x has a git submodule for flexdll
    tar -xzf flexdll.tar.gz
    rm -rf flexdll
    mv flexdll-* flexdll
  fi

  if [ "$ocaml_configure_windows_MAKEFLEXDLL" = ON ]; then
    OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL=ON
  else
    # shellcheck disable=SC2034
    OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL=OFF
  fi
}

ocaml_configure_options_for_abi() {
  ocaml_configure_options_for_abi_ABI="$1"
  shift

  # This is a guess that OCaml uses; it is useful when you can construct the desired ABI from the host ABI.
  ocaml_configure_options_for_abi_GUESS=$(build-aux/config.guess)
  
  # Cautionary notes
  # ----------------
  #
  # 1. Because native code compiler is based on the _host_ rather than the _target_, we likely have to change the host flag.
  #    https://github.com/ocaml/ocaml/blob/7997b65fdc87909e83f497da866763174699936e/configure#L14273-L14279
  #    This is a bug! The native code compiler should run on `--host` but should produce code for `--target`.
  #    Reference: https://gcc.gnu.org/onlinedocs/gccint/Configure-Terms.html ; just replace "GCC" with "OCaml Native Compiler".
  # 2. The ./configure script on Windows does a good job of figuring out the target based on the compiler.
  #    Others, especially multi-target compilers like `clang -arch XXXX`, need to be explicitly told the target.
  #    It doesn't look like OCaml uses `--target` consistently (ex. see #1), but let's be consistent ourselves.
  case "$ocaml_configure_options_for_abi_ABI" in
    darwin_x86_64)
      case "$ocaml_configure_options_for_abi_GUESS" in
        *-apple-*) # example: aarch64-apple-darwin21.1.0 -> x86_64-apple-darwin21.1.0
          printf "%s=%s %s=%s" "--host" "$ocaml_configure_options_for_abi_GUESS" "--target" "$ocaml_configure_options_for_abi_GUESS" | sed 's/=[A-Za-z0-9_]*-/=x86_64-/g'
          ;;
        *)
          printf "%s" "--target=x86_64-apple-darwin";;
      esac
      ;;
    darwin_arm64)
      case "$ocaml_configure_options_for_abi_GUESS" in
        *-apple-*) # example: x86_64-apple-darwin21.1.0 -> aarch64-apple-darwin21.1.0
          printf "%s=%s %s=%s" "--host" "$ocaml_configure_options_for_abi_GUESS" "--target" "$ocaml_configure_options_for_abi_GUESS" | sed 's/=[A-Za-z0-9_]*-/=aarch64-/g'
          ;;
        *)
          printf "%s" "--target=aarch64-apple-darwin"
          ;;
      esac
      ;;
  esac
}

ocaml_configure() {
  ocaml_configure_PREFIX="$1"
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

  # Configure options
  # -----------------

  # Add more, if any, options based on the ABI
  ocaml_configure_EXTRA_ABI_OPTS=$(ocaml_configure_options_for_abi "$ocaml_configure_ABI")
  ocaml_configure_EXTRA_OPTS=$(printf "%s %s" "$ocaml_configure_EXTRA_OPTS" "$ocaml_configure_EXTRA_ABI_OPTS")

  # ./configure and define make functions
  # -------------------------------------

  if is_abi_windows "$ocaml_configure_ABI"; then
    # Detect the compiler matching the host ABI
    # Sets OCAML_HOST_TRIPLET that corresponds to ocaml_configure_ABI, and creates the specified script
    DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_PLATFORM="$ocaml_configure_ABI" autodetect_compiler "$WORK"/env-with-compiler.sh

    # When we run OCaml's ./configure, the DKML compiler must be available
    make_preconfigured_env_script "$WORK"/env-with-compiler.sh "$WORK"/preconfigured-env-with-compiler.sh
    configure_environment_for_ocaml() {
      log_shell "$WORK"/preconfigured-env-with-compiler.sh "$@"
    }

    # do ./configure and define make using host triplet defined in compiler autodetection
    ocaml_configure_windows "$ocaml_configure_ABI" "$OCAML_HOST_TRIPLET" "$ocaml_configure_PREFIX" "$ocaml_configure_EXTRA_OPTS"
  else
    # Detect compiler; exports DKML_TARGET_SYSROOT as needed
    DKML_FEATUREFLAG_CMAKE_PLATFORM=ON DKML_TARGET_PLATFORM="$ocaml_configure_ABI" autodetect_compiler "$WORK"/with-compiler.sh

    if [ "${DKML_BUILD_TRACE:-}" = ON ]; then
      printf "@+ with-compiler.sh generated by autodetect_compiler\n" >&2
      "$DKMLSYS_SED" 's/^/@+| /' "$WORK"/with-compiler.sh | "$DKMLSYS_AWK" '{print}' >&2
    fi

    # sysroot
    if [ -n "${DKML_TARGET_SYSROOT:-}" ]; then
      if [ -x /usr/bin/cygpath ]; then
        ocaml_configure_SYSROOT=$(/usr/bin/cygpath -am "$DKML_TARGET_SYSROOT")
      else
        ocaml_configure_SYSROOT="$DKML_TARGET_SYSROOT"
      fi
    else
      ocaml_configure_SYSROOT=
    fi

    # When we run OCaml's ./configure, the with-compiler.sh must be available
    printf "exec %s %s\n" "$DKMLSYS_ENV" '"$@"' > "$WORK"/basic-env.sh
    make_preconfigured_env_script "$WORK"/basic-env.sh "$WORK"/preconfigured-env.sh
    configure_environment_for_ocaml() {
      log_shell "$WORK"/preconfigured-env.sh "$@"
    }
    run_script_and_then_configure_environment_for_ocaml() {
      run_script_and_then_configure_environment_for_ocaml_SCRIPT=$1
      shift
      log_shell "$run_script_and_then_configure_environment_for_ocaml_SCRIPT" "$WORK"/preconfigured-env.sh "$@"
    }

    # do ./configure
    if [ -n "$ocaml_configure_SYSROOT" ]; then
      # shellcheck disable=SC2086
      run_script_and_then_configure_environment_for_ocaml \
        "$WORK"/with-compiler.sh \
        "$DKMLSYS_ENV" $ocaml_configure_no_ocaml_leak_environment \
        ./configure --prefix "$ocaml_configure_PREFIX" --with-sysroot="$ocaml_configure_SYSROOT" $ocaml_configure_EXTRA_OPTS
    else
      # shellcheck disable=SC2086
      run_script_and_then_configure_environment_for_ocaml \
        "$WORK"/with-compiler.sh \
        "$DKMLSYS_ENV" $ocaml_configure_no_ocaml_leak_environment \
        ./configure --prefix "$ocaml_configure_PREFIX" $ocaml_configure_EXTRA_OPTS
    fi

    # shellcheck disable=SC2034
    OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL=OFF
  fi
}
