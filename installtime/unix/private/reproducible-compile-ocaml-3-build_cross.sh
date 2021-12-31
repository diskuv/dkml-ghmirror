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

# ------------------
# BEGIN Command line processing

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
    printf "%s\n" "   -e DKMLHOSTABI: Uses the Diskuv OCaml compiler detector find a host ABI compiler"
    printf "%s\n" "   -g CONFIGUREARGS: Optional. Extra arguments passed to OCaml's ./configure"
    printf "%s\n" "   -i OCAMLCARGS: Optional. Extra arguments passed to ocamlc like -g to save debugging"
    printf "%s\n" "   -j OCAMLOPTARGS: Optional. Extra arguments passed to ocamlopt like -g to save debugging"
  } >&2
}

DKMLDIR=
TARGETDIR=
TARGETABIS=
CONFIGUREARGS=
DKMLHOSTABI=
OCAMLCARGS=
OCAMLOPTARGS=
while getopts ":d:t:a:g:e:i:j:h" opt; do
  case ${opt} in
  h)
    usage
    exit 0
    ;;
  d)
    DKMLDIR="$OPTARG"
    if [ ! -e "$DKMLDIR/.dkmlroot" ]; then
      printf "%s\n" "Expected a DKMLDIR at $DKMLDIR but no .dkmlroot found" >&2
      usage
      exit 1
    fi
    DKMLDIR=$(cd "$DKMLDIR" && pwd) # absolute path
    ;;
  t)
    TARGETDIR="$OPTARG"
    ;;
  a)
    TARGETABIS="$OPTARG"
    ;;
  g)
    CONFIGUREARGS="$OPTARG"
    ;;
  e)
    DKMLHOSTABI="$OPTARG"
    ;;
  i)
    OCAMLCARGS="$OPTARG"
    ;;
  j)
    OCAMLOPTARGS="$OPTARG"
    ;;
  \?)
    printf "%s\n" "This is not an option: -$OPTARG" >&2
    usage
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "$DKMLDIR" ] || [ -z "$TARGETDIR" ] || [ -z "$DKMLHOSTABI" ]; then
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

if [ -x /usr/bin/cygpath ]; then
  OCAML_HOST=$(/usr/bin/cygpath -aw "$TARGETDIR_UNIX")
  OCAMLSRC_HOST_UNIX=$(/usr/bin/cygpath -au "$TARGETDIR_UNIX/src/ocaml")
  # Makefiles have very poor support for Windows paths, so use mixed (ex. C:/Windows) paths
  OCAMLSRC_HOST_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/src/ocaml")
  OCAMLBIN_HOST_MIXED=$(/usr/bin/cygpath -am "$TARGETDIR_UNIX/bin")
  # Use Windows paths to specify host paths on Windows ... ocamlc.exe -I <path> will
  # not understand Unix paths (but give you _no_ warning that something is wrong)
  host_dir_sep=\\
else
  OCAML_HOST=$TARGETDIR_UNIX
  OCAMLSRC_HOST_UNIX="$TARGETDIR_UNIX/src/ocaml"
  OCAMLSRC_HOST_MIXED="$TARGETDIR_UNIX/src/ocaml"
  OCAMLBIN_HOST_MIXED=$TARGETDIR_UNIX/bin
  host_dir_sep=/
fi

# Determine ext_exe from compiler (although the filename extensions on the host should be the same as well)
# shellcheck disable=SC2016
HOST_EXE_EXT=$("$OCAML_HOST${host_dir_sep}bin${host_dir_sep}ocamlc" -config | $DKMLSYS_AWK '$1=="ext_exe:"{print $2}')

OCAMLRUN="$OCAMLBIN_HOST_MIXED/ocamlrun$HOST_EXE_EXT"
OCAMLLEX="$OCAMLBIN_HOST_MIXED/ocamllex$HOST_EXE_EXT"
OCAMLYACC="$OCAMLBIN_HOST_MIXED/ocamlyacc$HOST_EXE_EXT"
OCAMLDOC="$OCAMLBIN_HOST_MIXED/ocamldoc$HOST_EXE_EXT"
CAMLDEP="$OCAMLBIN_HOST_MIXED/ocamlc$HOST_EXE_EXT -depend"

