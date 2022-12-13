#!/bin/bash
set -euf

# Really only needed for MSYS2 if we are calling from a MSYS2/usr/bin/make.exe rather than a full shell
export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$PATH"

CONTRIBDIR=$(pwd)
DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/.." && pwd)

# Which vendor/<dir> should be version synced with this
SYNCED_PRERELEASE_BEFORE_APPS=(dkml-compiler drc drd)
SYNCED_PRERELEASE_AFTER_APPS=(diskuv-opam-repository)
SYNCED_PRERELEASE_VENDORS=("${SYNCED_PRERELEASE_BEFORE_APPS[@]}" "${SYNCED_PRERELEASE_AFTER_APPS[@]}")
SYNCED_RELEASE_VENDORS=()
set +u # workaround bash 'unbound variable' triggered on empty arrays
ALL_VENDORS=(
    "${SYNCED_PRERELEASE_VENDORS[@]}"
    "${SYNCED_RELEASE_VENDORS[@]}"    
)
set -u
# Which non-vendored Git projects should be synced
GITURLS=(
    https://github.com/diskuv/dkml-workflows-prerelease.git
    https://github.com/diskuv/dkml-installer-ocaml.git
    https://github.com/diskuv/dkml-runtime-apps.git
    https://github.com/diskuv/dkml-component-opam.git
    https://github.com/diskuv/dkml-component-ocamlrun.git
    https://github.com/diskuv/dkml-component-ocamlcompiler.git
)
# Which GITURLs are synced with bump2version
SYNCED_RELEASE_GITDIRS=(dkml-installer-ocaml)

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    release.sh -h  Display this help message." >&2
    echo "    release.sh -p  Create a prerelease." >&2
    echo "    release.sh     Create a release." >&2
    printf "Options:\n" >&2
    printf "  -f: Force tags to be recreated\n" >&2
    printf "  -q: Quick mode. Creates a 'new' version of the OCaml Opam Repository that is a copy of the last version.\n" >&2
    printf "      After GitLab CI rebuilds the repository, the new version will be updated with the rebuilt contents.\n" >&2
    printf "      Without the quick mode, only one revision of the new version (the rebuilt contents) will be made.\n" >&2
}

PRERELEASE=OFF
QUICK=OFF
FORCE=OFF
while getopts ":hpfq" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p ) PRERELEASE=ON ;;
        q ) QUICK=ON ;;
        f ) FORCE=ON ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

# END Command line processing
# ------------------

if which glab.exe >/dev/null 2>&1; then
    GLAB=glab.exe
else
    GLAB=glab
fi

# For release-cli
# shellcheck disable=SC2155
export GITLAB_PRIVATE_TOKEN=$($GLAB auth status -t 2>&1 | awk '$2=="Token:" {print $3}')

# Git, especially through bump2version, needs HOME set for Windows
if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then HOME="$USERPROFILE"; fi

# Source dirs of git clones
SRC="$DKMLDIR/_build/src"
if [ -x /usr/bin/cygpath ]; then
    SRC_MIXED=$(/usr/bin/cygpath -m "$SRC")
else
    SRC_MIXED="$SRC"
fi
install -d "$SRC"

# Work directory
WORK=$(PATH=/usr/bin:/bin mktemp -d "$DKMLDIR"/_build/release.XXXXX)
trap 'PATH=/usr/bin:/bin rm -rf "$WORK"' EXIT

# Opam switch
OPAMSWITCH="$CONTRIBDIR"
if [ -x /usr/bin/cygpath ]; then
    OPAMSWITCH=$(/usr/bin/cygpath -aw "$OPAMSWITCH")
fi
export OPAMSWITCH

cd "$DKMLDIR"

# Load cross platform functions
#   shellcheck disable=SC1091
. "vendor/drc/unix/crossplatform-functions.sh"

# ------------------------
# Commits and tags
# ------------------------

