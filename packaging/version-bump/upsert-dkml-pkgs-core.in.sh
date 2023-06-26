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
dc_COMMIT=$(git -C '@dkml-compiler_SOURCE_DIR@' rev-parse --quiet --verify HEAD)
drc_COMMIT=$(git -C '@dkml-runtime-common_SOURCE_DIR@' rev-parse --quiet --verify HEAD)

export OPAMSWITCH=dkml

# Add or upgrade compiler packages.
# - Use topological order so don't have unnecessary reinstalls
"$OPAM_EXE" pin dkml-runtime-common-native "git+file://@dkml-runtime-common_SOURCE_DIR@/.git#$drc_COMMIT" --yes
"$OPAM_EXE" pin dkml-base-compiler "git+file://@dkml-compiler_SOURCE_DIR@/.git#$dc_COMMIT" --yes