# [genWrapper NAME EXECUTABLE <genWrapperArgs*>]
#
# Preconditions: Give all <genWrapperArgs> in native Windows or Unix path format.
#
# We want the literal expansion of the command line to look like:
#   EXECUTABLE <genWrapperArgs> "$@"
# Example:
#   C:/a/b/c/ocamlc.opt.exe -I Z:\x\y\z "$@"
#
# It is important in the example above that EXECUTABLE is in mixed Windows/Unix path format
# (ie. using forward slashes); that is because the "dash" shell is explicitly used if it is
# available, and dash on MSYS2 cannot directly launch a Windows executable in the native Windows
# path format (forward slashes).
genWrapper() {
  genWrapper_NAME=$1
  shift
  genWrapper_EXECUTABLE=$1
  shift

  genWrapper_DIRNAME=$(dirname "$genWrapper_NAME")
  install -d "$genWrapper_DIRNAME"

  if [ -x /usr/bin/cygpath ]; then
    genWrapper_EXECUTABLE=$(/usr/bin/cygpath -am "$genWrapper_EXECUTABLE")
  fi

  {
    printf "#!%s\n" "$DKML_POSIX_SHELL"
    printf "set -euf\n"
    printf "exec "                                 # exec
    escape_args_for_shell "$genWrapper_EXECUTABLE" # EXECUTABLE
    printf " "                                     #
    escape_args_for_shell "$@"                     # <genWrapperArgs>
    printf " %s\n" '"$@"'                          # "$@"
  } >"$genWrapper_NAME".tmp
  $DKMLSYS_CHMOD +x "$genWrapper_NAME".tmp
  $DKMLSYS_MV "$genWrapper_NAME".tmp "$genWrapper_NAME"
}

make_caml() {
  make_caml_ABI=$1
  shift

  ocaml_make "$make_caml_ABI" \
    -j"$NUMCPUS" -l"$NUMCPUS" \
    CAMLDEP="$CAMLDEP" \
    CAMLLEX="$OCAMLLEX" OCAMLLEX="$OCAMLLEX" \
    CAMLYACC="$OCAMLYACC" OCAMLYACC="$OCAMLYACC" \
    CAMLRUN="$OCAMLRUN" OCAMLRUN="$OCAMLRUN" \
    CAMLC="$CAMLC" OCAMLC="$CAMLC" \
    CAMLOPT="$CAMLOPT" OCAMLOPT="$CAMLOPT" \
    OCAMLDOC_RUN="$OCAMLDOC" \
    "$@"
}

HOST_MAKEFILE_CONFIG="$OCAML_HOST${host_dir_sep}lib${host_dir_sep}ocaml${host_dir_sep}Makefile.config"
get_host_variable() {
  # shellcheck disable=SC2016
  grep "$1=" "$HOST_MAKEFILE_CONFIG" | $DKMLSYS_AWK -F '=' '{print $2}'
}

NATDYNLINK=$(get_host_variable "NATDYNLINK")
NATDYNLINKOPTS=$(get_host_variable "NATDYNLINKOPTS")

make_host() {
  make_host_BUILD_ROOT=$1
  shift

  # BUILD_ROOT is passed to `ocamlrun .../ocamlmklink -o unix -oc unix -ocamlc '$(CAMLC)'`
  # in Makefile, so needs to be mixed Unix/Win32 path. Also the just mentioned example is
  # run from the Command Prompt on Windows rather than MSYS2 on Windows, so use /usr/bin/env
  # to always switch into Unix context.
  make_host_ENV=$DKMLSYS_ENV
  if [ -x /usr/bin/cygpath ]; then
    make_host_BUILD_ROOT=$(/usr/bin/cygpath -am "$make_host_BUILD_ROOT")
    make_host_ENV=$(/usr/bin/cygpath -am "$make_host_ENV")
  fi

  CAMLC="$make_host_ENV $make_host_BUILD_ROOT/bin/ocamlcHost.wrapper"
  CAMLOPT="$make_host_ENV $make_host_BUILD_ROOT/bin/ocamloptHost.wrapper"

  make_caml "$DKMLHOSTABI" \
    NATDYNLINK="$NATDYNLINK" \
    NATDYNLINKOPTS="$NATDYNLINKOPTS" \
    "$@"
}

make_target() {
  make_target_ABI=$1
  shift
  make_target_BUILD_ROOT=$1
  shift

  # BUILD_ROOT is passed to `ocamlrun .../ocamlmklink -o unix -oc unix -ocamlc '$(CAMLC)'`
  # in Makefile, so needs to be mixed Unix/Win32 path. Also the just mentioned example is
  # run from the Command Prompt on Windows rather than MSYS2 on Windows, so use /usr/bin/env
  # to always switch into Unix context.
  make_target_ENV=$DKMLSYS_ENV
  if [ -x /usr/bin/cygpath ]; then
    make_target_BUILD_ROOT=$(/usr/bin/cygpath -am "$make_target_BUILD_ROOT")
    make_target_ENV=$(/usr/bin/cygpath -am "$make_target_ENV")
  fi

  CAMLC="$make_host_ENV $make_target_BUILD_ROOT/bin/ocamlcTarget.wrapper"
  CAMLOPT="$make_host_ENV $make_target_BUILD_ROOT/bin/ocamloptTarget.wrapper"

  make_caml "$make_target_ABI" BUILD_ROOT="$make_target_BUILD_ROOT" "$@"
}

