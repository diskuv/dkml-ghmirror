#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# [ctypes.0.19.2-windowssupport-r6] requirements:
# - The following required C libraries are missing: libffi.
#       shellcheck disable=SC2050
if [ "@CMAKE_HOST_WIN32@" = 1 ] && [ ! -e /clang64/lib/libffi.a ]; then
    # 32-bit? mingw-w64-i686-libffi
    pacman -Sy --noconfirm --needed mingw-w64-clang-x86_64-libffi
fi

# ------ 0 --------
# Add or upgrade prereqs: dkml-runtime-common, dkml-compiler-env, dkml-runtime-distribution
# ------- 1 -------
# Add or upgrade the diskuv-opam-repository packages (except dkml-runtime-apps
# which we will do in the next step).
#
# Why add them if we don't deploy them immediately in the DkML installation?
# Because this [dkml] switch is used to collect the [pins.txt] used in
# [create-opam-switch.sh]. Besides, we have to make sure the packages
# actually build!
#
# ------- 2 -------
# Add or upgrade the Full distribution (minus Dune, minus conf-withdkml)
# * See upsert-dkml-pkgs-compiler.in for why we add packages like this)
# * There may be some overlap between these distribution packages and the patched
#   diskuv-opam-repository packages. That's fine!
# * We don't want [conf-withdkml] since that pulls in an external [with-dkml.exe]
#   which is not repeatable (ie. not hermetic).
#
# ------- 3 -------
# Add or upgrade dkml-runtime-apps
#
# ------- Why all at once? -------
# Install diskuv-opam-repository packages at
# the same time as FULL_NOT_DUNE packages so
# indirect dependencies of diskuv-opam-repository
# packages like [base] are installed with the correct
# version. Previously the latest base [base.v0.16.2]
# was broken in MSVC, and since [feather] was in
# diskuv-opam-repository and [feather] had a dependency
# on [base], that caused the broken [base.v0.16.2]
# to be installed. However, the good [base.v0.16.1]
# was listed in dkml-runtime-distribution (ie.
# FULL_NOT_DUNE packages).
# Similarly dkml-runtime-apps packages are indirect
# dependencies of diskuv-opam-repository. Since the
# versioning to (example) dkml-apps.M.N.O has already
# been done, the dkml-runtime-apps packages must be
# part of the install command line.
idempotent_opam_local_install unmanaged-patched-full-no-dune-withdkml-and-apps '@DKML_UNMANAGED_PATCHED_PACKAGES_PKGVERS_CKSUM@' '@PROJECT_SOURCE_DIR@' \
    '@dkml-runtime-common_REL_SOURCE_DIR@/dkml-runtime-common.opam' \
    '@dkml-compiler_REL_SOURCE_DIR@/dkml-compiler-env.opam' \
    '@dkml-runtime-distribution_REL_SOURCE_DIR@/dkml-runtime-distribution.opam' \
    @DKML_UNMANAGED_PATCHED_PACKAGES_SPACED_PKGVERS@ \
    @FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS@ \
    @dkml-runtime-apps_SPACED_REL_INSTALLABLE_OPAMFILES@
