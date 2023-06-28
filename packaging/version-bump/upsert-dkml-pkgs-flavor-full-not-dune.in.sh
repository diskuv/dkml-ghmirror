#!/bin/sh
set -euf

export TOPDIR='@dkml-runtime-common_SOURCE_DIR@/all/emptytop'
export DKMLDIR='@DKML_ROOT_DIR@'
GIT_EXECUTABLE_DIR='@GIT_EXECUTABLE_DIR@'

# Get location of opam from cmdrun/opamrun (whatever is launching this script)
OPAM_EXE=$(command -v opam)

# But especially for Windows, we need the system Git for [opam repository]
# commands and no other PATH complications.
#       shellcheck disable=SC1091
. '@dkml-runtime-common_SOURCE_DIR@/unix/crossplatform-functions.sh'
if [ -x /usr/bin/cygpath ]; then GIT_EXECUTABLE_DIR=$(/usr/bin/cygpath -au "$GIT_EXECUTABLE_DIR"); fi
export PATH="$GIT_EXECUTABLE_DIR:$PATH"
autodetect_system_path_with_git_before_usr_bin
export PATH="$DKML_SYSTEM_PATH"

# Some opam packages need the C compiler
ORIGDIR=$(pwd)
autodetect_compiler with-compiler.sh
if [ "${DKML_BUILD_TRACE:-}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
  echo '=== with-compiler.sh ===' >&2
  cat with-compiler.sh >&2
  echo '=== (done) ===' >&2
fi

# Add or upgrade prereqs
cd '@dkml-runtime-common_SOURCE_DIR@' && "$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install ./dkml-runtime-common.opam --ignore-pin-depends --yes
cd '@dkml-compiler_SOURCE_DIR@' && "$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install ./dkml-compiler-env.opam --ignore-pin-depends --yes
cd '@dkml-runtime-distribution_SOURCE_DIR@' && "$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install ./dkml-runtime-distribution.opam --ignore-pin-depends --yes

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
"$OPAM_EXE" repository set-url @DISKUV_OPAM_REPOSITORY_NAME_NEW@ "git+file://@diskuv-opam-repository_SOURCE_DIR@/.git#${dor_COMMIT}"
"$OPAM_EXE" update @DISKUV_OPAM_REPOSITORY_NAME_NEW@ --repositories --yes
#"$ORIGDIR/with-compiler.sh" "$OPAM_EXE" pin ctypes git+file://z:/source/ocaml-ctypes/.git --yes --verbose --debug-level 2
"$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install @DKML_UNMANAGED_PATCHED_PACKAGES_SPACED_PKGVERS@ --yes

# Add or upgrade dkml-runtime-apps
cd '@dkml-runtime-apps_SOURCE_DIR@' && \
    "$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install @dkml-runtime-apps_SPACED_INSTALLABLE_OPAMFILES@ \
    --ignore-pin-depends --yes

# Add or upgrade the Full distribution (minus Dune, minus conf-withdkml)
# * See upsert-dkml-pkgs-compiler.in for why we add packages like this)
# * There may be some overlap between these distribution packages and the patched
#   diskuv-opam-repository packages. That's fine!
# * We don't want [conf-withdkml] since that pulls in an external [with-dkml.exe]
#   which is not repeatable (ie. not hermetic).
"$ORIGDIR/with-compiler.sh" "$OPAM_EXE" install @FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS@ --yes

# TODO FIXPOINT: Reinstall dkml-runtime-distribution.opam now that we have a complete set of packages. Perhaps iterate until FIXPOINT.
