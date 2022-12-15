#!/bin/bash
set -euf

# Really only needed for MSYS2 if we are calling from a MSYS2/usr/bin/make.exe rather than a full shell
export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$PATH"

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/.." && pwd)

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    release.sh -h  Display this help message." >&2
    echo "    release.sh -p  Create a prerelease." >&2
    echo "    release.sh     Create a release." >&2
    printf "Options:\n" >&2
    printf "  -q: Quick mode. Creates a 'new' version of the OCaml Opam Repository that is a copy of the last version.\n" >&2
    printf "      After GitLab CI rebuilds the repository, the new version will be updated with the rebuilt contents.\n" >&2
    printf "      Without the quick mode, only one revision of the new version (the rebuilt contents) will be made.\n" >&2
}

QUICK=OFF
while getopts ":hq" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        q ) QUICK=ON ;;
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
CURRENT_VERSION=0.4.0-prerel22
OUT_VERSION=0.4.0-prerel26

# ------------------------
# GitLab Release
# ------------------------

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='diskuv-ocaml%2Fdistributions%2Fdkml' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/

# Setup Generic Packages (https://docs.gitlab.com/ee/user/packages/generic_packages/)
PACKAGE_REGISTRY_GENERIC_URL="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"
OOREPO_NEWURL="$PACKAGE_REGISTRY_GENERIC_URL/ocaml_opam_repo-reproducible/$OUT_VERSION"
OOREPO_OLDURL="$PACKAGE_REGISTRY_GENERIC_URL/ocaml_opam_repo-reproducible/$CURRENT_VERSION"
#OCAMLVERS=(4.14.0 4.13.1 4.12.1)
OCAMLVERS=(4.14.0 4.12.1)
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
