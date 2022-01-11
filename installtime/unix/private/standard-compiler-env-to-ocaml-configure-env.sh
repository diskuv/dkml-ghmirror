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
# On entry the following non-exported environment variables will be available:
# * DKML_TARGET_ABI
# * DKMLDIR
#
# DKML's autodetect_compiler() function will have already set common ./configure variables as
# described in https://www.gnu.org/software/make/manual/html_node/Implicit-Variables.html. The
# compiler will have been from:
# a) find the compiler selected/validated in the Diskuv OCaml installation (Windows) or on first-use (Unix)
# b) find the specific architecture that has been given to us in DKML_TARGET_ABI
#
# On exit the variables needed for github.com/ocaml/ocaml/configure will be set and exported.
set -euf

# shellcheck disable=SC1091
. "$DKMLDIR"/etc/contexts/linux-build/crossplatform-functions.sh

# Microsoft cl.exe and link.exe use forward slash (/) options; do not ever let MSYS2 interpret
# the forward slash and try to convert it to a Windows path.
disambiguate_filesystem_paths

# ---------------------------------------
# github.com/ocaml/ocaml/configure output
# ---------------------------------------

# Common passthrough flags
export PATH AR

# CC
# The value of this appears in `ocamlc -config`; will be viral to most Opam packages with embedded C code.
# clang and perhaps other compilers need --target=armv7-none-linux-androideabi21 for example
if [ -n "${CC:-}" ]; then
  ORIG_CC=$CC

  # OCaml's 4.14+ ./configure has func_cc_basename () which returns "gcc" if a GCC compiler, etc.
  # However it uses the basename ... so a symlink from /usr/bin/cc to to /etc/alternatives/cc to /usr/bin/gcc
  # to /usr/bin/x86_64-linux-gnu-gcc-9 for example would return "cc" and then code like
  # `./configure --enable-frame-pointers` would fail because it was looking for "gcc".
  #
  # Even worse, earlier versions of OCaml just used the variable "$CC" and checked if it was "gcc*".
  #
  # Mitigation: See if $CC resolves to the same realpath as gcc. Use it if it does. But prefer
  # "gcc" if it is /usr/bin/gcc.
  _GCCEXE=$(command -v gcc || true)
  if [ -n "$_GCCEXE" ] && [ -x /usr/bin/realpath ]; then
    _CC_1=$(/usr/bin/realpath "$CC")
    _CC_2=$(/usr/bin/realpath "$_GCCEXE")
    _CC_RESOLVE=$_GCCEXE
    if [ "$_GCCEXE" = /usr/bin/gcc ]; then
      _CC_RESOLVE=gcc
    fi
    if [ "$_CC_1" = "$_CC_2" ]; then
      CC=$_CC_RESOLVE
    fi
  fi

  # Add --target if necessary
  CC="$CC ${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_TARGET:-}${DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET:-}"
  # clang and perhaps other compilers need --sysroot=C:/Users/beckf/AppData/Local/Android/Sdk/ndk/21.4.7075529/toolchains/llvm/prebuilt/windows-x86_64/sysroot for example
  CC="$CC ${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_SYSROOT:-}${DKML_COMPILE_CM_CMAKE_SYSROOT:-}"
else
  ORIG_CC=
fi
export CC