# [sed_replace COMMAND FILE] is like the GNU extension [sed -i COMMAND FILE]
# that runs and saves the sed commands in-place in FILE. It also errors
# if no replacements were performed.
sed_replace() {
    sed_replace_COMMAND=$1
    shift
    sed_replace_FILE=$1
    shift
    sed "$sed_replace_COMMAND" "$sed_replace_FILE" > "$sed_replace_FILE".$$
    if cmp -s "$sed_replace_FILE".$$ "$sed_replace_FILE"; then
        printf "ERROR: No replacements found in %s with the sed expression: %s\n" \
            "$sed_replace_FILE" "$sed_replace_COMMAND" >&2
        return 1
    fi
    mv "$sed_replace_FILE".$$ "$sed_replace_FILE"
    chmod +x "$sed_replace_FILE"
}
gitdir() {
    gitdir_URL=$1
    gitdir_DIR=$(basename "$gitdir_URL")
    printf "%s" "$gitdir_DIR" | sed 's#.git$##'
}
opam_source_block() {
    opam_source_block_TYPE=$1
    shift
    opam_source_block_VER=$1
    shift
    opam_source_block_PKG=$1
    shift
    opam_source_block_FILE=$1
    shift

    log_trace "$DKMLSYS_CURL" -L "https://github.com/diskuv/$opam_source_block_PKG/archive/refs/tags/$opam_source_block_VER.tar.gz" -o "$WORK/a.tar.gz"
    log_trace tar tfz "$WORK/a.tar.gz" # make sure we have a valid download
    opam_source_block_CKSUM=$(sha256compute "$WORK/a.tar.gz")

    {
        if [ "$opam_source_block_TYPE" = url ]; then
            printf "url {\n"
        else
            printf "%s \"%s\" {\n" "$opam_source_block_TYPE" "dl/$opam_source_block_PKG.tar.gz"
        fi
        printf "  src: \"%s\"\n" "https://github.com/diskuv/$opam_source_block_PKG/archive/refs/tags/$opam_source_block_VER.tar.gz"
        printf "%s\n" '  checksum: ['
        printf "    \"sha256=%s\"\n" "$opam_source_block_CKSUM"
        printf "%s\n" '  ]'
        printf "%s\n" '}'
    } > "$opam_source_block_FILE"
}
remove_opam_extra_source() {
    remove_opam_extra_source_PKG=$1
    shift
    awk '/^extra-source "dl\/'"$remove_opam_extra_source_PKG"'.tar.gz"/ {got=1}   !got {print}   got==1 && /^}$/ {got=0}'
}
# When using an `opam` file directly from a repository, the `url { ... }` block will be removed
remove_opam_url_source() {
    awk '/^url {/ {got=1}   !got {print}   got==1 && /^}$/ {got=0}'
}
# When using a `xxx.opam` file from a project (perhaps generated by a `dune-project`), remove
# all fields that don't belong in a Opam repository `opam` file.
# - `name` and `version` are removed since those are implied from the Opam repository 
# directory structure
remove_opam_nonrepo_fields() {
    awk '!/^# This file is generated by dune/ && $1 != "name:" && $1 != "version:" {print}'
}
rungit() {
    if [ -n "${COMSPEC:-}" ]; then
        HOME="$USERPROFILE" git "$@"
    else
        git "$@"
    fi
}
update_pkgs_version() {
    update_pkgs_version_VER=$1
    shift
    update_pkgs_version_FILE=$1
    shift
    sed_replace 's#^dkml-apps\..*#dkml-apps.'"$update_pkgs_version_VER"'#' "$update_pkgs_version_FILE"
    sed_replace 's#^opam-dkml\..*#opam-dkml.'"$update_pkgs_version_VER"'#' "$update_pkgs_version_FILE"
    sed_replace 's#^with-dkml\..*#with-dkml.'"$update_pkgs_version_VER"'#' "$update_pkgs_version_FILE"
}
update_switch_version() {
    update_switch_version_VER=$1
    shift
    update_switch_version_FILE=$1
    shift
    #   We do not use \b word boundary regex since \b does not
    #   include SPACE (ASCII 32) + letter on macOS while GNU sed does.
    sed_replace 's#^\([ ]*\)dkml-apps,.*#\1dkml-apps,'"$update_switch_version_VER"'#' "$update_switch_version_FILE"
    sed_replace 's#^\([ ]*\)opam-dkml,.*#\1opam-dkml,'"$update_switch_version_VER"'#' "$update_switch_version_FILE"
    sed_replace 's#^\([ ]*\)with-dkml,.*#\1with-dkml,'"$update_switch_version_VER"'#' "$update_switch_version_FILE"
}
update_opam_version() {
    update_opam_version_VER=$1
    shift
    update_opam_version_FILE=$1
    shift
    sed_replace 's#^version: .*#version: "'"$update_opam_version_VER"'"#' "$update_opam_version_FILE"
}
update_dkmlbasecompiler_version() {
    update_dkmlbasecompiler_version_VER=$1
    shift
    update_dkmlbasecompiler_version_FILE=$1
    shift
    # ex. version: "4.12.1~v1.0.2~prerel9"
    sed_replace 's#^version: "\([0-9.]*\)~v.*"#version: "\1~v'"$update_dkmlbasecompiler_version_VER"'"#' "$update_dkmlbasecompiler_version_FILE"
    # ex. "dkml-runtime-common-native" {= "1.0.1"}
    # ex. "dkml-runtime-common-native" {>= "1.0.1"}
    # note: the * operator (0-inf) works in basic (non-extended) sed, unlike the ? operator (0-1).
    sed_replace 's#^\([ ]*\)"dkml-runtime-common-native" {>*= ".*"}#\1"dkml-runtime-common-native" {= "'"$update_dkmlbasecompiler_version_VER"'"}#' "$update_dkmlbasecompiler_version_FILE"
}
update_dune_version() {
    update_dune_version_VER=$1
    shift
    update_dune_version_FILE=$1
    shift
    sed_replace 's#^(version .*)#(version '"$update_dune_version_VER"')#' "$update_dune_version_FILE"
}
# Checkout main branches of vendored directories. If `git submodule` shows
# the submodules are tracking a detached HEAD or other branch, our release
# procedure will not be able to see the commits from the submodules with
# `git commit -a`.
update_submodules_to_main() {
    git submodule update --init
    for v in "${ALL_VENDORS[@]}"; do
        git -C vendor/"$v" pull --ff-only origin main
        git -C vendor/"$v" switch main
    done
}

