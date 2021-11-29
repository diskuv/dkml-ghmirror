#!/bin/sh
# -------------------------------------------------------
# build-sandbox-init-common.sh PLATFORM
#
# Purpose: Install common tools like Opam which are needed for builds but do NOT depend on the source code.
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
# -------------------------------------------------------
set -euf

# shellcheck disable=SC2034
PLATFORM=$1
shift

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR"/../.. && pwd)

# shellcheck disable=SC1091
. "$DKMLDIR"/runtime/unix/_common_tool.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# Set OCAMLHOME and OPAMHOME, if part of DKML system installation
autodetect_ocaml_and_opam_home

# Set BUILDHOST_ARCH
build_machine_arch

# -----------------------
# BEGIN opam init

DKML_FEATUREFLAG_CMAKE_PLATFORM=ON log_trace "$DKMLDIR"/installtime/unix/private/init-opam-root.sh -o "$OPAMHOME" -v "$OCAMLHOME"

# END opam init
# -----------------------

# -----------------------
# BEGIN opam create system switch

DKML_FEATUREFLAG_CMAKE_PLATFORM=ON log_trace "$DKMLDIR"/installtime/unix/private/create-tools-switch.sh -f Full -p "$BUILDHOST_ARCH" -o "$OPAMHOME" -v "$OCAMLHOME"

# END opam create system switch
# -----------------------

# -----------------------
# BEGIN install opam plugins

DKML_FEATUREFLAG_CMAKE_PLATFORM=ON log_trace "$DKMLDIR"/installtime/unix/private/install-opamplugin-opam-dkml.sh -o "$OPAMHOME" -v "$OCAMLHOME"

# END install opam plugins
# -----------------------

# -----------------------
# BEGIN install dkml plugins (except vcpkg which is done in build-sandbox-init-vcpkg.sh)

DKML_FEATUREFLAG_CMAKE_PLATFORM=ON log_trace "$DKMLDIR"/installtime/unix/private/install-dkmlplugin-withdkml.sh -o "$OPAMHOME" -v "$OCAMLHOME"

# END install dkml plugins
# -----------------------
