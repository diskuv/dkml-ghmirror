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
        # - [cd ..._SOURCE_DIR ; opam install ./x.opam] is required because opam 2.2 prereleases say:
        #   "Invalid character in package name" when opam install Z:/x/y/z/a.opam
        cd "$idempotent_opam_local_install_COMMITSOURCE_DIR" || exit 67
        '@WITH_COMPILER_SH@' "$OPAM_EXE" install "$@" --ignore-pin-depends --yes
        printf "%s" "$idempotent_opam_local_install_COMMIT" > "$idempotent_opam_local_install_LASTGITREFFILE"
    fi
    cd "$UPSERT_BINARY_DIR" || exit 67
}