# Use main branches of vendored dirs.
update_submodules_to_main

# Checkout or update non-vendored Git URLs
#   dkml-workflows-prerelease.git: v1 branch
WORKFLOWS_PRERELEASE_BRANCH=v1
for GITURL in "${GITURLS[@]}"; do
    GITRELDIR=$(gitdir "$GITURL")
    GITDIR=$SRC_MIXED/$GITRELDIR
    if [ -d "$GITDIR" ]; then
        git -C "$GITDIR" clean -d -x -f
        git -C "$GITDIR" fetch
        case "$GITRELDIR" in
            dkml-workflows-prerelease)
                git -C "$GITDIR" switch --discard-changes "$WORKFLOWS_PRERELEASE_BRANCH"
                git -C "$GITDIR" reset --hard "origin/$WORKFLOWS_PRERELEASE_BRANCH"
                ;;
            *)
                git -C "$GITDIR" switch --discard-changes main
                git -C "$GITDIR" reset --hard origin/main
        esac
        git -C "$GITDIR" pull --ff-only
    else
        git -C "$SRC_MIXED" clone "$GITURL"
    fi
done

# Capture which version will be the release version when the prereleases are finished
TARGET_VERSION=$(awk '$1=="current_version"{print $NF; exit 0}' .bumpversion.prerelease.cfg | sed 's/[-+].*//')
get_new_version() {
    NEW_VERSION=$(awk '$1=="current_version"{print $NF; exit 0}' .bumpversion.prerelease.cfg)
    OPAM_NEW_VERSION=$(printf "%s" "$NEW_VERSION" | tr -d v | tr - '~')
}
get_new_version
CURRENT_VERSION=$NEW_VERSION
DKMLAPPS_OLDOPAM="$SRC_MIXED/dkml-runtime-apps/dkml-apps.opam"
DKMLRUNTIMESCRIPTS_OLDOPAM="$SRC_MIXED/dkml-runtime-apps/dkml-runtimescripts.opam"
DKMLRUNTIMELIB_OLDOPAM="$SRC_MIXED/dkml-runtime-apps/dkml-runtimelib.opam"
OPAMDKML_OLDOPAM="$SRC_MIXED/dkml-runtime-apps/opam-dkml.opam"
WITHDKML_OLDOPAM="$SRC_MIXED/dkml-runtime-apps/with-dkml.opam"
DKMLRUNTIMECOMMONNATIVE_OLDOPAM="vendor/drc/dkml-runtime-common-native.opam"
DKMLRUNTIMECOMMON_OLDOPAM="vendor/drc/dkml-runtime-common.opam"
DKMLRUNTIMEDISTRIBUTION_OLDOPAM="vendor/drd/dkml-runtime-distribution.opam"
DKMLBASECOMPILER_OLDOPAM="vendor/dkml-compiler/dkml-base-compiler.opam"
DKMLCOMPILERENV_OLDOPAM="vendor/dkml-compiler/dkml-base-compiler.opam"
#   validate
OLDOPAM_ARR=(
    "$DKMLAPPS_OLDOPAM"
    "$DKMLRUNTIMESCRIPTS_OLDOPAM"
    "$DKMLRUNTIMELIB_OLDOPAM"
    "$OPAMDKML_OLDOPAM"
    "$WITHDKML_OLDOPAM"
    "$DKMLRUNTIMECOMMONNATIVE_OLDOPAM"
    "$DKMLRUNTIMECOMMON_OLDOPAM"
    "$DKMLRUNTIMEDISTRIBUTION_OLDOPAM"
    "$DKMLBASECOMPILER_OLDOPAM"
    "$DKMLCOMPILERENV_OLDOPAM"
)
for oldopam_item in "${OLDOPAM_ARR[@]}"; do
    if [ ! -e "$oldopam_item" ]; then
        printf "FATAL: Could not find %s\n" "$oldopam_item" >&2
        exit 1
    fi
