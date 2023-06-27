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

# The Opam 2.2 prereleases have finicky behavior with git pins. We really
# need to use a commit id not just a branch. Without a commit id, often
# Opam does not know there is an update.
#dc_COMMIT=$(git -C '@dkml-compiler_SOURCE_DIR@' rev-parse --quiet --verify HEAD)
#drc_COMMIT=$(git -C '@dkml-runtime-common_SOURCE_DIR@' rev-parse --quiet --verify HEAD)

export OPAMSWITCH=dkml

# dkml-base-compiler can find its own C compiler, so it does not need
# with-compiler.sh. However, during an opam recompile (perhaps
# dkml-base-compiler was updated) many already-installed packages will
# need a C compiler. This lack of C compiler won't appear during the initial
# install (because dkml-base-compiler does not need it), but will during a
# recompile. So we force the use of with-compiler.sh.
ORIGDIR=$(pwd)
autodetect_compiler with-compiler.sh
if [ "${DKML_BUILD_TRACE:-}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
  echo '=== with-compiler.sh ===' >&2
  cat with-compiler.sh >&2
  echo '=== (done) ===' >&2
fi

# Add or upgrade compiler packages.
# - Use topological order so don't have unnecessary reinstalls
#"$OPAM_EXE" pin dkml-runtime-common-native "git+file://@dkml-runtime-common_SOURCE_DIR@/.git#$drc_COMMIT" --yes --no-action
#"$OPAM_EXE" pin dkml-base-compiler "git+file://@dkml-compiler_SOURCE_DIR@/.git#$dc_COMMIT" --yes --no-action
# - Weird pin + install sequence?
#   - [opam pin ...#COMMIT] is to ensure opam knows there is an update. But opam
#     will report new versions as missing from the repository the _second_ time this
#     is run (probably because opam pin does a consistency check when it re-pins).
#     [opam install] has the same problem, but [opam install --ignore-pin-depends]
#     does not.
#     So rely only on [opam install --ignore-pin-depends] being correct that
#     there is a change to git
#     commit during repeated, partially aborted PRERELEASE where [version:] does
#     not change (it already detects an opam [version:] change accurately).
#   - [opam install] is only way to have opam report any new version numbers embedded in .opam.
# - [cd ..._SOURCE_DIR && opam install ./x.opam] is required because opam 2.2 prereleases say:
#   "Invalid character in package name" when opam install Z:/x/y/z/a.opam
cd '@dkml-runtime-common_SOURCE_DIR@' && "$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install ./dkml-runtime-common-native.opam --ignore-pin-depends --yes
cd '@dkml-compiler_SOURCE_DIR@' && "$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install ./dkml-base-compiler.opam --ignore-pin-depends --yes
