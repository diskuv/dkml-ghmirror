#!/bin/sh
set -euf

# [dkml] SWITCH
# This is only for building [with-dkml] and any other critical tools that
# are needed for a full opam switch (especially on Windows).

export TOPDIR='@dkml-runtime-common_SOURCE_DIR@/all/emptytop'
export DKMLDIR='@DKML_ROOT_DIR@'

#       shellcheck disable=SC1091
. '@UPSERT_UTILS@'
unset OPAMSWITCH # Interferes with init-opam-root.sh and create-opam-switch.sh

# The Opam 2.2 prereleases have finicky behavior with git pins. We really
# need to use a commit id not just a branch. Without a commit id, often
# Opam does not know there is an update.
dor_COMMIT=$(git -C '@diskuv-opam-repository_SOURCE_DIR@' rev-parse --quiet --verify HEAD)

# init-opam-root
#
# -p DKMLABI: The DKML ABI (not 'dev')
# -r OPAMROOT: Use <OPAMROOT> as the Opam root. Unlike [-d] no modifications are made to its system variables
# -d STATEDIR: If specified, use <STATEDIR>/opam as the Opam root and modify its sys-ocaml-* variables.
#    It is an error for both [-r] and [-d] to be specified
# -o OPAMEXE_OR_HOME: Optional. If a directory, it is the home for Opam containing bin/opam-real or bin/opam.
#    If an executable, it is the opam to use (and when there is an opam shim the opam-real can be used)
# -v OCAMLVERSION_OR_HOME: Optional. The OCaml version or OCaml home (containing usr/bin/ocaml or bin/ocaml)
#    to use.
#    The bin/ subdir of the OCaml home is added to the PATH; currently, passing an OCaml version does nothing
#    Examples: 4.13.1, /usr, /opt/homebrew
# -a Use local repository rather than git repository for diskuv-opam-repository. Requires rsync
# -e DISKUV_REPO: Use DISKUV_REPO rather than the default diskuv-opam-repository. Valid opam
#    urls must be used like https:// or git+https:// or git+file:// urls.
# -c CENTRAL_REPO: Use CENTRAL_REPO rather than the default https://opam.ocaml.org repository. Valid opam
#    urls must be used like https:// or git+https:// or git+file:// urls.
# -x Disable sandboxing in all platforms. By default, sandboxing is disabled in Windows, WSL2 and in dockcross
#    Linux containers
'@dkml-runtime-distribution_SOURCE_DIR@/src/unix/private/init-opam-root.sh' \
-p "@DKML_HOST_ABI@" \
-r "$OPAMROOT" \
-o "$OPAM_EXE" \
-e "git+file://@diskuv-opam-repository_SOURCE_DIR@/.git#${dor_COMMIT}" \
-x

# shellcheck disable=SC2050
if [ "@CMAKE_HOST_WIN32@" = 1 ]; then
    # Get rid of annoying warning in prereleases of Opam 2.2
    "$OPAM_EXE" option --root "$OPAMROOT" --global depext=false
fi

# create-opam-switch
#
# -p DKMLABI: The DKML ABI (not 'dev'). Determines how to make an OCaml home if a version number is specified
#    (or nothing) using -v option. Also part of the name for the dkml switch if -s option
# -s: Create the [dkml] switch
# -n GLOBALOPAMSWITCH: The target global Opam switch. If specified adds --switch to opam
# -r OPAMROOT: Use <OPAMROOT> as the Opam root
# -b BUILDTYPE: The build type which is one of:
#     Debug
#     Release - Most optimal code. Should be faster than ReleaseCompat* builds
#     ReleaseCompatPerf - Compatibility with 'perf' monitoring tool.
#     ReleaseCompatFuzz - Compatibility with 'afl' fuzzing tool.
#    Ignored when -v OCAMLHOME is a OCaml home
# -a: Do not look for with-dkml. By default with-dkml is added to the PATH and used as the wrap-build-commands,
#     wrap-install-commands and wrap-remove-commands. Use -0 WRAP_COMMAND if you want your own wrap commands
# -F: Disable adding of the fdopen repository on Windows. Diskuv OCaml installs a pruned repository which, without
#     the -F option, would be added to the new switch
# -o OPAMEXE_OR_HOME: Optional. If a directory, it is the home for Opam containing bin/opam-real or bin/opam.
#    If an executable, it is the opam to use (and when there is an opam shim the opam-real can be used)
# -e NAME=VAL or -e NAME+=VAL: Optional; can be repeated. Environment variables that will be available
#    to all users of and packages in the switch
# -z: Do not use any default invariants (ocaml-system, dkml-base-compiler). If the -m option is not used,
#    there will be no invariants. When there are no invariants no pins will be created
# -R NAME=EXTRAREPO: Optional; may be repeated. Opam repository to use in the switch. Will be higher priority
#    than the implicit repositories like the default opam.ocaml.org repository. First repository listed on command
#    line will be highest priority of the extra repositories.
# -m EXTRAINVARIANT: Optional; may be repeated. Opam package or package.version that will be added to the switch
#   invariant
#
#
# AUTHORITATIVE OPTIONS = dkml-runtime-apps's [cmd_init.ml]. Aka: [dkml init]
# But not using [-m conf-withdkml]
run_create_opam_switch() {
    '@dkml-runtime-distribution_SOURCE_DIR@/src/unix/create-opam-switch.sh' "$@"
}
#       shellcheck disable=SC2050
if [ "@CMAKE_HOST_WIN32@" = 1 ] && [ -x /usr/bin/cygpath ] && [ -d /clang64 ]; then
    run_create_opam_switch() {
        '@dkml-runtime-distribution_SOURCE_DIR@/src/unix/create-opam-switch.sh' \
            -e "PKG_CONFIG_PATH=$(/usr/bin/cygpath -aw /clang64/lib/pkgconfig)" \
            -e "PKG_CONFIG_SYSTEM_INCLUDE_PATH=" \
            -e "PKG_CONFIG_SYSTEM_LIBRARY_PATH=" \
            "$@"
    }
fi
run_create_opam_switch \
-p '@DKML_HOST_ABI@' \
-b Release \
-n '@SHORT_BUMP_LEVEL@' \
-r "$OPAMROOT" \
-a \
-F \
-o "$OPAM_EXE" \
-z