done

# Do release commits
autodetect_system_binaries # find DKMLSYS_CURL
update_dkmlcompiler_src() {
    update_opam_version "$OPAM_NEW_VERSION" vendor/dkml-compiler/dkml-compiler-env.opam
    update_dkmlbasecompiler_version "$OPAM_NEW_VERSION" vendor/dkml-compiler/dkml-base-compiler.opam
}
update_drc_src() {
    #   Update META and .opam
    update_opam_version "$OPAM_NEW_VERSION" vendor/drc/dkml-runtime-common.opam
    update_opam_version "$OPAM_NEW_VERSION" vendor/drc/dkml-runtime-common-native.opam
    sed_replace 's#^version *= *".*"#version = "'"$OPAM_NEW_VERSION"'"#' vendor/drc/META
}
update_drd_src() {
    #   Update ci-pkgs.txt, create-opam-switch.sh, dune-project and .opam
    update_pkgs_version "$OPAM_NEW_VERSION" vendor/drd/src/none/ci-pkgs.txt
    update_switch_version "$OPAM_NEW_VERSION" vendor/drd/src/unix/create-opam-switch.sh
    update_dune_version "$OPAM_NEW_VERSION" vendor/drd/dune-project
    update_opam_version "$OPAM_NEW_VERSION" vendor/drd/dkml-runtime-distribution.opam
}
if [ "$PRERELEASE" = ON ]; then
    # Increment the prerelease

    # 1. Bump everything, including vendored submodules, but do not commit
    bump2version prerelease \
        --config-file .bumpversion.prerelease.cfg \
        --verbose
    get_new_version
    #   Update dkml-compiler/, drc/ and drd/
    update_dkmlcompiler_src
    update_drc_src
    update_drd_src
    #   the prior bump2version checked if the Git working directory was clean, so this is safe
    for v in "${SYNCED_PRERELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" add -A
    done
    git add -A

    # 2. Make a prerelease commit
    for v in "${SYNCED_PRERELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" commit -m "Bump version: $CURRENT_VERSION → $NEW_VERSION"
    done
	git commit -m "Bump version: $CURRENT_VERSION → $NEW_VERSION" -a
