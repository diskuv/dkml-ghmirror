#!/bin/bash
set -euf

# Really only needed for MSYS2 if we are calling from a MSYS2/usr/bin/make.exe rather than a full shell
export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$PATH"

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/.." && pwd)

# Which vendor/<dir> should be version synced with this
SYNCED_PRERELEASE_BEFORE_APPS=(drc drd)
SYNCED_PRERELEASE_AFTER_APPS=(diskuv-opam-repository)
SYNCED_PRERELEASE_VENDORS=("${SYNCED_PRERELEASE_BEFORE_APPS[@]}" "${SYNCED_PRERELEASE_AFTER_APPS[@]}")
SYNCED_RELEASE_VENDORS=(diskuv-opam-repository)
# Which non-vendored Git projects should be synced
GITURLS=(
    https://github.com/diskuv/dkml-workflows.git
    https://github.com/diskuv/dkml-installer-ocaml.git
    https://github.com/diskuv/dkml-runtime-apps.git
    https://github.com/diskuv/dkml-component-opam.git
    https://github.com/diskuv/dkml-component-ocamlrun.git
    https://github.com/diskuv/dkml-component-ocamlcompiler.git
)
OPAMPATHS=(
    dkml-component-ocamlcompiler/dkml-component-network-ocamlcompiler.opam
    dkml-component-ocamlrun/dkml-component-staging-ocamlrun.opam
    dkml-component-opam/dkml-component-staging-opam32.opam
    dkml-component-opam/dkml-component-staging-opam64.opam
    dkml-installer-ocaml/dkml-installer-network-ocaml.opam.template
    dkml-installer-ocaml/dkml-installer-network-ocaml.opam
)
# Which GITURLs are synced with bump2version
SYNCED_RELEASE_GITDIRS=(dkml-installer-ocaml)
# ex. OPAMPROJECTS=(dkml-component-opam dkml-component-ocamlrun ...)
# ignore exit code (for some reason it fails but still sets the array)
IFS=$'\n' read -r -d '' -a OPAMPROJECTS < <(for i in "${OPAMPATHS[@]}"; do dirname "$i"; done | sort -u) || true

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
install -d "$SRC"

# Work directory
WORK=$(PATH=/usr/bin:/bin mktemp -d "$DKMLDIR"/_build/release.XXXXX)
trap 'PATH=/usr/bin:/bin rm -rf "$WORK"' EXIT

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
    if cmp "$sed_replace_FILE".$$ "$sed_replace_FILE"; then
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
update_drc_drd() {
    update_drc_drd_FILE=$1
    shift
    # shellcheck disable=SC2002
    cat "$update_drc_drd_FILE" | \
        remove_opam_extra_source dkml-runtime-common | \
        remove_opam_extra_source dkml-runtime-distribution | \
        cat - "$WORK/dkml-runtime-common.extra-source" "$WORK/dkml-runtime-distribution.extra-source" > \
        "$update_drc_drd_FILE".tmp
    mv "$update_drc_drd_FILE".tmp "$update_drc_drd_FILE"
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
}
update_opam_version() {
    update_opam_version_VER=$1
    shift
    update_opam_version_FILE=$1
    shift
    sed_replace 's#^version: .*#version: "'"$update_opam_version_VER"'"#' "$update_opam_version_FILE"
}
update_dune_version() {
    update_dune_version_VER=$1
    shift
    update_dune_version_FILE=$1
    shift
    sed_replace 's#^(version .*)#(version '"$update_dune_version_VER"')#' "$update_dune_version_FILE"
}

# Checkout or update non-vendored Git URLs
for GITURL in "${GITURLS[@]}"; do
    GITDIR=$SRC/$(gitdir "$GITURL")
    if [ -d "$GITDIR" ]; then
        git -C "$GITDIR" clean -d -x -f
        git -C "$GITDIR" reset --hard origin/main
        git -C "$GITDIR" pull --ff-only
    else
        git -C "$SRC" clone "$GITURL"
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
DKMLAPPS_OLDOPAM="$SRC/dkml-runtime-apps/dkml-apps.opam"
DKMLRUNTIME_OLDOPAM="$SRC/dkml-runtime-apps/dkml-runtime.opam"
OPAMDKML_OLDOPAM="$SRC/dkml-runtime-apps/opam-dkml.opam"

