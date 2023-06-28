#!/bin/sh
set -euf

export TOPDIR='@dkml-runtime-common_SOURCE_DIR@/all/emptytop'
export DKMLDIR='@DKML_ROOT_DIR@'
GIT_EXECUTABLE_DIR='@GIT_EXECUTABLE_DIR@'

# Get location of opam from cmdrun/opamrun (whatever is launching this script)
OPAM_EXE=$(command -v opam)

# But especially for Windows, we need the system Git for [opam repository]
# commands and no other PATH complications.
#       shellcheck disable=SC1091
. '@dkml-runtime-common_SOURCE_DIR@/unix/crossplatform-functions.sh'
if [ -x /usr/bin/cygpath ]; then GIT_EXECUTABLE_DIR=$(/usr/bin/cygpath -au "$GIT_EXECUTABLE_DIR"); fi
export PATH="$GIT_EXECUTABLE_DIR:$PATH"
autodetect_system_path_with_git_before_usr_bin
export PATH="$DKML_SYSTEM_PATH"

export OPAMSWITCH=dkml

# Compiling Dune needs the C compiler
autodetect_compiler with-compiler.sh
if [ "${DKML_BUILD_TRACE:-}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
  echo '=== with-compiler.sh ===' >&2
  cat with-compiler.sh >&2
  echo '=== (done) ===' >&2
fi

# Add or upgrade Dune
#       shellcheck disable=SC2043
./with-compiler.sh "$OPAM_EXE" install @DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS@ --yes