else
    # We are doing a target release, not a prerelease ...

    # 1. There are a couple files that should have a "stable" link that only change when the release is
    # finished rather than every prerelease. We change those here.
    bump2version major \
        --config-file .bumpversion.release.cfg \
        --new-version "$TARGET_VERSION" \
        --verbose
    #   the prior bump2version checked if the Git working directory was clean, so this is safe
    set +u # workaround bash 'unbound variable' triggered on empty arrays
    for v in "${SYNCED_RELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" add -A
    done
    set -u
    #   the newly checked-out / resetted Git URLs are also safe
    for GITDIR in "${SYNCED_RELEASE_GITDIRS[@]}"; do
        GITDIR="$SRC_MIXED/$GITDIR"
        git -C "$GITDIR" add -A
    done
    git add -A

    # 2. Assemble the change log
    RELEASEDATE=$(date +%Y-%m-%d)
    sed "s/@@YYYYMMDD@@/$RELEASEDATE/" "contributors/changes/v$TARGET_VERSION.md" > /tmp/v.md
    mv /tmp/v.md "contributors/changes/v$TARGET_VERSION.md"
    cp CHANGES.md /tmp/
    cp "contributors/changes/v$TARGET_VERSION.md" CHANGES.md
	echo >> CHANGES.md
    cat /tmp/CHANGES.md >> CHANGES.md
    git add CHANGES.md "contributors/changes/v$TARGET_VERSION.md"

    # 3. Make a release commit
    set +u # workaround bash 'unbound variable' triggered on empty arrays
    for v in "${SYNCED_RELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" commit -m "Finish v$TARGET_VERSION release (1 of 2)"
        git add vendor/"$v"
    done
    set -u
    for GITDIR in "${SYNCED_RELEASE_GITDIRS[@]}"; do
        GITDIR=$SRC_MIXED/"$GITDIR"
        git -C "$GITDIR" commit -m "Finish v$TARGET_VERSION release"
    done
	git commit -m "Finish v$TARGET_VERSION release (1 of 2)"

    # Increment the change which will clear the _prerelease_ state
	bump2version change \
        --config-file .bumpversion.prerelease.cfg \
        --new-version "$TARGET_VERSION" \
        --verbose
    get_new_version
    #   Safety check version for a release. Calculate final versions
    if [ ! "$NEW_VERSION" = "$TARGET_VERSION" ]; then
        echo "The target version $TARGET_VERSION and the new version $NEW_VERSION did not match" >&2
        exit 1
    fi
    #   Update dkml-compiler/, drc/ and drd/
    update_dkmlcompiler_src
    update_drc_src
    update_drd_src
    #   Commit
    for v in "${SYNCED_PRERELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" commit -m "Finish $NEW_VERSION release (2 of 2)" -a
        git add vendor/"$v"
    done
    git commit -m "Finish $NEW_VERSION release (2 of 2)"
fi

# From this point on NEW_VERSION is the version being committed. It will be
# different from TARGET_VERSION if we are currently doing a prerelease.

# Tag and push before dkml-runtime-apps
for v in "${SYNCED_PRERELEASE_BEFORE_APPS[@]}"; do
    if [ "$FORCE" = "ON" ]; then
        git -C vendor/"$v" tag -d "$NEW_VERSION" || true
        git -C vendor/"$v" push --delete origin "$NEW_VERSION" || true
    fi
    git -C vendor/"$v" tag -a "$NEW_VERSION" -m "$OPAM_NEW_VERSION"
    git -C vendor/"$v" push --atomic origin main "$NEW_VERSION"
done

# Update, tag and push dkml-runtime-apps (and components and opam-repository)
#   Calculate new extra-source blocks; wait 5 seconds to make sure
#   dkml-runtime-common|distribution GitHub tarballs are eventually consistent
sleep 5
opam_source_block extra-source "$NEW_VERSION" dkml-runtime-common       "$WORK/dkml-runtime-common.extra-source"
opam_source_block extra-source "$NEW_VERSION" dkml-runtime-distribution "$WORK/dkml-runtime-distribution.extra-source"
opam_source_block url "$NEW_VERSION" dkml-runtime-common       "$WORK/dkml-runtime-common.url"
opam_source_block url "$NEW_VERSION" dkml-runtime-distribution "$WORK/dkml-runtime-distribution.url"
opam_source_block url "$NEW_VERSION" dkml-compiler             "$WORK/dkml-compiler.url"
#   Update and push dkml-runtime-apps which is used by diskuv-opam-repository
update_opam_version "$OPAM_NEW_VERSION" "$SRC_MIXED/dkml-runtime-apps/dkml-apps.opam"
update_opam_version "$OPAM_NEW_VERSION" "$SRC_MIXED/dkml-runtime-apps/dkml-runtimelib.opam"
update_opam_version "$OPAM_NEW_VERSION" "$SRC_MIXED/dkml-runtime-apps/dkml-runtimescripts.opam"
update_opam_version "$OPAM_NEW_VERSION" "$SRC_MIXED/dkml-runtime-apps/opam-dkml.opam"
update_opam_version "$OPAM_NEW_VERSION" "$SRC_MIXED/dkml-runtime-apps/with-dkml.opam"
update_dune_version "$OPAM_NEW_VERSION" "$SRC_MIXED/dkml-runtime-apps/dune-project"
rungit -C "$SRC_MIXED/dkml-runtime-apps" commit -a -m "Bump version: $CURRENT_VERSION → $NEW_VERSION"
if [ "$FORCE" = "ON" ]; then
    rungit -C "$SRC_MIXED/dkml-runtime-apps" tag -d "$NEW_VERSION" || true
    rungit -C "$SRC_MIXED/dkml-runtime-apps" push --delete origin "$NEW_VERSION" || true