#   validate
if [ ! -e "$DKMLAPPS_OLDOPAM" ]; then
    printf "FATAL: Could not find %s\n" "$DKMLAPPS_OLDOPAM" >&2
    exit 1
fi
if [ ! -e "$DKMLRUNTIME_OLDOPAM" ]; then
    printf "FATAL: Could not find %s\n" "$DKMLRUNTIME_OLDOPAM" >&2
    exit 1
fi
if [ ! -e "$OPAMDKML_OLDOPAM" ]; then
    printf "FATAL: Could not find %s\n" "$OPAMDKML_OLDOPAM" >&2
    exit 1
fi

# Do release commits
autodetect_system_binaries # find DKMLSYS_CURL
update_drd_src() {
    #   Update ci-pkgs.txt and create-opam-switch.sh
    update_pkgs_version "$OPAM_NEW_VERSION" vendor/drd/src/none/ci-pkgs.txt
    update_switch_version "$OPAM_NEW_VERSION" vendor/drd/src/unix/create-opam-switch.sh
}
if [ "$PRERELEASE" = ON ]; then
    # Increment the prerelease

    # 1. Bump everything, including vendored submodules, but do not commit
    bump2version prerelease \
        --config-file .bumpversion.prerelease.cfg \
        --verbose
    get_new_version
    #   Update drd/src
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
    for v in "${SYNCED_RELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" add -A
    done
    #   the newly checked-out / resetted Git URLs are also safe
    for GITDIR in "${SYNCED_RELEASE_GITDIRS[@]}"; do
        GITDIR=$SRC/"$GITDIR"
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
    for v in "${SYNCED_RELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" commit -m "Finish v$TARGET_VERSION release (1 of 2)"
    done
    for GITDIR in "${SYNCED_RELEASE_GITDIRS[@]}"; do
        GITDIR=$SRC/"$GITDIR"
        git -C "$GITDIR" commit -m "Finish v$TARGET_VERSION release (1 of 2)"
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
    #   Update drd/src
    update_drd_src
    #   Commit
    for v in "${SYNCED_PRERELEASE_VENDORS[@]}"; do
        git -C vendor/"$v" commit -m "Finish v$NEW_VERSION release (2 of 2)" -a
    done
    for GITDIR in "${SYNCED_RELEASE_GITDIRS[@]}"; do
        GITDIR=$SRC/"$GITDIR"
        git -C "$GITDIR" commit -m "Finish v$NEW_VERSION release (2 of 2)" -a
    done
    git commit -m "Finish v$NEW_VERSION release (2 of 2)" -a
fi

# From this point on NEW_VERSION is the version being committed. It will be
# different from TARGET_VERSION if we are currently doing a prerelease.

# Tag and push before dkml-runtime-apps
for v in "${SYNCED_PRERELEASE_BEFORE_APPS[@]}"; do
    if [ "$FORCE" = "ON" ]; then
        git -C vendor/"$v" tag -d "v$NEW_VERSION" || true
        git -C vendor/"$v" push --delete origin "v$NEW_VERSION" || true
    fi
    git -C vendor/"$v" tag "v$NEW_VERSION"
    git -C vendor/"$v" push --atomic origin main "v$NEW_VERSION"
done

