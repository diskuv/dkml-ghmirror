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
    echo "    release-prerel-delete.sh -h        Display this help message." >&2
    echo "    release-prerel-delete.sh VERSION   Delete prereleases of the version. Ex. 0.2, 0.3.3" >&2
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

if [ "$#" -ne 1 ]; then
    echo "Missing VERSION" >&2
    usage
    exit 1
fi

VERSION=$1
shift

DOTS=$(printf "%s" "$VERSION" | tr -cd .)
case "$DOTS" in
    .|..) ;;
    *)
    echo "The VERSION must be in the format M.N or M.N.P." >&2
    usage
    exit 1
esac

# END Command line processing
# ------------------

cd "$DKMLDIR"

if which glab.exe >/dev/null 2>&1; then
    GLAB=glab.exe
else
    GLAB=glab
fi

# shellcheck disable=SC2155
export GITLAB_PRIVATE_TOKEN=$($GLAB auth status -t 2>&1 | awk '$2=="Token:" {print $3}')

# TODO: Need to delete the release, not just the Generic Packages

# Find Generic Packages
# TODO: Pagination is not handled!! https://docs.gitlab.com/ee/api/index.html#pagination
PROJECT_URL='https://gitlab.com/api/v4/projects/dkml%2Fdistributions%2Fdkml'

install -d _build
curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$PROJECT_URL/packages?per_page=100" | \
     jq > _build/packages.lst.txt

yesno() {
    echo "Do you wish to delete those versions?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) return;;
            No ) exit 0;;
        esac
    done
}

case "$DOTS" in
    .)
        awk '/"name":/{name=$2} /version/{v=0} /version.*'"$VERSION"'[.][0-9]*-prerel/{v=1; print name, $2}' _build/packages.lst.txt
        yesno
        awk                    '/version/{v=0} /version.*'"$VERSION"'[.][0-9]*-prerel/{v=1} v==1&&/delete_api_path/{print $2}' _build/packages.lst.txt | tr -d '"' | xargs -n1 curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" --request DELETE
        ;;
    ..)
        awk '/"name":/{name=$2} /version/{v=0} /version.*'"$VERSION"'-prerel/{v=1; print name, $2}' _build/packages.lst.txt
        yesno
        awk                    '/version/{v=0} /version.*'"$VERSION"'-prerel/{v=1} v==1&&/delete_api_path/{print $2}' _build/packages.lst.txt | tr -d '"' | xargs -n1 curl --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" --request DELETE
        ;;
esac
echo "Delete completed"