# CFLAGS
# The value of this appears in `ocamlc -config`; will be viral to most Opam packages with embedded C code.
# -m32 is an option that needs to be in CC for OCaml rather than CFLAGS since CFLAGS not used to created shared libraries.
if [ -n "${CC:-}" ]; then
  if printf "%s" "${CFLAGS:-}" | PATH=/usr/bin:/bin grep -q '\B-m32\b'; then
      CC="$CC -m32"
      CFLAGS=$(printf "%s" "$CFLAGS" | PATH=/usr/bin:/bin sed 's/\B-m32\b//g')
  fi
  if printf "%s" "${CFLAGS:-}" | PATH=/usr/bin:/bin grep -q '\B-m64\b'; then
      CC="$CC -m64"
      CFLAGS=$(printf "%s" "$CFLAGS" | PATH=/usr/bin:/bin sed 's/\B-m64\b//g')
  fi

  # For OCaml 5.00 there is an error with GCC:
  #   gc_ctrl.c:201:28: error: format ‘%zu’ expects argument of type ‘size_t’, but argument 3 has type ‘long unsigned int’ [-Werror=format=]
  case "${CC:-}" in
    */gcc*|gcc*) CFLAGS="${CFLAGS:-} -Wno-format" ;;
  esac
fi
export CFLAGS

# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure.ac#L1213-L1240
if cmake_flag_on "${DKML_COMPILE_CM_MSVC:-}"; then
    # Use the MASM compiler (ml/ml64) which is required for OCaml with MSVC.
    # See https://github.com/ocaml/ocaml/blob/4c52549642873f9f738dd89ab39cec614fb130b8/configure#L14585-L14588 for options
    if [ "${DKML_COMPILE_CM_CONFIG:-}" = "Debug" ]; then
      _MLARG_EXTRA=" -Zi"
    else
      _MLARG_EXTRA=
    fi
    if [ "$DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P" -eq 4 ]; then
      AS="${DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER}${_MLARG_EXTRA} -nologo -coff -Cp -c -Fo"
    else
      AS="${DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER}${_MLARG_EXTRA} -nologo -Cp -c -Fo"
    fi
    ASPP="$AS"