# Update, tag and push dkml-runtime-apps (and components and opam-repository)
#   Calculate new extra-source blocks; wait 5 seconds to make sure
#   dkml-runtime-common|distribution GitHub tarballs are eventually consistent
sleep 5
opam_source_block extra-source "v$NEW_VERSION" dkml-runtime-common       "$WORK/dkml-runtime-common.extra-source"
opam_source_block extra-source "v$NEW_VERSION" dkml-runtime-distribution "$WORK/dkml-runtime-distribution.extra-source"
#   Update and push dkml-runtime-apps which is used by diskuv-opam-repository
update_drc_drd "$SRC/dkml-runtime-apps/dkml-runtime.opam"
update_drc_drd "$SRC/dkml-runtime-apps/dkml-runtime.opam.template"
update_opam_version "$OPAM_NEW_VERSION" "$SRC/dkml-runtime-apps/dkml-apps.opam"
update_opam_version "$OPAM_NEW_VERSION" "$SRC/dkml-runtime-apps/dkml-runtime.opam"
update_opam_version "$OPAM_NEW_VERSION" "$SRC/dkml-runtime-apps/opam-dkml.opam"
update_dune_version "$OPAM_NEW_VERSION" "$SRC/dkml-runtime-apps/dune-project"
rungit -C "$SRC/dkml-runtime-apps" commit -a -m "Bump version: $CURRENT_VERSION → $NEW_VERSION"
if [ "$FORCE" = "ON" ]; then
    rungit -C "$SRC/dkml-runtime-apps" tag -d "v$NEW_VERSION" || true
    rungit -C "$SRC/dkml-runtime-apps" push --delete origin "v$NEW_VERSION" || true
fi
rungit -C "$SRC/dkml-runtime-apps" tag "v$NEW_VERSION"
rungit -C "$SRC/dkml-runtime-apps" push --atomic origin main "v$NEW_VERSION"
#   Update and push components. We want one commit if many components in project
for i in "${OPAMPROJECTS[@]}"; do
    COMPONENTDIR="$SRC/$i"
    for COMPONENTPATH in "${OPAMPATHS[@]}"; do
        case $COMPONENTPATH in
            $i/*)
                update_drc_drd "$SRC/$COMPONENTPATH"
                rungit -C "$COMPONENTDIR" add "$SRC/$COMPONENTPATH"
                ;;
        esac
    done
    rungit -C "$COMPONENTDIR" commit -m "dkml-runtime-{common,distribution} $NEW_VERSION"
    rungit -C "$COMPONENTDIR" push origin main
done
#   Calculate new extra-source blocks; wait 5 seconds to make sure
#   dkml-runtime-apps GitHub tarball is eventually consistent
sleep 5
opam_source_block url "v$NEW_VERSION" dkml-runtime-apps "$WORK/dkml-runtime-apps.url"
#   Update diskuv-opam-repository
new_opam_package_version() {
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
        cat - "$WORK/dkml-runtime-apps.url" > \
        "vendor/diskuv-opam-repository/$new_opam_package_version_NEW".tmp
    mv "vendor/diskuv-opam-repository/$new_opam_package_version_NEW".tmp "vendor/diskuv-opam-repository/$new_opam_package_version_NEW"
    rungit -C "vendor/diskuv-opam-repository" add "$new_opam_package_version_NEW"
}
new_opam_package_version "$DKMLAPPS_OLDOPAM" "packages/dkml-apps/dkml-apps.$OPAM_NEW_VERSION/opam"
new_opam_package_version "$DKMLRUNTIME_OLDOPAM" "packages/dkml-runtime/dkml-runtime.$OPAM_NEW_VERSION/opam"
new_opam_package_version "$OPAMDKML_OLDOPAM" "packages/opam-dkml/opam-dkml.$OPAM_NEW_VERSION/opam"
rungit -C "vendor/diskuv-opam-repository" commit -m "dkml-runtime-apps.$OPAM_NEW_VERSION"

# Tag and push after dkml-runtime-apps
for v in "${SYNCED_PRERELEASE_AFTER_APPS[@]}"; do
    if [ "$FORCE" = "ON" ]; then
        rungit -C vendor/"$v" tag -d "v$NEW_VERSION" || true
        rungit -C vendor/"$v" push --delete origin "v$NEW_VERSION" || true
    fi
    rungit -C vendor/"$v" tag "v$NEW_VERSION"
    rungit -C vendor/"$v" push --atomic origin main "v$NEW_VERSION"
done
rungit commit -a -m "Update dependencies to $NEW_VERSION"
if [ "$FORCE" = "ON" ]; then
    rungit tag -d "v$NEW_VERSION" || true
    rungit push --delete origin "v$NEW_VERSION" || true
fi
rungit tag "v$NEW_VERSION"
# do not use: git push --atomic origin main "v$NEW_VERSION"
# because we can't be on 'next' branch
rungit push
rungit push origin "v$NEW_VERSION"

# Update and push dkml-workflows
DOR=$(rungit -C "vendor/diskuv-opam-repository" rev-parse HEAD)
sed_replace "s/export DEFAULT_DISKUV_OPAM_REPOSITORY_TAG=.*/export DEFAULT_DISKUV_OPAM_REPOSITORY_TAG=$DOR/" "$SRC/dkml-workflows/.github/workflows/scripts/localdev/windows_vars.source.sh"
sed_replace "s/DEFAULT_DISKUV_OPAM_REPOSITORY_TAG: .*/DEFAULT_DISKUV_OPAM_REPOSITORY_TAG: $DOR/" "$SRC/dkml-workflows/.github/workflows/setup-dkml.yml"
rungit -C "$SRC/dkml-workflows" add .github/workflows/setup-dkml.yml .github/workflows/scripts/localdev/windows_vars.source.sh
rungit -C "$SRC/dkml-workflows" commit -m "diskuv-opam-repository#$DOR"
rungit -C "$SRC/dkml-workflows" push

