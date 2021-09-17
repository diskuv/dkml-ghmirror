#!/bin/bash
# -------------------------------------------------------
# build-sandbox-init.sh PLATFORM
#
# Purpose: Install tools in _tools which are needed for builds but do NOT depend on the source code.
#
# When Used:
#  - Install Time
#  - Build Time when deploying a new platform for the first time
#
# PLATFORM=dev|linux_arm32v6|linux_arm32v7|windows_x86|...
#
#   The PLATFORM can be `dev` which means the dev platform using the native CPU architecture
#   and system binaries for Opam from your development machine.
#   Otherwise it is one of the "PLATFORMS" canonically defined in TOPDIR/Makefile.
#
# The tool packages are placed in build/_tools/$PLATFORM/$PKGNAME.
#
# -------------------------------------------------------
set -euf -o pipefail

# shellcheck disable=SC2034
PLATFORM=$1
shift

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR"/../.. && pwd)

# shellcheck disable=SC1091
source "$DKMLDIR"/runtime/unix/_common_tool.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

BINDIR="$TOOLSDIR/local/bin" # executables placed here are automatically added to build's PATH
install -d "$BINDIR"
if [ -x /usr/bin/setfacl ]; then /usr/bin/setfacl --remove-all --remove-default "$BINDIR"; fi

# -----------------------
# BEGIN opam init

if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then set -x; fi
"$DKMLDIR"/installtime/unix/init-opam-root.sh -p "$PLATFORM"

# END opam init
# -----------------------
