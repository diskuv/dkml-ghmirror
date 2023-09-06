#!/bin/bash
set -euf

# Really only needed for MSYS2 if we are calling from a MSYS2/usr/bin/make.exe rather than a full shell
export PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$PATH"

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR/.." && pwd)

# ------------------
# BEGIN Command line processing

CPKGS_VERSION=0.1.1
SQLITE3_VERSION=

usage() {
    echo "Usage:" >&2
    echo "    upload-sqlite3.sh -h        Display this help message." >&2
    echo "    upload-sqlite3.sh [options] Copy the x86 sqlite3.lib" >&2
    echo "Options:" >&2
    echo "  -f CPKGS_VERSION: Copy from the specified cpkgs Generic version. Defaults to $CPKGS_VERSION" >&2
    echo "  -t SQLITE3_VERSION: Copy to the specified sqlite3 Generic version. Defaults to the output of: sqlite3 --version" >&2
}

while getopts ":hf:t:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        f) CPKGS_VERSION=$OPTARG;;
        t) SQLITE3_VERSION=$OPTARG;;
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
CPKGS_X64_URL="$PACKAGE_REGISTRY_GENERIC_URL/x64-windows/$CPKGS_VERSION"
CPKGS_X86_URL="$PACKAGE_REGISTRY_GENERIC_URL/x86-windows/$CPKGS_VERSION"

# Download from Generic Packages

install -d build
curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -o build/base-x64.tar.gz \
    "$CPKGS_X64_URL/base.tar.gz"
curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -o build/base-x86.tar.gz \
    "$CPKGS_X86_URL/base.tar.gz"

# Create build/tools/sqlite3-x64.tar.gz with
# - windows_x64/sqlite3.lib
# and build/tools/sqlite3-x86.tar.gz with
# - windows_x86/sqlite3.lib
# Also include headers and 
cd build
if [ -z "${SQLITE3_VERSION:-}" ]; then
    tar xvf base-x64.tar.gz ./tools/sqlite3.exe ./tools/sqlite3.dll
    SQLITE3_VERSION=$(tools/sqlite3 --version | awk '{print $1}')
fi
{
    tar xvf base-x64.tar.gz ./bin/sqlite3.dll ./include/sqlite3.h ./include/sqlite3ext.h ./lib/sqlite3.lib ./lib/pkgconfig/sqlite3.pc
    rm -rf windows_x64
    install -d windows_x64/bin windows_x64/include windows_x64/lib/pkgconfig
    mv bin/sqlite3.dll windows_x64/bin/
    mv include/sqlite3.h include/sqlite3ext.h windows_x64/include/
    mv lib/sqlite3.lib windows_x64/lib/
    mv lib/pkgconfig/sqlite3.pc windows_x64/lib/pkgconfig/
    tar cvfz sqlite3-x64.tar.gz windows_x64
}
{
    tar xvf base-x86.tar.gz ./bin/sqlite3.dll ./include/sqlite3.h ./include/sqlite3ext.h ./lib/sqlite3.lib ./lib/pkgconfig/sqlite3.pc
    rm -rf windows_x86
    install -d windows_x86/bin windows_x86/include windows_x86/lib windows_x86/lib/pkgconfig/
    mv bin/sqlite3.dll windows_x86/bin/
    mv include/sqlite3.h include/sqlite3ext.h windows_x86/include/
    mv lib/sqlite3.lib windows_x86/lib/
    mv lib/pkgconfig/sqlite3.pc windows_x86/lib/pkgconfig/
    tar cvfz sqlite3-x86.tar.gz windows_x86
}
cd ..

# ------------------------
# GitLab Release
# ------------------------

# Set GitLab options
CI_SERVER_URL=https://gitlab.com
CI_API_V4_URL="$CI_SERVER_URL/api/v4"
CI_PROJECT_ID='dkml%2Fdistributions%2Fdkml' # Must be url-encoded per https://docs.gitlab.com/ee/user/packages/generic_packages/

# Setup Generic Packages (https://docs.gitlab.com/ee/user/packages/generic_packages/)
PACKAGE_REGISTRY_GENERIC_URL="$CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/generic"
SQLITE3_URL="$PACKAGE_REGISTRY_GENERIC_URL/sqlite3/$SQLITE3_VERSION"

# Upload sqlite3 tarball to Generic Packages

curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file "build/sqlite3-x64.tar.gz" \
     "$SQLITE3_URL/sqlite3-x64.tar.gz"
curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --upload-file "build/sqlite3-x86.tar.gz" \
     "$SQLITE3_URL/sqlite3-x86.tar.gz"