# ------------------------
# Distribution archive
# ------------------------

# Define which files and directories go into distribution archive
ARCHIVE_MEMBERS=(LICENSE.txt README.md etc buildtime vendor .dkmlroot .gitattributes .gitignore)

# Make _build/distribution-portable.zip
FILE="$DKMLDIR/contributors/_build/distribution-portable.zip"
rm -f "$FILE"
install -d contributors/_build/release-zip
rm -rf contributors/_build/release-zip
install -d contributors/_build/release-zip
zip -r "$FILE" "${ARCHIVE_MEMBERS[@]}"
pushd contributors/_build/release-zip
install -d diskuv-ocaml
cd diskuv-ocaml
unzip "$FILE"
cd ..
rm -f "$FILE"
zip -r "$FILE" diskuv-ocaml
popd

# Make _build/distribution-portable.tar.gz
FILE="$DKMLDIR/contributors/_build/distribution-portable.tar.gz"
install -d contributors/_build
rm -f "$FILE"
if tar -cf contributors/_build/probe.tar --no-xattrs --owner root /dev/null >/dev/null 2>/dev/null; then GNUTAR=ON; fi # test to see if GNU tar
if [ "${GNUTAR:-}" = ON ]; then
    # GNU tar
    tar cvfz "$FILE" --owner root --group root --exclude _build --transform 's,^,diskuv-ocaml/,' --no-xattrs "${ARCHIVE_MEMBERS[@]}"
else
    # BSD tar
    tar cvfz "$FILE" -s ',^,diskuv-ocaml/,' --uname root --gname root --exclude _build --no-xattrs "${ARCHIVE_MEMBERS[@]}"
fi

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='diskuv%2Fdiskuv-ocaml' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/
GLOBAL_OPTS=(--server-url "$CI_SERVER_URL" --project-id "$CI_PROJECT_ID")
CREATE_OPTS=(
    --tag-name "v$NEW_VERSION"
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
DISTPORTABLE_NEWURL="$PACKAGE_REGISTRY_GENERIC_URL/distribution-portable/$NEW_VERSION"
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

# Upload files to Generic Packages

curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file contributors/_build/distribution-portable.zip \
     "$DISTPORTABLE_NEWURL/distribution-portable.zip"
CREATE_OPTS+=(--assets-link "{\"name\":\"Diskuv OCaml distribution (zip) [portable;FairSource-0.9]\",\"url\":\"${DISTPORTABLE_NEWURL}/distribution-portable.zip\",\"link_type\":\"package\"}")

curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file contributors/_build/distribution-portable.tar.gz \
     "$DISTPORTABLE_NEWURL/distribution-portable.tar.gz"
CREATE_OPTS+=(--assets-link "{\"name\":\"Diskuv OCaml distribution (tar.gz) [portable;FairSource-0.9]\",\"url\":\"${DISTPORTABLE_NEWURL}/distribution-portable.tar.gz\",\"link_type\":\"package\"}")

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
echo 'Go to https://gitlab.com/diskuv/diskuv-ocaml/-/pipelines and make sure that the pipeline succeeds'
echo
