#!/bin/sh
set -euf

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'

# Add or upgrade prereqs
idempotent_opam_local_install dkml-runtime-common '@dkml-runtime-common_SOURCE_DIR@' ./dkml-runtime-common.opam
idempotent_opam_local_install dkml-compiler-env '@dkml-compiler_SOURCE_DIR@' ./dkml-compiler-env.opam
idempotent_opam_local_install dkml-runtime-distribution '@dkml-runtime-distribution_SOURCE_DIR@' ./dkml-runtime-distribution.opam

# The Opam 2.2 prereleases have finicky behavior with git pins. We really
# need to use a commit id not just a branch. Without a commit id, often
# Opam does not know there is an update.
dor_COMMIT=$(git -C '@diskuv-opam-repository_SOURCE_DIR@' rev-parse --quiet --verify HEAD)

# [ctypes.0.19.2-windowssupport-r6] requirements:
# - The following required C libraries are missing: libffi.
#       shellcheck disable=SC2050
if [ "@CMAKE_HOST_WIN32@" = 1 ] && [ ! -e /clang64/lib/libffi.a ]; then
    # 32-bit? mingw-w64-i686-libffi
    pacman -Sy --noconfirm --needed mingw-w64-clang-x86_64-libffi
fi

# Add or upgrade the diskuv-opam-repository packages (except dkml-runtime-apps
# which we will do in the next step).
#
# Why add them if we don't deploy them immediately in the DkML installation?
# Because this [dkml] switch is used to collect the [pins.txt] used in
# [create-opam-switch.sh]. Besides, we have to make sure the packages
# actually build!
_LAST_ID_FILE="$UPSERT_BINARY_DIR/dkml_unmanaged_patched_packages.installed.id"
_IDEMPOTENT_ID="$dor_COMMIT @DKML_UNMANAGED_PATCHED_PACKAGES_SPACED_PKGVERS@"
_REBUILD=1
if [ -e "$_LAST_ID_FILE" ]; then
    _LAST_ID=$(cat "$_LAST_ID_FILE")
    if [ "$_LAST_ID" = "$_IDEMPOTENT_ID" ]; then
        _REBUILD=0
    fi
fi
if [ $_REBUILD -eq 1 ]; then
  "$OPAM_EXE" repository set-url @DISKUV_OPAM_REPOSITORY_NAME_NEW@ "git+file://@diskuv-opam-repository_SOURCE_DIR@/.git#$dor_COMMIT"
  "$OPAM_EXE" update @DISKUV_OPAM_REPOSITORY_NAME_NEW@ --repositories --yes
  '@WITH_COMPILER_SH@' "$OPAM_EXE" install @DKML_UNMANAGED_PATCHED_PACKAGES_SPACED_PKGVERS@ --yes
  printf "%s" "$_IDEMPOTENT_ID" > "$_LAST_ID_FILE"
fi

# Add or upgrade dkml-runtime-apps
idempotent_opam_local_install dkml-runtime-apps-installable '@dkml-runtime-apps_SOURCE_DIR@' @dkml-runtime-apps_SPACED_INSTALLABLE_OPAMFILES@

# Add or upgrade the Full distribution (minus Dune, minus conf-withdkml)
# * See upsert-dkml-pkgs-compiler.in for why we add packages like this)
# * There may be some overlap between these distribution packages and the patched
#   diskuv-opam-repository packages. That's fine!
# * We don't want [conf-withdkml] since that pulls in an external [with-dkml.exe]
#   which is not repeatable (ie. not hermetic).
idempotent_opam_install full-not-dune-flavor-no-withdkml @FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS@
