#!/bin/bash
set -euf -o pipefail

# Really only needed for MSYS2 if we are calling from a MSYS2/usr/bin/make.exe rather than a full shell
export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$PATH"

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/.." && pwd)

# ------------------
# BEGIN Command line processing

function usage () {
    echo "Usage:" >&2
    echo "    release.sh -h  Display this help message." >&2
    echo "    release.sh -p  Create a prerelease." >&2
    echo "    release.sh     Create a release." >&2
    echo "Options:" >&2
    echo "       -p PLATFORM: The target platform or 'dev'" >&2
    echo "       -s: Select the 'diskuv-system' switch" >&2
    echo "       -b BUILDTYPE: Optional. The build type. If specified will create the switch" >&2
    echo "            in the build directory that corresponds to BUILDTYPE. Otherwise creates" >&2
    echo "            a global switch" >&2
}

PRERELEASE=OFF
while getopts ":h:p" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            PRERELEASE=ON
        ;;
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

cd "$DKMLDIR"

# Capture which version will be the release version when the prereleases are finished
TARGET_VERSION=$(awk '$1=="current_version"{print $NF; exit 0}' .bumpversion.prerelease.cfg | sed 's/[-+].*//')

if [[ "$PRERELEASE" = ON ]]; then
    # Increment the prerelease
    bump2version prerelease \
        --config-file .bumpversion.prerelease.cfg \
        --message 'Prerelease v{new_version}' \
        --verbose
else
    # We are doing a target release, not a prerelease ...

    # 1. There are a couple files that should have a "stable" link that only change when the release is
    # finished rather than every prerelease. We change those here.
    bump2version major \
        --config-file .bumpversion.release.cfg \
        --new-version "$TARGET_VERSION" \
        --verbose
    git add -A # the prior bump2version checked if the Git working directory was clean, so this is safe

    # 2. Assemble the change log
    RELEASEDATE=$(date +%Y-%m-%d)
	sed -i "s/@@YYYYMMDD@@/$RELEASEDATE/" "contributors/changes/v$TARGET_VERSION.md"
	echo >> CHANGES.md && cat "contributors/changes/v$TARGET_VERSION.md" >> CHANGES.md
    git add CHANGES.md "contributors/changes/v$TARGET_VERSION.md"

    # 3. Make a release commit
	git commit -m "Finish v$TARGET_VERSION release (1 of 2)"

    # Increment the change which will clear the _prerelease_ state
	bump2version change \
        --config-file .bumpversion.prerelease.cfg \
        --new-version "$TARGET_VERSION" \
        --message 'Finish v{new_version} release (2 of 2)' \
        --tag-name 'v{new_version}' \
        --verbose
fi

# Safety check version for a release
NEW_VERSION=$(awk '$1=="current_version"{print $NF; exit 0}' .bumpversion.prerelease.cfg)
if [[ "$PRERELEASE" = OFF ]]; then
    if [[ ! "$NEW_VERSION" = "$TARGET_VERSION" ]]; then
        echo "The target version $TARGET_VERSION and the new version $NEW_VERSION did not match" >&2
        exit 1
    fi
    NEW_VERSION="$TARGET_VERSION"
fi

# Push
git push --atomic origin main "v$NEW_VERSION" # git push && git push --tags

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='diskuv%2Fdiskuv-ocaml' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/
GLOBAL_OPTS=(--server-url "$CI_SERVER_URL" --project-id "$CI_PROJECT_ID")
CREATE_OPTS=(
    --tag-name "v$NEW_VERSION"
)
if [[ "$PRERELEASE" = OFF ]]; then
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

# Upload files to Generic Packages (https://docs.gitlab.com/ee/user/packages/generic_packages/)
# GITLAB_TARGET_VERSION=$(echo "$TARGET_VERSION" | tr +- ..) # replace -prerelM and +commitN with .prerelM and .commitN
PACKAGE_REGISTRY_GENERIC_URL="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"
PACKAGE_REGISTRY_URL="$PACKAGE_REGISTRY_GENERIC_URL/distribution-portable/$NEW_VERSION"
curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file contributors/_build/distribution-portable.zip \
     "$PACKAGE_REGISTRY_URL/distribution-portable.zip"
CREATE_OPTS+=(--assets-link "{\"name\":\"DKML distribution (zip) [portable]\",\"url\":\"${PACKAGE_REGISTRY_URL}/distribution-portable.zip\"}")
curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file contributors/_build/distribution-portable.tar.gz \
     "$PACKAGE_REGISTRY_URL/distribution-portable.tar.gz"
CREATE_OPTS+=(--assets-link "{\"name\":\"DKML distribution (tar.gz) [portable]\",\"url\":\"${PACKAGE_REGISTRY_URL}/distribution-portable.tar.gz\"}")

# Reference the Generic Packages that GitLab automatically creates
CREATE_OPTS+=(--assets-link "{\"name\":\"opam package manager for 32-bit Windows (tar.gz) [reproducible]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/opam-reproducible/$NEW_VERSION/opam-win32.tar.gz\"}")
CREATE_OPTS+=(--assets-link "{\"name\":\"opam package manager for 32-bit Windows (zip) [reproducible]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/opam-reproducible/$NEW_VERSION/opam-win32.zip\"}")
CREATE_OPTS+=(--assets-link "{\"name\":\"opam package manager for 64-bit Windows (tar.gz) [reproducible]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/opam-reproducible/$NEW_VERSION/opam-win64.tar.gz\"}")
CREATE_OPTS+=(--assets-link "{\"name\":\"opam package manager for 64-bit Windows (zip) [reproducible]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/opam-reproducible/$NEW_VERSION/opam-win64.zip\"}")
CREATE_OPTS+=(--assets-link "{\"name\":\"opam repository of ocaml/opam Docker base image (tar.gz) [reproducible]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/ocaml_opam_repo-reproducible/$NEW_VERSION/ocaml-opam-repo.tar.gz\"}")
CREATE_OPTS+=(--assets-link "{\"name\":\"opam repository of ocaml/opam Docker base image (zip) [reproducible]\",\"url\":\"${PACKAGE_REGISTRY_GENERIC_URL}/ocaml_opam_repo-reproducible/$NEW_VERSION/ocaml-opam-repo.zip\"}")

# Create the release
release-cli "${GLOBAL_OPTS[@]}" create "${CREATE_OPTS[@]}"