fi
rungit -C "$SRC_MIXED/dkml-runtime-apps" tag -a "$NEW_VERSION" -m "$OPAM_NEW_VERSION"
rungit -C "$SRC_MIXED/dkml-runtime-apps" push --atomic origin main "$NEW_VERSION"
#   Calculate new extra-source blocks; wait 5 seconds to make sure
#   dkml-runtime-apps GitHub tarball is eventually consistent
sleep 5
opam_source_block url "$NEW_VERSION" dkml-runtime-apps "$WORK/dkml-runtime-apps.url"
#   Update diskuv-opam-repository
new_opam_package_version() {
    new_opam_package_version_URL=$1
    shift
    new_opam_package_version_OLD=$1
    shift
    new_opam_package_version_NEW=$1
    shift
    new_opam_package_version_DIR=$(dirname "vendor/diskuv-opam-repository/$new_opam_package_version_NEW")
    install -d "$new_opam_package_version_DIR"
    #       shellcheck disable=SC2002
    cat "$new_opam_package_version_OLD" | \
        remove_opam_url_source | \
        remove_opam_nonrepo_fields | \
        cat - "$WORK/$new_opam_package_version_URL.url" > \
        "vendor/diskuv-opam-repository/$new_opam_package_version_NEW".tmp
    mv "vendor/diskuv-opam-repository/$new_opam_package_version_NEW".tmp "vendor/diskuv-opam-repository/$new_opam_package_version_NEW"
    rungit -C "vendor/diskuv-opam-repository" add "$new_opam_package_version_NEW"
}
new_opam_package_version dkml-runtime-apps "$DKMLAPPS_OLDOPAM" "packages/dkml-apps/dkml-apps.$OPAM_NEW_VERSION/opam"
new_opam_package_version dkml-runtime-apps "$DKMLRUNTIMESCRIPTS_OLDOPAM" "packages/dkml-runtimescripts/dkml-runtimescripts.$OPAM_NEW_VERSION/opam"
new_opam_package_version dkml-runtime-apps "$DKMLRUNTIMELIB_OLDOPAM" "packages/dkml-runtimelib/dkml-runtimelib.$OPAM_NEW_VERSION/opam"
new_opam_package_version dkml-runtime-apps "$OPAMDKML_OLDOPAM" "packages/opam-dkml/opam-dkml.$OPAM_NEW_VERSION/opam"
new_opam_package_version dkml-runtime-apps "$WITHDKML_OLDOPAM" "packages/with-dkml/with-dkml.$OPAM_NEW_VERSION/opam"

new_opam_package_version dkml-runtime-common "$DKMLRUNTIMECOMMONNATIVE_OLDOPAM" "packages/dkml-runtime-common-native/dkml-runtime-common-native.$OPAM_NEW_VERSION/opam"
new_opam_package_version dkml-runtime-common "$DKMLRUNTIMECOMMON_OLDOPAM" "packages/dkml-runtime-common/dkml-runtime-common.$OPAM_NEW_VERSION/opam"
new_opam_package_version dkml-runtime-distribution "$DKMLRUNTIMEDISTRIBUTION_OLDOPAM" "packages/dkml-runtime-distribution/dkml-runtime-distribution.$OPAM_NEW_VERSION/opam"

