#!/bin/sh

GIT_EXECUTABLE_DIR='@GIT_EXECUTABLE_DIR@'
UPSERT_BINARY_DIR=$(pwd)

# Get location of opam from cmdrun/opamrun (whatever is launching this script)
OPAM_EXE=$(command -v opam)
export OPAMSWITCH=@SHORT_BUMP_LEVEL@

# Especially for Windows, we need the system Git for [opam repository]
# commands and no other PATH complications.
#       shellcheck disable=SC1091
. '@dkml-runtime-common_SOURCE_DIR@/unix/crossplatform-functions.sh'
if [ -x /usr/bin/cygpath ]; then GIT_EXECUTABLE_DIR=$(/usr/bin/cygpath -au "$GIT_EXECUTABLE_DIR"); fi
export PATH="$GIT_EXECUTABLE_DIR:$PATH"
autodetect_system_path_with_git_before_usr_bin
export PATH="$DKML_SYSTEM_PATH"

# [idempotent_opam_local_install name absdir ./pkg1.opam ./pkg2.opam ...]
# conditionally executes `opam install ./pkg1.opam ./pkg2.opam ...`
# in the absolute directory <absdir>.
#
# On exit, the directory is restored to whatever it was on entry.
#
# If either of the following conditions are true, the installation will execute:
# 1. The [name] has not been used before.
# 2. The last time [name] was used the git commit id of [absdir]
#    was different.
idempotent_opam_local_install() {
    idempotent_opam_local_install_NAME=$1; shift
    idempotent_opam_local_install_COMMITSOURCE_DIR=$1; shift
    idempotent_opam_local_install_COMMIT=$(git -C "$idempotent_opam_local_install_COMMITSOURCE_DIR" rev-parse --quiet --verify HEAD)
    idempotent_opam_local_install_LASTGITREFFILE="$UPSERT_BINARY_DIR/$idempotent_opam_local_install_NAME.installed.gitref"
    idempotent_opam_local_install_REBUILD=1
    if [ -e "$idempotent_opam_local_install_LASTGITREFFILE" ]; then
        idempotent_opam_local_install_LASTGITREF=$(cat "$idempotent_opam_local_install_LASTGITREFFILE")
        if [ "$idempotent_opam_local_install_LASTGITREF" = "$idempotent_opam_local_install_COMMIT" ]; then
            idempotent_opam_local_install_REBUILD=0
        fi
    fi
    if [ $idempotent_opam_local_install_REBUILD -eq 1 ]; then
        idempotent_opam_local_install_ENTRYDIR=$(pwd)
        # - [cd ..._SOURCE_DIR ; opam install ./x.opam] is required because opam 2.2 prereleases say:
        #   "Invalid character in package name" when opam install Z:/x/y/z/a.opam
        cd "$idempotent_opam_local_install_COMMITSOURCE_DIR" || exit 67
        '@WITH_COMPILER_SH@' "$OPAM_EXE" install "$@" --ignore-pin-depends --yes
        cd "$idempotent_opam_local_install_ENTRYDIR" || exit 67

        printf "%s" "$idempotent_opam_local_install_COMMIT" > "$idempotent_opam_local_install_LASTGITREFFILE"
    fi
}

# [idempotent_opam_install name pkg1.ver1 pkg2.ver2 ...] conditionally executes
# `opam install pkg1.ver1 pkg2.ver2 ...`.
#
# If either of the following conditions are true, the installation will execute:
# 1. The [name] has not been used before.
# 2. The last time [name] was used the package list [pkg1.ver1 pkg2.ver2 ...]
#    was different.
idempotent_opam_install() {
    idempotent_opam_install_NAME=$1; shift
    idempotent_opam_install_IDEMPOTENT_ID="$*"
    idempotent_opam_install_LAST_ID_FILE="$UPSERT_BINARY_DIR/$idempotent_opam_install_NAME.installed.id"
    idempotent_opam_install_REBUILD=1
    if [ -e "$idempotent_opam_install_LAST_ID_FILE" ]; then
        idempotent_opam_install_LAST_ID=$(cat "$idempotent_opam_install_LAST_ID_FILE")
        if [ "$idempotent_opam_install_LAST_ID" = "$idempotent_opam_install_IDEMPOTENT_ID" ]; then
            idempotent_opam_install_REBUILD=0
        fi
    fi
    if [ $idempotent_opam_install_REBUILD -eq 1 ]; then
        '@WITH_COMPILER_SH@' "$OPAM_EXE" install "$@" --yes
        printf "%s" "$idempotent_opam_install_IDEMPOTENT_ID" > "$idempotent_opam_install_LAST_ID_FILE"
    fi
}