# Get a triplet that can be used by OCaml's ./configure.
# See https://github.com/ocaml/ocaml/blob/35af4cddfd31129391f904167236270a004037f8/configure#L14306-L14334
# for the Android triplet format.
ocaml_android_triplet() {
  ocaml_android_triplet_ABI=$1
  shift

  if [ "${DKML_COMPILE_TYPE:-}" = CM ] && [ -n "${DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET:-}" ]; then
    # Use CMAKE_C_COMPILER_TARGET=armv7-none-linux-androideabi16 (etc.)
    # Reference: https://android.googlesource.com/platform/ndk/+/master/meta/abis.json
    case "$DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET" in
    arm*-none-linux-android* | aarch64*-none-linux-android* | i686*-none-linux-android* | x86_64*-none-linux-android*)
      printf "%s\n" "$DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET"
      return
      ;;
    esac
  fi
  # Use given DKML ABI to find OCaml triplet
  case "$ocaml_android_triplet_ABI" in
    # v7a uses soft-float not hard-float (eabihf). https://developer.android.com/ndk/guides/abis#v7a
    android_arm32v7a) printf "armv7-none-linux-androideabi\n" ;;
    # v8a probably doesn't use hard-float since removed in https://android.googlesource.com/platform/ndk/+/master/docs/HardFloatAbi.md
    android_arm64v8a) printf "armv8-none-linux-androideabi\n" ;;
    # fallback to v6 (Raspberry Pi 1, Raspberry Pi Zero). Raspberry Pi uses soft-float;
    # https://www.raspbian.org/RaspbianFAQ#What_is_Raspbian.3F . We do the same since it has most market
    # share
    *)                printf "armv5-none-linux-androideabi\n" ;;
  esac
}

