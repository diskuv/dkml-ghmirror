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
    echo "    reupload.sh -h  Display this help message." >&2
    echo "    reupload.sh -p  Create a prerelease." >&2
    echo "    reupload.sh     Create a release." >&2
}

while getopts ":h" opt; do
    case ${opt} in
        h )
            usage
            exit 0
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

# Capture the version

NEW_VERSION=$(awk '$1=="current_version"{print $NF; exit 0}' .bumpversion.prerelease.cfg)

# ------------------------
# GitLab Release
# ------------------------

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='diskuv-ocaml%2Fdistributions%2Fdkml' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/

# Setup Generic Packages (https://docs.gitlab.com/ee/user/packages/generic_packages/)
PACKAGE_REGISTRY_GENERIC_URL="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"
SUPPORT_NEWURL="$PACKAGE_REGISTRY_GENERIC_URL/ocaml_opam_repo-support/$NEW_VERSION"

# Build ocaml_opam_repo_trim.bc (after the vendor/drd/ is cleaned, and just before upload)
opam exec -- dune clean --root vendor/drd/src/ml
opam exec -- dune build --root vendor/drd/src/ml ocaml_opam_repo_trim.bc
DUNE_BUILDDIR=vendor/drd/src/ml/_build/default

# Upload support files to Generic Packages

curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file "$DUNE_BUILDDIR/ocaml_opam_repo_trim.bc" \
     "$SUPPORT_NEWURL/ocaml_opam_repo_trim.bc"
