#!/bin/bash
set -euf

# Really only needed for MSYS2 if we are calling from a MSYS2/usr/bin/make.exe rather than a full shell
export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$PATH"

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/.." && pwd)

# ------------------
# BEGIN Command line processing

CPKGS_VERSION=0.1.1
PKGCONF_VERSION=

usage() {
    echo "Usage:" >&2
    echo "    upload-pkgconf.sh -h        Display this help message." >&2
    echo "    upload-pkgconf.sh [options] Copy the x86 pkgconf.exe" >&2
    echo "Options:" >&2
    echo "  -f CPKGS_VERSION: Copy from the specified cpkgs Generic version. Defaults to $CPKGS_VERSION" >&2
    echo "  -t PKGCONF_VERSION: Copy to the specified pkgconf Generic version. Defaults to the output of: pkgconf --version" >&2
}

while getopts ":hf:t:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        f) CPKGS_VERSION=$OPTARG;;
        t) PKGCONF_VERSION=$OPTARG;;
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

# ------------------------
# GitLab Download from private repository
# ------------------------

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='diskuv%2Fdistributions%2Fnext%2Fcpkgs' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/

# Setup Generic Packages (https://docs.gitlab.com/ee/user/packages/generic_packages/)
PACKAGE_REGISTRY_GENERIC_URL="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"
CPKGS_URL="$PACKAGE_REGISTRY_GENERIC_URL/x86-windows/$CPKGS_VERSION"

# Download from Generic Packages

install -d build
curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -o build/base.tar.gz \
    "$CPKGS_URL/base.tar.gz"

# Create build/tools/pkgconf.tar.gz with
# - windows_x86/pkgconf.exe (and .dll and .pdb)
cd build
tar xvf base.tar.gz ./tools/pkgconf
cd tools
rm -rf windows_x86
mv pkgconf windows_x86
tar cvfz pkgconf.tar.gz windows_x86
cd ../..

if [ -z "${PKGCONF_VERSION:-}" ]; then
    PKGCONF_VERSION=$(build/tools/windows_x86/pkgconf --version)
fi

# ------------------------
# GitLab Release
# ------------------------

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='dkml%2Fdistributions%2Fdkml' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/

# Setup Generic Packages (https://docs.gitlab.com/ee/user/packages/generic_packages/)
PACKAGE_REGISTRY_GENERIC_URL="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"
PKGCONF_URL="$PACKAGE_REGISTRY_GENERIC_URL/pkgconf/$PKGCONF_VERSION"

# Upload pkgconf tarball to Generic Packages

curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file "build/tools/pkgconf.tar.gz" \
     "$PKGCONF_URL/pkgconf.tar.gz"