elif [ -n "${AS:-}" ]; then
  _TMP_AS="${AS:-}"
  AS="$_TMP_AS ${DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OPTIONS_TARGET:-}${DKML_COMPILE_CM_CMAKE_ASM_COMPILER_TARGET:-} ${ASFLAGS:-}"

  # Some architectures need flags when compiling OCaml
  case "$DKML_TARGET_ABI" in
    darwin_*) AS="$AS -Wno-trigraphs" ;;
  esac

  # A CMake-configured `AS` will be missing the `-c` option needed by OCaml; fix that
  if printf "%s" "${DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OBJECT:-}" | PATH=/usr/bin:/bin grep -q -E -- '\B-c\b'; then
    # CMAKE_ASM_COMPILE_OBJECT contains '-c' as a single word. Ex: <CMAKE_ASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -o <OBJECT> -c <SOURCE>
    AS="$AS -c"
  fi

  # By default ASPP is the same as AS. But since ASPP involves preprocessing and many assemblers do not include
  # preprocessing, we may need to look at the C compiler (ex. clang) and see if we should override ASPP.
  ASPP="$AS"
  case "$ORIG_CC" in
    gcc|*-gcc|*/gcc)
      ASPP="$CC -c" # include -m32 by using $CC
      ;;
  esac
  case "${DKML_COMPILE_CM_CMAKE_C_COMPILER_ID:-}" in
    AppleClang|Clang)
      # Clang Integrated Assembler
      # --------------------------
      #
      # Clang has an integrated assembler that will can be invoked indirectly (`clang --target xxx -c something.s`)
      # or directly (`clang -cc1as -help`). Calling with the `cc1as` form directly is rarely a good idea because the
      # `--target` form can inject a lot of useful default options when it itself calls `clang -cc1as <options-for-target>`.
      #
      # The integrated assembler is not strictly compatible with GNU `as` even though it recognizes GNU assembly syntax.
      # For OCaml the problem is that the integrated assembler will "error: invalid symbol redefinition" on OCaml native
      # generated assembly code like:
      #   .L108:
      #   .L108:
      # 	  bl	camlCamlinternalFormatBasics__entry(PLT)
      # Until those bugs are fixed we can't use clang for native generated code (the `AS` ./configure variable). However
      # clang can be used for the assembly code in the runtime library (the `ASPP` ./configure variable) since that assembly
      # code is hand-crafted and also because the clang integrated assembler has a preprocessor.

      # Android NDK
      # -----------
      #
      # Android NDK comes with a) a Clang compiler and b) a GNU AS assembler and c) sometimes a YASM assembler
      # in its bin folder
      # (ex. ndk/23.1.7779620/toolchains/llvm/prebuilt/linux-x86_64/bin/{clang,arm-linux-androideabi-as,yasm}).
      # The Android NDK toolchain used within CMake will select the Clang compiler as its CMAKE_ASM_COMPILER.
      #
      # The GNU AS assembler (https://sourceware.org/binutils/docs/as/index.html) does not support preprocessing
      # so it cannot be used as the `ASPP` ./configure variable.
      
      # XCode (macOS/iOS)
      # -----------------
      #
      # Nothing will be found in the code below that searches for a `<triple>-as` assembler. macOS uses
      # `AS=as -arch <target>` to select the architecture, and AS will have already been set with
      # autodetect_compiler_darwin().

      # Triples
      # -------
      #
      # Android NDK for example exposes a triple like so: CMAKE_ANDROID_ARCH_TRIPLE=arm-linux-androideabi
      # It also has the same triple in CMAKE_LIBRARY_ARCHITECTURE.
      # Other toolchains may support it as well; CMAKE_LIBRARY_ARCHITECTURE is poorly documented, but
      # https://lldb.llvm.org/resources/build.html indicates it is typically set to the architecture triple

      # Find GNU AS assembler named `<triple>-as`, if any
      #
      #   Nothing should be found in this code section if you are using an Xcode toolchain. macOS uses
      #   `AS=as -arch <target>` to select the architecture, and AS will have already been set with
      #   autodetect_compiler_darwin().
      _c_compiler_bindir=$(PATH=/usr/bin:/bin dirname "$DKML_COMPILE_CM_CMAKE_C_COMPILER")
      _gnu_as_compiler=
      for _compiler_triple in "${DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_TRIPLE:-}" "${DKML_COMPILE_CM_CMAKE_LIBRARY_ARCHITECTURE:-}"; do
        if [ -n "$_compiler_triple" ]; then
          if [ -e "$_c_compiler_bindir/$_compiler_triple-as.exe" ]; then
            _gnu_as_compiler="$_c_compiler_bindir/$_compiler_triple-as.exe"
            break
          elif [ -e "$_c_compiler_bindir/$_compiler_triple-as" ]; then
            _gnu_as_compiler="$_c_compiler_bindir/$_compiler_triple-as"
            break
          fi
        fi
      done
      if [ -n "$_gnu_as_compiler" ]; then
        # Found GNU AS assembler
        if [ -x /usr/bin/cygpath ]; then
          _gnu_as_compiler=$(/usr/bin/cygpath -am "$_gnu_as_compiler")
        fi
        AS="$_gnu_as_compiler"
        ASPP="$DKML_COMPILE_CM_CMAKE_C_COMPILER ${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_TARGET:-}${DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET:-} ${CFLAGS:-} -c"
        if [ "${DKML_COMPILE_CM_CONFIG:-}" = "Debug" ]; then
          AS="$AS -g"
          # CFLAGS will already include `-g` if the toolchain wanted it.
          # But we add -fdebug-macro since there are very useful macros in the runtime code (ex. runtime/arm.S) that should be expanded when in disassembly
          # or in lldb/gdb debugger.
          ASPP="$ASPP -fdebug-macro"
        fi
      fi
      ;;
  esac
fi
export AS ASPP

# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure#L3434-L3534
# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure.ac#L1158-L1175
if [ -n "${DKML_COMPILE_CM_CMAKE_LINKER:-}" ]; then
  LD=$DKML_COMPILE_CM_CMAKE_LINKER
  DIRECT_LD=$DKML_COMPILE_CM_CMAKE_LINKER