#   nit: today we support 4.12.1. There should only be one opam file even when we introduce 4.13.1 and/or multiple other versions!
#   Instead the logic inside the build:[] commands should parse the opam version (ex. POSIX case/esac statements) and fork the
#   behavior if it needs to. That way we can always submit several versions at once to the repository, and bug fixes are applied
#   to historical version, and running 'opam install ./dkml-base-compiler.opam' inside dkml-compiler/ just works.
new_opam_package_version dkml-compiler "$DKMLBASECOMPILER_OLDOPAM" "packages/dkml-base-compiler/dkml-base-compiler.4.12.1~v$OPAM_NEW_VERSION/opam"
new_opam_package_version dkml-compiler "$DKMLCOMPILERENV_OLDOPAM" "packages/dkml-compiler-env/dkml-compiler-env.$OPAM_NEW_VERSION/opam"

rungit -C "vendor/diskuv-opam-repository" commit -m "dkml $OPAM_NEW_VERSION"

# Tag and push after dkml-runtime-apps
for v in "${SYNCED_PRERELEASE_AFTER_APPS[@]}"; do
    if [ "$FORCE" = "ON" ]; then
        rungit -C vendor/"$v" tag -d "$NEW_VERSION" || true
        rungit -C vendor/"$v" push --delete origin "$NEW_VERSION" || true
    fi
    rungit -C vendor/"$v" tag -a "$NEW_VERSION" -m "$OPAM_NEW_VERSION"
    rungit -C vendor/"$v" push --atomic origin main "$NEW_VERSION"
done
update_submodules_to_main
rungit commit -a -m "Update dependencies to $NEW_VERSION"
if [ "$FORCE" = "ON" ]; then
    rungit tag -d "$NEW_VERSION" || true
    rungit push --delete origin "$NEW_VERSION" || true
fi
rungit tag -a "$NEW_VERSION" -m "$OPAM_NEW_VERSION"
# do not use: git push --atomic origin main "$NEW_VERSION"
# because we can't be on 'next' branch
rungit push
rungit push origin "$NEW_VERSION"

# Update and push dkml-workflows-prerelease
DOR=$(rungit -C "vendor/diskuv-opam-repository" rev-parse HEAD)
sed_replace "s/DEFAULT_DISKUV_OPAM_REPOSITORY_TAG=[a-f0-9]*$/DEFAULT_DISKUV_OPAM_REPOSITORY_TAG=$DOR/" "$SRC_MIXED/dkml-workflows-prerelease/src/scripts/setup-dkml.sh"
sed_replace 's#"PIN_DKML_APPS", *"[^"]*"#"PIN_DKML_APPS", "'"$OPAM_NEW_VERSION"'"#' "$SRC_MIXED/dkml-workflows-prerelease/src/logic/model.ml"
sed_replace 's#"PIN_WITH_DKML", *"[^"]*"#"PIN_WITH_DKML", "'"$OPAM_NEW_VERSION"'"#' "$SRC_MIXED/dkml-workflows-prerelease/src/logic/model.ml"
rungit -C "$SRC_MIXED/dkml-workflows-prerelease" add src/scripts/setup-dkml.sh src/logic/model.ml
rungit -C "$SRC_MIXED/dkml-workflows-prerelease" commit -m "Bump diskuv-opam-repository and dkml-apps"
rungit -C "$SRC_MIXED/dkml-workflows-prerelease" push origin "$WORKFLOWS_PRERELEASE_BRANCH"

# ------------------------
# Distribution archive
# ------------------------

# Remove git ignored files from submodules for distribution archive. ARCHIVE_MEMBERS
# is already a good filter for this repository (diskuv-ocaml), and we do not clean it
# because we may blow away IDE settings and other build information.
for v in "${ALL_VENDORS[@]}"; do
    git -C vendor/"$v" clean -x -d -f
    rm -rf vendor/"$v"/_opam
done

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='diskuv%2Fdiskuv-ocaml' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/
GLOBAL_OPTS=(--server-url "$CI_SERVER_URL" --project-id "$CI_PROJECT_ID")
CREATE_OPTS=(
    --tag-name "$NEW_VERSION"
)
if [ "$PRERELEASE" = OFF ]; then
    CREATE_OPTS+=(
        --name "Version $NEW_VERSION"
        --description "contributors/changes/v$NEW_VERSION.md"
    )
else
    CREATE_OPTS+=(
        --name "$NEW_VERSION (alpha prerelease of $TARGET_VERSION)"
    )
fi
if [ -e /usr/ssl/cert.pem ]; then
    # Really only needed for MSYS2 if we are calling from a MSYS2/usr/bin/make.exe rather than a full shell
    cp /usr/ssl/cert.pem contributors/_build/
    GLOBAL_OPTS+=(--additional-ca-cert-bundle contributors/_build/cert.pem)
