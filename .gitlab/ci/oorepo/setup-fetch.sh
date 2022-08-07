#!/bin/sh
set -eufx
CI_PROJECT_DIR=$1
shift
DEPLOYDIR=$1
shift
DV_WindowsMsvcDockerImage=$1
shift
OCAMLVERSION=$1
shift

# SETUP
# -----

env TOPDIR="${CI_PROJECT_DIR}/vendor/drc/all/emptytop" vendor/drd/src/unix/private/r-f-oorepo-1-setup.sh \
    -d "${CI_PROJECT_DIR}" \
    -t "$DEPLOYDIR" \
    -v "$DV_WindowsMsvcDockerImage" \
    -a amd64 \
    -b "$OCAMLVERSION"

# BUILD (FETCH)
# -------------

# Because Cygwin has a max 260 character limit of absolute file names, we place the working directories in /tmp, and override moby/.
# Because we want to make the full repository as an artifact, we override opamroot/.

DKML_TMP_PARENTDIR=$(mktemp -d /tmp/dkmlp.XXXXX)
export DKML_TMP_PARENTDIR
export DKML_MOBYDIR="$CI_PROJECT_DIR/_ci/moby"
export DKML_BUILD_TRACE=ON
export DKML_BUILD_TRACE_LEVEL=2

cd "$DEPLOYDIR"
set +e
"share/dkml/repro/200-fetch-oorepo-${OCAMLVERSION}/vendor/drd/src/unix/private/r-f-oorepo-2-build-noargs.sh"
ec=$?

rm -rf "$DKML_TMP_PARENTDIR"
if [ $ec = 103 ]; then
    echo "Possible cache corruption. Deleting Moby cache." >&2
    rm -rf "$DKML_MOBYDIR"
fi
exit $ec