build_world() {
  build_world_BUILD_ROOT=$1
  shift
  build_world_PREFIX=$1
  shift
  build_world_TARGET_ABI=$1
  shift
  build_world_PRECONFIGURE=$1
  shift

  # PREFIX is captured in `ocamlc -config` so it needs to be a mixed Unix/Win32 path.
  # BUILD_ROOT is used in `ocamlopt.opt -I ...` so it needs to be a native path or mixed Unix/Win32 path.
  if [ -x /usr/bin/cygpath ]; then
    build_world_PREFIX=$(/usr/bin/cygpath -am "$build_world_PREFIX")
    build_world_BUILD_ROOT=$(/usr/bin/cygpath -am "$build_world_BUILD_ROOT")
  fi

  case "$build_world_TARGET_ABI" in
  windows_*) build_world_TARGET_EXE_EXT=.exe ;;
  *) build_world_TARGET_EXE_EXT= ;;
  esac

  # Are we consistently Win32 host->target or consistently Unix host->target? If not we will
  # have some C functions that are missing.
  case "$DKMLHOSTABI" in
  windows_*)
    case "$build_world_TARGET_ABI" in
    windows_*) build_world_WIN32UNIX_CONSISTENT=ON ;;
    *) build_world_WIN32UNIX_CONSISTENT=OFF ;;
    esac
    ;;
  *)
    case "$build_world_TARGET_ABI" in
    windows_*) build_world_WIN32UNIX_CONSISTENT=OFF ;;
    *) build_world_WIN32UNIX_CONSISTENT=ON ;;
    esac
    ;;
  esac
  printf "build_world_WIN32UNIX_CONSISTENT=%s\n" "$build_world_WIN32UNIX_CONSISTENT" >&2

  # Make C compiler script for host and target ABI. Any compile spec (especially from CMake) will be
  # applied to the target compiler
  DKML_TARGET_PLATFORM="$DKMLHOSTABI" DKML_COMPILE_SPEC=1 DKML_COMPILE_TYPE=SYS autodetect_compiler "$build_world_BUILD_ROOT"/bin/with-host-c-compiler.sh
  DKML_TARGET_PLATFORM="$build_world_TARGET_ABI" autodetect_compiler "$build_world_BUILD_ROOT"/bin/with-target-c-compiler.sh

  # Make script to set OCAML_FLEXLINK so flexlink.exe and run correctly on Windows, and other
  # environment variables needed to link OCaml bytecode or native code on the host.
  {
    printf "#!%s\n" "$DKML_POSIX_SHELL"
    if [ -x "$OCAMLSRC_HOST_UNIX/boot/ocamlrun" ] && [ -x "$OCAMLSRC_HOST_UNIX/flexdll/flexlink" ]; then
      printf "# Since OCAML_FLEXLINK does not support spaces like in '%s'\n" 'C:\Users\John Doe\flexdll'
      printf "# TODO: Write 'ocamlrun flexlink.exe' into a script without spaces, and set OCAML_FLEXLINK to that\n"
      printf "export OCAML_FLEXLINK='%s/boot/ocamlrun %s/flexdll/flexlink.exe'\n" "$OCAMLSRC_HOST_UNIX" "$OCAMLSRC_HOST_MIXED"
      printf "exec \"\$@\"\n"
    else
      printf "exec \"\$@\"\n"
    fi
  } >"$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh.tmp
  $DKMLSYS_CHMOD +x "$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh.tmp
  $DKMLSYS_MV "$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh.tmp "$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh

  # Wrappers
  # shellcheck disable=SC2086
  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamlcHost.wrapper" "$build_world_BUILD_ROOT"/bin/with-host-c-compiler.sh "$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh "$OCAMLBIN_HOST_MIXED/ocamlc.opt$HOST_EXE_EXT" $OCAMLCARGS -I "$OCAML_HOST${host_dir_sep}lib${host_dir_sep}ocaml" -I "$OCAML_HOST${host_dir_sep}lib${host_dir_sep}ocaml${host_dir_sep}stublibs" -nostdlib
  # shellcheck disable=SC2086
  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamloptHost.wrapper" "$build_world_BUILD_ROOT"/bin/with-host-c-compiler.sh "$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh "$OCAMLBIN_HOST_MIXED/ocamlopt.opt$HOST_EXE_EXT" $OCAMLOPTARGS -I "$OCAML_HOST${host_dir_sep}lib${host_dir_sep}ocaml" -nostdlib
  # shellcheck disable=SC2086
  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamlcTarget.wrapper" "$build_world_BUILD_ROOT"/bin/with-target-c-compiler.sh "$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh "$build_world_BUILD_ROOT/ocamlc.opt$build_world_TARGET_EXE_EXT" $OCAMLCARGS -I "$build_world_BUILD_ROOT/stdlib" -I "$build_world_BUILD_ROOT/otherlibs/unix" -I "$OCAML_HOST${host_dir_sep}lib${host_dir_sep}ocaml${host_dir_sep}stublibs" -nostdlib
  # shellcheck disable=SC2086
  log_trace genWrapper "$build_world_BUILD_ROOT/bin/ocamloptTarget.wrapper" "$build_world_BUILD_ROOT"/bin/with-target-c-compiler.sh "$build_world_BUILD_ROOT"/bin/with-linking-on-host.sh "$build_world_BUILD_ROOT/ocamlopt.opt$build_world_TARGET_EXE_EXT" $OCAMLOPTARGS -I "$build_world_BUILD_ROOT/stdlib" -I "$build_world_BUILD_ROOT/otherlibs/unix" -nostdlib

  # clean (otherwise you will 'make inconsistent assumptions' errors with a mix of host + target binaries)
  make clean

  # provide --host for use in `checking whether we are cross compiling` ./configure step
  case "$build_world_TARGET_ABI" in
  android_*)
    build_world_HOST_TRIPLET=$(ocaml_android_triplet "$build_world_TARGET_ABI")
    ;;
  *)
    # This is a fallback, just not a perfect one
    build_world_HOST_TRIPLET=$("$build_world_BUILD_ROOT"/build-aux/config.guess)
    ;;
  esac

  # ./configure
  log_trace ocaml_configure "$build_world_PREFIX" "$build_world_TARGET_ABI" "$build_world_PRECONFIGURE" "--host=$build_world_HOST_TRIPLET $CONFIGUREARGS --disable-ocamldoc"

  # Build
  # -----

  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_host "$build_world_BUILD_ROOT" flexdll
  fi
  log_trace make_host "$build_world_BUILD_ROOT" runtime coreall
  log_trace make_host "$build_world_BUILD_ROOT" opt-core
  log_trace make_host "$build_world_BUILD_ROOT" ocamlc.opt NATIVECCLIBS= BYTECCLIBS= # host and target C libraries don't mix

  # Troubleshooting
  printf "+ '%s/ocamlc.opt' -config\n" "$build_world_BUILD_ROOT" >&2
  "$build_world_BUILD_ROOT"/ocamlc.opt -config >&2

  log_trace make_host "$build_world_BUILD_ROOT" ocamlopt.opt
  log_trace make_host "$build_world_BUILD_ROOT" compilerlibs/ocamltoplevel.cma otherlibraries
  log_trace make_host "$build_world_BUILD_ROOT" ocamllex.opt ocamltoolsopt

  # If the host is Windows and the target is Unix then linking to `unix.cma` will fail. So the Unix
  # target will compile otherlibs/unix/unix.cma while the Windows host will compile the
  # compatibility module otherlibs/win32unix/unix.cma, but the first requires the C function
  # `unix_waitpid` while the second requires the C function `win_waitpid`. Both C functions will not
  # exist in a single unix.cma, so the ocamlc linker will immediately stop trying to create the
  # desired executable. https://stackoverflow.com/questions/17315402/how-to-make-ocaml-bytecode-that-works-on-windows-and-linux
  # is fairly similar. For now there are no good solutions; we just try/continue the compilation.
  if [ "$build_world_WIN32UNIX_CONSISTENT" = ON ]; then
    log_trace make_host "$build_world_BUILD_ROOT" ocamldebugger
    log_trace make_host "$build_world_BUILD_ROOT" ocamltoolsopt.opt
  else
    printf "WARNING: Not building ocamldebugger and ocamltoolsopt.opt because you are crossing Windows and Unix host and target\n"
    printf '#!/bin/sh\necho "FATAL: No cross-compiled ocamldebugger"\nexit 1\n' > debugger/ocamldebug"$build_world_TARGET_EXE_EXT"
    $DKMLSYS_CHMOD +x debugger/ocamldebug"$build_world_TARGET_EXE_EXT"
  fi

  log_trace find . -name '*.cm?' -exec rm {} +
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" flexdll
  fi
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" -C stdlib all allopt
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" ocaml ocamlc
  log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" ocamlopt otherlibraries \
    otherlibrariesopt ocamltoolsopt \
    driver/main.cmx driver/optmain.cmx \
    compilerlibs/ocamlcommon.cmxa \
    compilerlibs/ocamlbytecomp.cmxa \
    compilerlibs/ocamloptcomp.cmxa
  # otherlibrariesopt:
  # ocamlrun.exe ../../tools/ocamlmklib -o unix -oc unix -ocamlopt '...' -linkall unix.cmx unixLabels.cmx
  #   ocamloptTarget.wrapper -shared -o unix.cmxs -I . unix.cmxa
  #   ** Fatal error: Cannot find file "flexdll_initer_msvc.obj"
  #   File "caml_startup", line 1:
  #   Error: Error during linking (exit code 2)
  # Cross-compiling? Can do Unix to Unix with mingw as host compiler. Or just build correct
  # unix library when cross-compiling.
  if [ "$OCAML_CONFIGURE_NEEDS_MAKE_FLEXDLL" = ON ]; then
    log_trace make_target "$build_world_TARGET_ABI" "$build_world_BUILD_ROOT" flexlink.opt
  fi

  ## Install
  log_trace "$DKMLSYS_INSTALL" "$OCAMLRUN" runtime/ocamlrun"$build_world_TARGET_EXE_EXT"
  log_trace make_host "$build_world_BUILD_ROOT" install
  log_trace make_host "$build_world_BUILD_ROOT" -C debugger install
}

# Loop over each target abi script file; each file separated by semicolons, and each term with an equals
printf "%s\n" "$TARGETABIS" | sed 's/;/\n/g' | sed 's/^\s*//; s/\s*$//' >"$WORK"/tabi
while IFS= read -r _abientry; do
  _targetabi=$(printf "%s" "$_abientry" | sed 's/=.*//')
  _abiscript=$(printf "%s" "$_abientry" | sed 's/^[^=]*=//')

  case "$_abiscript" in
  /* | ?:*) # /a/b/c or C:\Windows
    ;;
  *) # relative path; need absolute path since we will soon change dir to $_CROSS_SRCDIR
    _abiscript="$DKMLDIR/$_abiscript"
    ;;
  esac

  _CROSS_TARGETDIR=$TARGETDIR_UNIX/opt/mlcross/$_targetabi
  _CROSS_SRCDIR=$_CROSS_TARGETDIR/src/ocaml
  cd "$_CROSS_SRCDIR"
  build_world "$_CROSS_SRCDIR" "$_CROSS_TARGETDIR" "$_targetabi" "$_abiscript"
done <"$WORK"/tabi
