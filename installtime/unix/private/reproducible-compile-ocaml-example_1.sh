#!/bin/sh
#
# On entry the following non-exported environment variables will be available:
# * DKML_TARGET_ABI
# * DKMLDIR
#
# On exit the variables needed for github.com/ocaml/ocaml/configure will be set and exported.
#
# This example uses DKML's autodetect_compiler() function to:
# a) find the compiler selected/validated in the Diskuv OCaml installation (Windows) or on first-use (Unix)
# b) find the specific architecture that has been given to us in DKML_TARGET_PLATFORM
set -euf

# shellcheck disable=SC1091
. "$DKMLDIR"/etc/contexts/linux-build/crossplatform-functions.sh

# Microsoft cl.exe and link.exe use forward slash (/) options; do not ever let MSYS2 interpret
# the forward slash and try to convert it to a Windows path.
disambiguate_filesystem_paths

# ---------------------------------------
# github.com/ocaml/ocaml/configure output
# ---------------------------------------

export PATH LDFLAGS AR

# CFLAGS
# The value of this appears in `ocamlc -config`; will be viral to most Opam packages with embedded C code
export CFLAGS

# CC
# The value of this appears in `ocamlc -config`; will be viral to most Opam packages with embedded C code
# clang and perhaps other compilers need --target=armv7-none-linux-androideabi21 for example
CC="$CC ${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_TARGET:-}${DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET:-}"
# clang and perhaps other compilers need --sysroot=C:/Users/beckf/AppData/Local/Android/Sdk/ndk/21.4.7075529/toolchains/llvm/prebuilt/windows-x86_64/sysroot for example
CC="$CC ${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_SYSROOT:-}${DKML_COMPILE_CM_CMAKE_SYSROOT:-}"
export CC

## DEP_CC
## In ./configure this will be used to capture dependencies with -MT and -MT flags. Unlike CC, no
## CFLAGS are used with it which means important flags like -fPIC are lost in the dependencies.
## That makes linking impossible for clang (at least for Android armeabi-v7a). clang and gcc are
## capable of capturing dependencies, so just use the CC + CFLAGS compiler
#case "${DKML_COMPILE_CM_CMAKE_C_COMPILER_ID:-}" in
#  AppleClang|Clang|GNU)
#    DEP_CC="$CC $CFLAGS"
#    export DEP_CC
#    ;;
#esac

# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure.ac#L1213-L1240
_TMP_AS="${AS:-}"
AS="$_TMP_AS ${DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OPTIONS_TARGET:-}${DKML_COMPILE_CM_CMAKE_ASM_COMPILER_TARGET:-} $ASFLAGS"
case "$DKML_TARGET_ABI" in
  darwin_*) AS="$AS -Wno-trigraphs" ;;
esac
if printf "%s" "${DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OBJECT:-}" | PATH=/usr/bin:/bin grep -q -E -- '\B-c\b'; then
  # CMAKE_ASM_COMPILE_OBJECT contains '-c' as a single word. Ex: <CMAKE_ASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -o <OBJECT> -c <SOURCE>
  AS="$AS -c"
fi
ASPP="$AS"
case "${DKML_COMPILE_CM_CMAKE_ASM_COMPILER_ID:-}" in
  AppleClang|Clang)
    # For clang, AS should be `as` so that relocations work properly and ASPP should be `clang -c`.
    # So we try <bindir>/<CMAKE_ANDROID_ARCH_TRIPLE>-as and <bindir>/<CMAKE_LIBRARY_ARCHITECTURE>-as.
    # (CMAKE_LIBRARY_ARCHITECTURE is poorly documented, but https://lldb.llvm.org/resources/build.html
    # indicates it is typically set to the architecture triple; Android NDK does this).
    _asm_compiler_bindir=$(PATH=/usr/bin:/bin dirname "$DKML_COMPILE_CM_CMAKE_ASM_COMPILER")
    _asm_compiler_as=
    if [ -e "$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_TRIPLE:-}-as.exe" ]; then
      _asm_compiler_as="$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_TRIPLE:-}-as.exe"
    elif [ -e "$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_TRIPLE:-}-as" ]; then
      _asm_compiler_as="$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_TRIPLE:-}-as"

    elif [ -e "$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_LIBRARY_ARCHITECTURE:-}-as.exe" ]; then
      _asm_compiler_as="$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_LIBRARY_ARCHITECTURE:-}-as.exe"
    elif [ -e "$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_LIBRARY_ARCHITECTURE:-}-as" ]; then
      _asm_compiler_as="$_asm_compiler_bindir/${DKML_COMPILE_CM_CMAKE_LIBRARY_ARCHITECTURE:-}-as"
    fi
    if [ -n "$_asm_compiler_as" ]; then
      if [ -x /usr/bin/cygpath ]; then
        _asm_compiler_as=$(/usr/bin/cygpath -am "$_asm_compiler_as")
      fi
      AS="$_asm_compiler_as"
    fi
    ;;
esac
export AS ASPP

# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure#L3434-L3534
# https://github.com/ocaml/ocaml/blob/01c6f16cc69ce1d8cf157e66d5702fadaa18d247/configure.ac#L1158-L1175
if [ -n "${DKML_COMPILE_CM_CMAKE_LINKER:-}" ]; then
  LD=$DKML_COMPILE_CM_CMAKE_LINKER
  DIRECT_LD=$DKML_COMPILE_CM_CMAKE_LINKER
fi
export LD DIRECT_LD

# STRIP, RANLIB, NM, OBJDUMP
RANLIB="${DKML_COMPILE_CM_CMAKE_RANLIB:-}"
STRIP="${DKML_COMPILE_CM_CMAKE_STRIP:-}"
NM="${DKML_COMPILE_CM_CMAKE_NM:-}"
OBJDUMP="${DKML_COMPILE_CM_CMAKE_OBJDUMP:-}"
export STRIP RANLIB NM OBJDUMP