fi
# OCaml uses LDFLAGS for both $CC (ex. gcc) and $LD, so we have to zero out
# LDFLAGS and push LDFLAGS into LD directly
if [ -n "${LD:-}" ]; then
  LD="$LD ${LDFLAGS:-}"
  DIRECT_LD=$LD
  LDFLAGS=
fi
export LD DIRECT_LD LDFLAGS

# STRIP, RANLIB, NM, OBJDUMP
RANLIB="${DKML_COMPILE_CM_CMAKE_RANLIB:-}"
STRIP="${DKML_COMPILE_CM_CMAKE_STRIP:-}"
NM="${DKML_COMPILE_CM_CMAKE_NM:-}"
OBJDUMP="${DKML_COMPILE_CM_CMAKE_OBJDUMP:-}"
export STRIP RANLIB NM OBJDUMP

# Final fixup
if cmake_flag_on "${DKML_COMPILE_CM_MSVC:-}"; then
    # To avoid the following when /Zi or /ZI is enabled:
    #   2># major_gc.c : fatal error C1041: cannot open program database 'Z:\build\windows_x86\Debug\dksdk\system\_opam\.opam-switch\build\ocaml-variants.4.12.0+options+dkml+msvc32\runtime\vc140.pdb'; if multiple CL.EXE write to the same .PDB file, please use /FS
    # we use /FS. This slows things down, so we should only do it
    if printf "%s" "${CFLAGS:-}" | PATH=/usr/bin:/bin grep -q "[/-]Zi"; then
        CFLAGS="$CFLAGS /FS"
    elif printf "%s" "${CFLAGS:-}" | PATH=/usr/bin:/bin grep -q "[/-]ZI"; then
        CFLAGS="$CFLAGS /FS"
    fi

    # To avoid the following when /O2 is added by OCaml ./configure to the given "$DKML_COMPILE_CM_CMAKE_C_FLAGS $_CMAKE_C_FLAGS_FOR_CONFIG" = "/DWIN32 /D_WINDOWS /Zi /Ob0 /Od /RTC1" :
    #   (cd _build/default/src && C:\DiskuvOCaml\BuildTools\VC\Tools\MSVC\14.26.28801\bin\HostX64\x86\cl.exe -nologo -O2 -Gy- -MD -DWIN32 -D_WINDOWS -Zi -Ob0 -Od -RTC1 -FS -D_CRT_SECURE_NO_DEPRECATE -nologo -O2 -Gy- -MD -DWIN32 -D_WINDOWS -Zi -Ob0 -Od -RTC1 -FS -D_LARGEFILE64_SOURCE -I Z:/build/windows_x86/Debug/dksdk/host-tools/_opam/lib/ocaml -I Z:\build\windows_x86\Debug\dksdk\system\_opam\lib\sexplib0 -I ../compiler-stdlib/src -I ../hash_types/src -I ../shadow-stdlib/src /Foexn_stubs.obj -c exn_stubs.c)
    #   cl : Command line error D8016 : '/RTC1' and '/O2' command-line options are incompatible
    # we remove any /RTC1 from the flags
    CFLAGS=$(printf "%s" "${CFLAGS:-}" | PATH=/usr/bin:/bin sed 's#\B/RTC1\b##g')

    # Always use dash (-) form of options rather than slash (/) options. Makes MSYS2 not try
    # to think the option is a filepath and try to translate it.
    CFLAGS=$(printf "%s" "${CFLAGS:-}" | PATH=/usr/bin:/bin sed 's# /# -#g')
    CC=$(printf "%s" "${CC:-}" | PATH=/usr/bin:/bin sed 's# /# -#g')
    ASPP=$(printf "%s" "${ASPP:-}" | PATH=/usr/bin:/bin sed 's# /# -#g')
    AS=$(printf "%s" "${AS:-}" | PATH=/usr/bin:/bin sed 's# /# -#g')
fi
