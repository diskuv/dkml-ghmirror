#!/bin/sh

GIT_EXECUTABLE_DIR='@GIT_EXECUTABLE_DIR@'
UPSERT_BINARY_DIR=$(pwd)

# Get location of opam from cmdrun/opamrun (whatever is launching this script)
OPAM_EXE=$(command -v opam)
export OPAMSWITCH=@DKML_VERSION_CMAKEVER@

# Especially for Windows, we need the system Git for [opam repository]
# commands and no other PATH complications.
#       shellcheck disable=SC1091
. '@dkml-runtime-common_SOURCE_DIR@/unix/crossplatform-functions.sh'
if [ -x /usr/bin/cygpath ]; then GIT_EXECUTABLE_DIR=$(/usr/bin/cygpath -au "$GIT_EXECUTABLE_DIR"); fi
export PATH="$GIT_EXECUTABLE_DIR:$PATH"
autodetect_system_path_with_git_before_usr_bin
export PATH="$DKML_SYSTEM_PATH"

# Returns 1 if one or more packages is missing.
_idempotent_confirm_pkg_exist() {
    # All the packages must exist. Opam can remove many packages when there is
    # a package upgrade (or re-install) followed by a build failure.
    _idempotent_confirm_pkg_exist_LIB=$1
    shift
    _idempotent_confirm_pkg_exist_PKG=$1
    shift
    # META existence is a speedy check, with some false positives, that a package is not present
    if [ ! -e "$_idempotent_confirm_pkg_exist_LIB/$_idempotent_confirm_pkg_exist_PKG/META" ]; then
        # Foolproof slow check that a package is not present
        if ! $OPAM_EXE show "$_idempotent_confirm_pkg_exist_PKG" --readonly --list-files >/dev/null 2>/dev/null; then
            echo "Rebuilding missing package [$_idempotent_confirm_pkg_exist_PKG]" >&2
            return 1
        fi
    fi
    return 0
}

# [idempotent_opam_local_install name salt absdir ./pkg1.opam ./pkg2.opam ...]
# conditionally executes `opam install ./pkg1.opam ./pkg2.opam ...`
# in the absolute directory <absdir>.
#
# On exit, the directory is restored to whatever it was on entry.
#
# If either of the following conditions are true, the installation will execute:
# 1. The [name] has not been used before.
# 2. The last time [name] was used _either_ the git commit id of [absdir]
#    was different, or the [salt] was different
idempotent_opam_local_install() {
    idempotent_opam_local_install_NAME=$1; shift
    idempotent_opam_local_install_SALT=$1; shift
    idempotent_opam_local_install_COMMITSOURCE_DIR=$1; shift
    idempotent_opam_local_install_IDEMPOTENT_ID=${idempotent_opam_local_install_SALT}$(git -C "$idempotent_opam_local_install_COMMITSOURCE_DIR" rev-parse --quiet --verify HEAD)
    idempotent_opam_local_install_LASTGITREFFILE="$UPSERT_BINARY_DIR/$idempotent_opam_local_install_NAME.installed.gitref"
    idempotent_opam_local_install_REBUILD=1
    if [ -e "$idempotent_opam_local_install_LASTGITREFFILE" ]; then
        idempotent_opam_local_install_LASTGITREF=$(cat "$idempotent_opam_local_install_LASTGITREFFILE")
        if [ "$idempotent_opam_local_install_LASTGITREF" = "$idempotent_opam_local_install_IDEMPOTENT_ID" ]; then
            # All the packages must exist. Opam can remove many packages when there is
            # a package upgrade (or re-install) followed by a build failure.
            idempotent_opam_local_install_LIB=$($OPAM_EXE var lib)
            idempotent_opam_local_install_REBUILD=0
            for idempotent_opam_local_install_OPAMFILE in "$@"; do
                idempotent_opam_local_install_PKG=$(basename "$idempotent_opam_local_install_OPAMFILE")
                idempotent_opam_local_install_PKG=$(printf "%s" "$idempotent_opam_local_install_PKG" | sed 's/[.].*//')
                if ! _idempotent_confirm_pkg_exist "$idempotent_opam_local_install_LIB" "$idempotent_opam_local_install_PKG"; then
                    idempotent_opam_local_install_REBUILD=1
                    break
                fi
            done
        fi
    fi
    if [ $idempotent_opam_local_install_REBUILD -eq 1 ]; then
        idempotent_opam_local_install_ENTRYDIR=$(pwd)
        # - [cd ..._SOURCE_DIR ; opam install ./x.opam] is required because opam 2.2 prereleases say:
        #   "Invalid character in package name" when opam install Z:/x/y/z/a.opam
        cd "$idempotent_opam_local_install_COMMITSOURCE_DIR" || exit 67
        '@WITH_COMPILER_SH@' "$OPAM_EXE" install "$@" --ignore-pin-depends --yes
        cd "$idempotent_opam_local_install_ENTRYDIR" || exit 67

        printf "%s" "$idempotent_opam_local_install_IDEMPOTENT_ID" > "$idempotent_opam_local_install_LASTGITREFFILE"
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
    idempotent_opam_install_SALT=$1; shift
    idempotent_opam_install_IDEMPOTENT_ID="${idempotent_opam_install_SALT}$*"
    idempotent_opam_install_LAST_ID_FILE="$UPSERT_BINARY_DIR/$idempotent_opam_install_NAME.installed.id"
    idempotent_opam_install_REBUILD=1
    if [ -e "$idempotent_opam_install_LAST_ID_FILE" ]; then
        idempotent_opam_install_LAST_ID=$(cat "$idempotent_opam_install_LAST_ID_FILE")
        if [ "$idempotent_opam_install_LAST_ID" = "$idempotent_opam_install_IDEMPOTENT_ID" ]; then
            # All the packages must exist. Opam can remove many packages when there is
            # a package upgrade (or re-install) followed by a build failure.
            idempotent_opam_install_LIB=$($OPAM_EXE var lib)
            idempotent_opam_install_REBUILD=0
            for idempotent_opam_install_PKGVER in "$@"; do
                idempotent_opam_install_PKG=$(printf "%s" "$idempotent_opam_install_PKGVER" | sed 's/[.].*//')
                if ! _idempotent_confirm_pkg_exist "$idempotent_opam_install_LIB" "$idempotent_opam_install_PKG"; then
                    idempotent_opam_install_REBUILD=1
                    break
                fi
            done
        fi
    fi
    if [ $idempotent_opam_install_REBUILD -eq 1 ]; then
        '@WITH_COMPILER_SH@' "$OPAM_EXE" install "$@" --yes
        printf "%s" "$idempotent_opam_install_IDEMPOTENT_ID" > "$idempotent_opam_install_LAST_ID_FILE"
    fi
}