fi
if false; then
    # need Premium GitLab for this, and the milestone probably needs to exist already
    CREATE_OPTS+=(--milestone "v$TARGET_VERSION")
fi

# ------------------------
# GitLab Release
# ------------------------

# Setup Generic Packages (https://docs.gitlab.com/ee/user/packages/generic_packages/)
PACKAGE_REGISTRY_GENERIC_URL="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"
SUPPORT_NEWURL="$PACKAGE_REGISTRY_GENERIC_URL/ocaml_opam_repo-support/$NEW_VERSION"
OOREPO_NEWURL="$PACKAGE_REGISTRY_GENERIC_URL/ocaml_opam_repo-reproducible/$NEW_VERSION"
OOREPO_OLDURL="$PACKAGE_REGISTRY_GENERIC_URL/ocaml_opam_repo-reproducible/$CURRENT_VERSION"
OCAMLVERS=(4.13.1 4.12.1)
#GITLAB_TARGET_VERSION=$(printf "%s" "$TARGET_VERSION" | tr +- ..) # replace -prerelM and +commitN with .prerelM and .commitN

# Re-upload files from Generic Packages

if [ "$QUICK" = ON ]; then
    for OCAMLVER in "${OCAMLVERS[@]}"; do
        for OOREPO_BASENAME in "ocaml-opam-repo-$OCAMLVER.tar.gz" "ocaml-opam-repo-$OCAMLVER.zip"; do
            # download old
            curl -L -o "contributors/_build/$OOREPO_BASENAME" "$OOREPO_OLDURL/$OOREPO_BASENAME"
            # upload new
            curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
                --upload-file "contributors/_build/$OOREPO_BASENAME" \
                "$OOREPO_NEWURL/$OOREPO_BASENAME"
        done
    done
fi

# Build ocaml_opam_repo_trim.bc (after the vendor/drd/ is cleaned, and just before upload)
opam exec -- dune build --root vendor/drd/src/ml ocaml_opam_repo_trim.bc
DUNE_BUILDDIR=vendor/drd/src/ml/_build/default

# Upload support files to Generic Packages

curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file "$DUNE_BUILDDIR/ocaml_opam_repo_trim.bc" \
     "$SUPPORT_NEWURL/ocaml_opam_repo_trim.bc"

# Reference the Generic Packages that GitLab automatically creates
for OCAMLVER in "${OCAMLVERS[@]}"; do
    CREATE_OPTS+=(--assets-link "{\"name\":\"Vanilla OCaml $OCAMLVER for 64-bit Windows (zip) [reproducible;Apache-2.0]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/ocaml-reproducible/$NEW_VERSION/ocaml-$OCAMLVER-windows_x86_64.zip\"}")
    CREATE_OPTS+=(--assets-link "{\"name\":\"Vanilla OCaml $OCAMLVER for 32-bit Windows (zip) [reproducible;Apache-2.0]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/ocaml-reproducible/$NEW_VERSION/ocaml-$OCAMLVER-windows_x86.zip\"}")
done
for OCAMLVER in "${OCAMLVERS[@]}"; do
    CREATE_OPTS+=(--assets-link "{\"name\":\"OCaml $OCAMLVER tailored Opam repository (tar.gz) [reproducible;Apache-2.0]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/ocaml_opam_repo-reproducible/$NEW_VERSION/ocaml-opam-repo-$OCAMLVER.tar.gz\"}")
    CREATE_OPTS+=(--assets-link "{\"name\":\"OCaml $OCAMLVER tailored Opam repository (zip) [reproducible;Apache-2.0]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/ocaml_opam_repo-reproducible/$NEW_VERSION/ocaml-opam-repo-$OCAMLVER.zip\"}")
done

# Create the release
release-cli "${GLOBAL_OPTS[@]}" create "${CREATE_OPTS[@]}"

# Messaging
echo
echo
echo '1. Go to https://gitlab.com/diskuv/diskuv-ocaml/-/pipelines and make sure that the pipeline succeeds'
echo '2. Do a merge to https://github.com/diskuv/dkml-workflows.git from https://github.com/diskuv/dkml-workflows-prerelease.git'
echo
