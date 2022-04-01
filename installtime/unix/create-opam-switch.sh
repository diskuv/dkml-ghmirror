#!/bin/sh
set -euf

# ------
# pinned
# ------
#
# The format is `PACKAGE_NAME,PACKAGE_VERSION`. Notice the **comma** inside the quotes!

# These MUST BE IN SYNC with installtime/unix/private/ml/ocaml_opam_repo_trim.ml's [packages_fdopen_to_remove].
# Summary: DKML provides patches for these
#
# Sections:
# 1. Subset of packages from ci-flavor-packages.txt, in `.txt` order
# 2. Subset of packages from full-flavor-minus-ci-flavor-packages.txt, in `.txt` order
# 3. Any packages that don't belong in #1 and #2, in alphabetical order
PINNED_PACKAGES_DKML_PATCHES="
    ocamlfind,1.9.1
    ptime,0.8.6

    ocp-indent,1.8.2-windowssupport

    bigstringaf,0.8.0
    core_kernel,v0.14.2
    ctypes-foreign,0.19.2-windowssupport-r4
    ctypes,0.19.2-windowssupport-r4
    digestif,1.0.1
    dune-configurator,2.9.3
    feather,0.3.0
    mccs,1.1+13
    mirage-crypto-ec,0.10.4-windowssupport
    mirage-crypto-pk,0.10.4-windowssupport
    mirage-crypto-rng-async,0.10.4-windowssupport
    mirage-crypto-rng-mirage,0.10.4-windowssupport
    mirage-crypto-rng,0.10.4-windowssupport
    mirage-crypto,0.10.4-windowssupport
    ocamlbuild,0.14.0
    ppx_expect,v0.14.1
    "

# These MUST BE IN SYNC with installtime/unix/private/ml/ocaml_opam_repo_trim.ml's [packages_fdopen_to_remove].
# Summary: Packages which MUST be pinned and come from the central Opam repository.
# Reasons:
# a) pkg used a major version bump and caused major breaking changes to downstream packages or broke OS (ex. Win32) compatibility
# b) pkgver not yet present in fdopen
# c) pkgver is in fdopen, but `opam` file is equivalent to central Opam repository (so no fdopen modifications)
#
# Callouts:
# * (a) ppxlib incorrectly did not use a major version bump and caused major breaking changes to downstream packages.
#   That is, ppxlib.0.23.0 breaks ppx_variants_conv.v0.14.1. PR to fix is https://github.com/janestreet/ppx_variants_conv/pull/9
# * (b) jsonrpc, lsp and ocaml-lsp-server as of 2021-11-22 was not present in the fdopen repository, but was needed by lsp.1.9.0
# * (c) bos, sha and sexplib are needed to compile with-dkml.exe; bos needs rresult and fmt, and fdopen `opam` files are same as https://opam.ocaml.org/
# * (c) cmdliner and opam-client (+ opam-*) are needed to compile opam-dkml.exe; same `opam` as https://opam.ocaml.org/
# * (a) alcotest.1.4.0 works with Win32 MSVC; 1.5.0 does not
#
# Sections:
# 1. Subset of packages from ci-flavor-packages.txt, in `.txt` order
# 2. Subset of packages from full-flavor-minus-ci-flavor-packages.txt, in `.txt` order
# 3. Any packages that don't belong in #1 and #2, in alphabetical order
PINNED_PACKAGES_OPAM_VERSIONAGNOSTIC="
    bos,0.2.1
    fmt,0.9.0
    rresult,0.7.0
    sha,1.15.2
    sexplib,v0.14.0
    cmdliner,1.0.4
    crunch,3.2.0
    uuidm,0.9.7

    jingoo,1.4.4
    ocamlformat,0.19.0
    ocamlformat-rpc,0.19.0
    ocamlformat-rpc-lib,0.19.0
    odoc-parser,0.9.0
    stdio,v0.14.0
    base,v0.14.2
    dune,2.9.3
    dune-action-plugin,2.9.3
    dune-glob,2.9.3
    dune-private-libs,2.9.3
    dune-site,2.9.3
    utop,2.9.0

    ppxlib,0.22.0
    alcotest,1.4.0
    alcotest-async,1.4.0
    alcotest-js,1.4.0
    alcotest-lwt,1.4.0
    alcotest-mirage,1.4.0
    "
export PINNED_PACKAGES_OPAM_4_12_1="
    lsp,1.9.0
    ocaml-lsp-server,1.9.0
    jsonrpc,1.9.0
"
export PINNED_PACKAGES_OPAM_4_13_1="
    lsp,1.10.3
    ocaml-lsp-server,1.10.3
    jsonrpc,1.10.3
"

OCAML_DEFAULT_VERSION=4.12.1

# ------------------
# BEGIN Command line processing

# __escape_args_for_shell ARG1 ARG2 ...
# (Copied from crossplatform-functions.sh)
#
# If `__escape_args_for_shell asd sdfs 'hello there'` then prints `asd sdfs hello\ there`
#
# Prereq: autodetect_system_binaries
__escape_args_for_shell() {
    # Confer %q in https://www.gnu.org/software/bash/manual/bash.html#Shell-Builtin-Commands
    bash -c 'printf "%q " "$@"' -- "$@" | PATH=/usr/bin:/bin sed 's/ $//'
}

usage() {
    printf "%s\n" "Creates a local Opam switch with a working compiler.">&2
    printf "%s\n" "  Will pre-pin package versions based on the installed Diskuv OCaml distribution." >&2
    printf "%s\n" "  Will set switch options pin package versions needed to compile on Windows." >&2
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    create-opam-switch.sh -h                          Display this help message" >&2
    printf "%s\n" "    create-opam-switch.sh -u OFF|ON [-b BUILDTYPE]    Create the Opam switch." >&2
    printf "%s\n" "                                                      If an OCaml home is specified with the -v option, then the" >&2
    printf "%s\n" "                                                      switch will have a 'system' OCaml compiler that uses OCaml from the" >&2
    printf "%s\n" "                                                      PATH. If an OCaml version is specified with the -v option, and the" >&2
    printf "%s\n" "                                                      -p option is used, then the switch will build a 'base' OCaml compiler." >&2
    printf "%s\n" "                                                      Otherwise (ie. OCaml version specified with the -v option but no -p option, or" >&2
    printf "%s\n" "                                                      the -v option not specified) the switch must be created by the DKSDK product;" >&2
    printf "%s\n" "                                                      DKSDK will supply environment variables so that the switch can build a" >&2
    printf "%s\n" "                                                      'base' OCaml compiler, although this path is rare since DKSDK will typically" >&2
    printf "%s\n" "                                                      create and use an OCaml home. DKSDK will also supply variables so that the" >&2
    printf "%s\n" "                                                      -b option is not needed; otherwise -b option is required." >&2
    printf "%s\n" "Options:" >&2
    printf "%s\n" "    -p DKMLPLATFORM: The DKML platform (not 'dev'). Determines how to make an OCaml home if a version number is specified" >&2
    printf "%s\n" "       (or nothing) using -v option. Also part of the name for the host-tools switch if -s option" >&2
    printf "%s\n" "    -d STATEDIR: Create <STATEDIR>/_opam as an Opam switch prefix, unless [-s] is also" >&2
    printf "%s\n" "        selected which creates <STATEDIR>/host-tools, and unless [-s] [-u ON] is also" >&2
    printf "%s\n" "        selected which creates <DiskuvOCamlHome>/host-tools/_opam on Windows and" >&2
    printf "%s\n" "        <OPAMROOT>/diskuv-host-tools/_opam on non-Windows. See also -t option" >&2
    printf "%s\n" "    -s: Create the diskuv-host-tools or host-tools switch. See the -d option for the rules" >&2
    printf "%s\n" "    -b BUILDTYPE: The build type which is one of:" >&2
    printf "%s\n" "        Debug" >&2
    printf "%s\n" "        Release - Most optimal code. Should be faster than ReleaseCompat* builds" >&2
    printf "%s\n" "        ReleaseCompatPerf - Compatibility with 'perf' monitoring tool." >&2
    printf "%s\n" "        ReleaseCompatFuzz - Compatibility with 'afl' fuzzing tool." >&2
    printf "%s\n" "    -t OPAMSWITCH: Create <OPAMSWITCH>/_opam as an Opam switch prefix when -u ON but not -s." >&2
    printf "%s\n" "       Optional when -d option supplied; defaults to <STATEDIR>/_opam" >&2
    printf "%s\n" "    -u ON|OFF: User mode. If OFF, sets Opam --root to <STATEDIR>/opam." >&2
    printf "%s\n" "       If ON, uses Opam 2.2+ default root" >&2
    printf "%s\n" "    -v OCAMLVERSION_OR_HOME: Optional. The OCaml version or OCaml home (containing usr/bin/ocaml or bin/ocaml)" >&2
    printf "%s\n" "       to use. The OCaml home determines the native code produced by the switch." >&2
    printf "%s\n" "       Examples: 4.13.1, /usr, /opt/homebrew" >&2
    printf "%s\n" "    -o OPAMHOME: Optional. Home directory for Opam containing bin/opam or bin/opam.exe" >&2
    printf "%s\n" "    -y Say yes to all questions (can be overridden with DKML_OPAM_FORCE_INTERACTIVE=ON)" >&2
    printf "%s\n" "    -c EXTRAPATH: Optional. Semicolon separated PATH that should be available to all users of and packages" >&2
    printf "%s\n" "       in the switch. Since the PATH is affected the EXTRAPATH must be for the host ABI." >&2
    printf "%s\n" "       Users of with-dkml.exe should also do '-e DKML_3P_PROGRAM_PATH+=<EXTRAPATH>' so that PATH can propagate." >&2
    printf "%s\n" "    -e NAME=VAL or -e NAME+=VAL: Optional; can be repeated. Environment variables that will be available" >&2
    printf "%s\n" "       to all users of and packages in the switch" >&2
    printf "%s\n" "    -f NAME=VAL or -f NAME=: Optional; can be repeated. Opam variables that will be available" >&2
    printf "%s\n" "       to all <package>.opam in the switch. '-f NAME=' will delete the variable if present" >&2
    printf "%s\n" "    -r NAME=EXTRAREPO: Optional; may be repeated. Opam repository to use in the switch. Will be higher priority" >&2
    printf "%s\n" "       than the implicit repositories like the default opam.ocaml.org repository. First repository listed on command" >&2
    printf "%s\n" "       line will be highest priority of the extra repositories." >&2
    printf "%s\n" "    -i HOOK: Commands that will be run after the Opam switch has been created." >&2
    printf "%s\n" "       The hook file must be a /bin/sh script (POSIX compatible script, not Bash!)." >&2
    printf "%s\n" "       Opam commands should be platform-neutral, and will be executed after the switch has been initially" >&2
    printf "%s\n" "       created with a minimal OCaml compiler, and after DKML pins and options are set for the switch." >&2
    printf "%s\n" "       The Opam commands should use \$OPAMEXE as the path to the Opam executable." >&2
    printf "%s\n" "          Example: \$OPAMEXE pin add --yes opam-lib 'https://github.com/ocaml/opam.git#1.2'" >&2
    printf "%s\n" "       The hook file must use LF (not CRLF) line terminators. In a git project we recommend including" >&2
    printf "%s\n" "         *.sh text eol=lf" >&2
    printf "%s\n" "       or similar in a .gitattributes file so on Windows the file is not autoconverted to CRLF on git checkout." >&2
    printf "%s\n" "    -j PREBUILD: Optional; may be repeated. A pre-build-command that Opam will execute before building any" >&2
    printf "%s\n" "      Opam package. Documentation is at https://opam.ocaml.org/doc/Manual.html#configfield-pre-build-commands" >&2
    printf "%s\n" "      and the format of PREBUILD must be:" >&2
    printf "%s\n" "        <term> { <filter> } ..." >&2
    printf "%s\n" "      The enclosing [ ] array will be added automatically; do not add it yourself." >&2
    printf "%s\n" "    -k POSTINSTALL: Optional; may be repeated. A post-install-command that Opam will execute before building any" >&2
    printf "%s\n" "      Opam package. Documentation is at https://opam.ocaml.org/doc/Manual.html#configfield-post-install-commands" >&2
    printf "%s\n" "      ; see -j PREBUILD for the format." >&2
    printf "%s\n" "    -l PREREMOVE: Optional; may be repeated. A pre-remove-command that Opam will execute before building any" >&2
    printf "%s\n" "      Opam package. Documentation is at https://opam.ocaml.org/doc/Manual.html#configfield-pre-remove-commands" >&2
    printf "%s\n" "      ; see -j PREBUILD for the format." >&2
    printf "%s\n" "    -m EXTRAINVARIANT: Optional; may be repeated. Opam package or package.version that will be added to the switch" >&2
    printf "%s\n" "      invariant" >&2
}

DO_SETENV_OPTIONS=
add_do_setenv_option() {
    add_do_setenv_option_CMD=$1
    shift
    add_do_setenv_option_ESCAPED=$(__escape_args_for_shell "$add_do_setenv_option_CMD")
    # newlines are stripped by MSYS2 dash, so use semicolons as separator
    if [ -z "$DO_SETENV_OPTIONS" ]; then
        DO_SETENV_OPTIONS=$(printf "do_setenv_option %s" "$add_do_setenv_option_ESCAPED")
    else
        DO_SETENV_OPTIONS=$(printf "%s ; do_setenv_option %s" "$DO_SETENV_OPTIONS" "$add_do_setenv_option_ESCAPED")
    fi
}
DO_VARS=
add_do_var() {
    add_do_var_CMD=$1
    shift
    add_do_var_ESCAPED=$(__escape_args_for_shell "$add_do_var_CMD")
    # newlines are stripped by MSYS2 dash, so use semicolons as separator
    if [ -z "$DO_VARS" ]; then
        DO_VARS=$(printf "do_var %s" "$add_do_var_ESCAPED")
    else
        DO_VARS=$(printf "%s ; do_var %s" "$DO_VARS" "$add_do_var_ESCAPED")
    fi
}

BUILDTYPE=
DISKUV_TOOLS_SWITCH=OFF
STATEDIR=
YES=OFF
USERMODE=ON
OCAMLVERSION_OR_HOME=${OCAML_DEFAULT_VERSION}
OPAMHOME=
DKMLPLATFORM=
EXTRAPATH=
EXTRAREPOCMDS=
HOOK_POSTCREATE=
PREBUILDS=
POSTINSTALLS=
PREREMOVES=
EXTRAINVARIANTS=
while getopts ":hb:p:sd:u:o:t:v:yc:r:e:f:i:j:k:l:m:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            DKMLPLATFORM=$OPTARG
            if [ "$DKMLPLATFORM" = dev ]; then
                usage
                exit 0
            fi
        ;;
        b )
            BUILDTYPE=$OPTARG
        ;;
        s )
            DISKUV_TOOLS_SWITCH=ON
        ;;
        d)
            STATEDIR=$OPTARG
        ;;
        t)
            TARGET_OPAMSWITCH=$OPTARG
        ;;
        u )
            USERMODE=$OPTARG
        ;;
        y)
            YES=ON
        ;;
        v )
            if [ -n "$OPTARG" ]; then OCAMLVERSION_OR_HOME=$OPTARG; fi
        ;;
        o ) OPAMHOME=$OPTARG ;;
        c ) EXTRAPATH=$OPTARG ;;
        e ) add_do_setenv_option "$OPTARG" ;;
        f ) add_do_var "$OPTARG" ;;
        r )
            if [ -n "$EXTRAREPOCMDS" ]; then
                EXTRAREPOCMDS="$EXTRAREPOCMDS; "
            fi
            EXTRAREPOCMDS="${EXTRAREPOCMDS}add_extra_repo '${OPTARG}'"
        ;;
        i ) HOOK_POSTCREATE=$OPTARG ;;
        j ) PREBUILDS="${PREBUILDS} [$OPTARG]" ;;
        k ) POSTINSTALLS="${POSTINSTALLS} [$OPTARG]" ;;
        l ) PREREMOVES="${PREREMOVES} [$OPTARG]" ;;
        m ) EXTRAINVARIANTS="$EXTRAINVARIANTS,$OPTARG" ;;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "$USERMODE" ]; then
    usage
    exit 1
fi
if [ ! "$USERMODE" = ON ] && [ ! "$USERMODE" = OFF ]; then
    usage
    printf "FATAL: Invalid -u USERMODE\n" >&2
    exit 1
fi
if [ "$USERMODE" = OFF ] && [ -z "$STATEDIR" ] && [ "$DISKUV_TOOLS_SWITCH" = OFF ]; then
    usage
    printf "FATAL: Missing -d STATEDIR or -s\n" >&2
    exit 1
fi
if [ -z "$BUILDTYPE" ] && [ -z "${DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P:-}" ]; then
    usage
    printf "FATAL: Missing -b BUILDTYPE\n" >&2
    exit 1
fi
if [ -z "${TARGET_OPAMSWITCH:-}" ] && [ -n "$STATEDIR" ]; then
    TARGET_OPAMSWITCH="$STATEDIR"
fi

# END Command line processing
# ------------------

if [ -z "${DKMLDIR:-}" ]; then
    DKMLDIR=$(dirname "$0")
    DKMLDIR=$(cd "$DKMLDIR/../.." && pwd)
fi
if [ ! -e "$DKMLDIR/.dkmlroot" ]; then printf "%s\n" "FATAL: Not embedded within or launched from a 'diskuv-ocaml' Local Project" >&2 ; exit 1; fi

# `diskuv-host-tools` is the host architecture, so use `dev` as its platform
if [ -n "$STATEDIR" ]; then
    # shellcheck disable=SC2034
    DKML_DUNE_BUILD_DIR="." # build directory will be the same as TOPDIR, not build/dev/Debug
    # shellcheck disable=SC2034
    TOPDIR="$STATEDIR"
fi

# shellcheck disable=SC1091
. "$DKMLDIR"/runtime/unix/_common_build.sh

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# --------------------------------
# BEGIN opam switch create

# Set OPAMEXE
set_opamexe

# Set DKML_POSIX_SHELL
autodetect_posix_shell

# Set NUMCPUS if unset from autodetection of CPUs
autodetect_cpus

# Set DKMLPARENTHOME_BUILDHOST
set_dkmlparenthomedir

# Set DKMLSYS_*
autodetect_system_binaries

# Get the OCaml version and check whether to build an OCaml base (ocamlc compiler, etc.)
if [ -x /usr/bin/cygpath ]; then
    # If OCAMLVERSION_OR_HOME=C:/x/y/z then match against /c/x/y/z
    OCAMLVERSION_OR_HOME_UNIX=$(/usr/bin/cygpath -u "$OCAMLVERSION_OR_HOME")
else
    OCAMLVERSION_OR_HOME_UNIX="$OCAMLVERSION_OR_HOME"
fi
case "$OCAMLVERSION_OR_HOME_UNIX" in
    /* | ?:*) # /a/b/c or C:\Windows
        validate_and_explore_ocamlhome "$OCAMLVERSION_OR_HOME"
        # the `awk ...` is dos2unix equivalent
        OCAMLVERSION=$("$DKML_OCAMLHOME_UNIX/$DKML_OCAMLHOME_BINDIR_UNIX/ocamlc" -version | awk '{ sub(/\r$/,""); print }')
        BUILD_OCAML_BASE=OFF
        ;;
    *)
        OCAMLVERSION="$OCAMLVERSION_OR_HOME"
        BUILD_OCAML_BASE=ON
        ;;
esac

# Make PINNED_PACKAGES_OPAM be version agnostic + version specific packages
OCAMLVERSION_ID=$(printf "%s" "$OCAMLVERSION" | $DKMLSYS_TR . _)
PINNED_PACKAGES_OPAM_VERSIONSPECIFIC_NAME=$(eval printf "PINNED_PACKAGES_OPAM_%s" "$OCAMLVERSION_ID")
PINNED_PACKAGES_OPAM_VERSIONSPECIFIC=$(eval echo '$'"$PINNED_PACKAGES_OPAM_VERSIONSPECIFIC_NAME")
PINNED_PACKAGES_OPAM="$PINNED_PACKAGES_OPAM_VERSIONAGNOSTIC $PINNED_PACKAGES_OPAM_VERSIONSPECIFIC"

# Set OCAML_OPTIONS if we are building the OCaml base. And if so, set
# TARGET_ variables that can be used to pick an Opam variant (OCAMLVARIANT) later.
#
# Also any "EXTRA" compiler flags. Use standard ./configure compiler flags
# (AS/ASFLAGS/CC/etc.) not OCaml ./configure compiler flags (AS/ASPP/etc.)
# any autodetect_compiler() flags will be standard ./configure flags ... and
# in a hook we'll convert them all to OCaml ./configure flags.
#
if [ "$BUILD_OCAML_BASE" = ON ]; then
    # Frame pointers enabled
    # ----------------------
    # option-fp
    # * OCaml only supports 64-bit Linux thing with either the GCC or the clang compiler.
    # * In particular the Musl GCC compiler is not supported.
    # * On Linux we need it for `perf`.
    # Confer:
    #  https://github.com/ocaml/ocaml/blob/e93f6f8e5f5a98e7dced57a0c81535481297c413/configure#L17455-L17472
    #  https://github.com/ocaml/opam-repository/blob/ed5ed7529d1d3672ed4c0d2b09611a98ec87d690/packages/ocaml-option-fp/ocaml-option-fp.1/opam#L6
    OCAML_OPTIONS=
    OPAM_SWITCH_CFLAGS=
    true > "$WORK"/invariant_for_base.formula.head.txt
    true > "$WORK"/invariant_for_base.formula.tail.txt
    case "$BUILDTYPE" in
        Debug*) BUILD_DEBUG=ON; BUILD_RELEASE=OFF ;;
        Release*) BUILD_DEBUG=OFF; BUILD_RELEASE=ON ;;
        *) BUILD_DEBUG=OFF; BUILD_RELEASE=OFF
    esac
    if [ -n "$DKMLPLATFORM" ]; then
        # We'll set compiler options to:
        # * use static builds for Linux platforms running in a (musl-based Alpine) container
        # * use flambda optimization if a `Release*` build type
        #
        # Setting compiler options via environment variables (like CC and LIBS) has been available since 4.8.0 (https://github.com/ocaml/ocaml/pull/1840)
        # but still has problems even as of 4.10.0 (https://github.com/ocaml/ocaml/issues/8648).
        #
        # The following has some of the compiler options we might use for `macos`, `linux` and `windows`:
        #   https://github.com/ocaml/opam-repository/blob/bfc07c20d6846fffa49c3c44735905af18969775/packages/ocaml-variants/ocaml-variants.4.12.0%2Boptions/opam#L17-L47
        #
        # The following is for `macos`, `android` and `ios`:
        #   https://github.com/EduardoRFS/reason-mobile/tree/master/sysroot
        #
        # Notes:
        # * `ocaml-option-musl` has a good defaults for embedded systems. But we don't want to optimize for size on a non-embedded system.
        #   Since we have fine grained information about whether we are on a tiny system (ie. ARM 32-bit) we set the CFLAGS ourselves.
        # * Advanced: You can use OCAMLPARAM through `opam config set ocamlparam` (https://github.com/ocaml/opam-repository/pull/16619) or
        #   just set it in `within-dev.sh`.
        # `is_reproducible_platform && case "$PLATFORM" in linux*) ... ;;` then
        #     # NOTE 2021/08/04: When this block is enabled we get the following error, which means the config is doing something that we don't know how to inspect ...
        #
        #     # === ERROR while compiling capnp.3.4.0 ========================================#
        #     # context     2.0.8 | linux/x86_64 | ocaml-option-static.1 ocaml-variants.4.12.0+options | https://opam.ocaml.org#8b7c0fed
        #     # path        /work/build/linux_x86_64/Debug/_opam/.opam-switch/build/capnp.3.4.0
        #     # command     /work/build/linux_x86_64/Debug/_opam/bin/dune build -p capnp -j 5
        #     # exit-code   1
        #     # env-file    /work/build/_tools/linux_x86_64/opam-root/log/capnp-1-ebe0e0.env
        #     # output-file /work/build/_tools/linux_x86_64/opam-root/log/capnp-1-ebe0e0.out
        #     # ## output ###
        #     # [...]
        #     # /work/build/linux_x86_64/Debug/_opam/.opam-switch/build/stdint.0.7.0/_build/default/lib/uint56_conv.c:172: undefined reference to `get_uint128'
        #     # /usr/lib/gcc/x86_64-alpine-linux-musl/10.3.1/../../../../x86_64-alpine-linux-musl/bin/ld: /work/build/linux_x86_64/Debug/_opam/lib/stdint/libstdint_stubs.a(uint64_conv.o): in function `uint64_of_int128':
        #     # /work/build/linux_x86_64/Debug/_opam/.opam-switch/build/stdint.0.7.0/_build/default/lib/uint64_conv.c:111: undefined reference to `get_int128'
        #
        #     # NOTE 2021/08/03: `ocaml-option-static` seems to do nothing. No difference when running `dune printenv --verbose`
        #     OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-static
        # fi
        case "$DKMLPLATFORM" in
            windows_*)    TARGET_LINUXARM32=OFF ;;
            linux_arm32*) TARGET_LINUXARM32=ON ;;
            *)            TARGET_LINUXARM32=OFF
        esac
        case "$DKMLPLATFORM" in
            *_x86 | linux_arm32*) TARGET_32BIT=ON ;;
            *) TARGET_32BIT=OFF
        esac
        case "$DKMLPLATFORM" in
            linux_x86_64) TARGET_CANENABLEFRAMEPOINTER=ON ;;
            *) TARGET_CANENABLEFRAMEPOINTER=OFF
        esac

        if [ $TARGET_LINUXARM32 = ON ]; then
            # -Os optimizes for size. Useful for CPUs with small cache sizes. Confer https://wiki.gentoo.org/wiki/GCC_optimization
            OPAM_SWITCH_CFLAGS="${OPAM_SWITCH_CFLAGS:-} -Os"
        fi
    else
        if [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = Linux ] && [ "$DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P" -eq 8 ]; then
            case "$DKML_COMPILE_CM_CMAKE_C_COMPILER_ID" in
                Clang | GNU) TARGET_CANENABLEFRAMEPOINTER=ON ;; # _not_ AppleClang
                *) TARGET_CANENABLEFRAMEPOINTER=OFF ;;
            esac
        else
            TARGET_CANENABLEFRAMEPOINTER=OFF
        fi
        if [ "$DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P" -eq 4 ]; then
            TARGET_32BIT=ON
        else
            TARGET_32BIT=OFF
        fi
    fi
    if [ $BUILD_DEBUG = ON ] && [ $TARGET_CANENABLEFRAMEPOINTER = ON ]; then
        # Frame pointer should be on in Debug mode.
        OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-fp
        printf ",'%s'" ocaml-option-fp >> "$WORK"/invariant_for_base.formula.tail.txt
    fi
    if [ "$BUILDTYPE" = ReleaseCompatPerf ] && [ $TARGET_CANENABLEFRAMEPOINTER = ON ]; then
        # If we need Linux `perf` we need frame pointers enabled
        OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-fp
        printf ",'%s'" ocaml-option-fp >> "$WORK"/invariant_for_base.formula.tail.txt
    fi
    if [ $BUILD_RELEASE = ON ]; then
        # All release builds should get flambda optimization
        OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-flambda
        printf ",'%s'" ocaml-option-flambda >> "$WORK"/invariant_for_base.formula.tail.txt
    fi
    if cmake_flag_on "${DKML_COMPILE_CM_HAVE_AFL:-OFF}" || [ "$BUILDTYPE" = ReleaseCompatFuzz ]; then
        # If we need fuzzing we must add AFL. If we have a fuzzing compiler, use AFL in OCaml.
        OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-afl
        printf ",'%s'" ocaml-option-afl >> "$WORK"/invariant_for_base.formula.tail.txt
    fi
fi

# Set OCAMLVARIANT
if [ "$BUILD_OCAML_BASE" = ON ]; then
    # use Opam base compiler, which compiles ocaml from scratch
    if is_unixy_windows_build_machine; then
        set_ocaml_variant_for_windows_switches "$OCAMLVERSION"
        if [ $TARGET_32BIT = ON ]; then
            OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS="$OCAML_VARIANT_FOR_SWITCHES_IN_32BIT_WINDOWS"
        else
            OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS="$OCAML_VARIANT_FOR_SWITCHES_IN_64BIT_WINDOWS"
        fi
        OCAMLVARIANT="$OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS"
    else
        OCAMLVARIANT="$OCAMLVERSION+options"
    fi
else
    # use Opam system compiler, which use ocaml from PATH
    OCAMLVARIANT="ocaml-system.$OCAMLVERSION"
fi


# Make launchers for opam switch create <...> and for opam <...>
if [ "$DISKUV_TOOLS_SWITCH" = ON ]; then
    # Set OPAMROOTDIR_BUILDHOST, OPAMROOTDIR_EXPAND, DKMLPLUGIN_BUILDHOST and WITHDKMLEXE_BUILDHOST
    # Set OPAMSWITCHFINALDIR_BUILDHOST and OPAMSWITCHNAME_EXPAND of `diskuv-host-tools` switch

    if [ -z "$DKMLPLATFORM" ]; then printf "%s\n" "FATAL: create-opam-switch check_state nonempty DKMLPLATFORM" >&2; exit 1; fi
    set_opamswitchdir_of_system "$DKMLPLATFORM"
    OPAM_EXEC_OPTS="-s -d '$STATEDIR' -p '$DKMLPLATFORM' -u $USERMODE -o '$OPAMHOME' -v '$OCAMLVERSION_OR_HOME'"
else
    # Set OPAMSWITCHFINALDIR_BUILDHOST, OPAMSWITCHNAME_BUILDHOST, OPAMSWITCHNAME_EXPAND, OPAMSWITCHISGLOBAL, DKMLPLUGIN_BUILDHOST and WITHDKMLEXE_BUILDHOST
    set_opamrootandswitchdir

    OPAM_EXEC_OPTS=" -p '$DKMLPLATFORM' -d '$STATEDIR' -t '$TARGET_OPAMSWITCH' -u $USERMODE -o '$OPAMHOME' -v '$OCAMLVERSION_OR_HOME'"
fi
printf "%s\n" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec.sh \\" > "$WORK"/nonswitchexec.sh
printf "%s\n" "  $OPAM_EXEC_OPTS \\" >> "$WORK"/nonswitchexec.sh
printf "%s\n" "'$DKMLDIR'/runtime/unix/platform-opam-exec.sh \\" > "$WORK"/nonswitchcall.sh
printf "%s\n" "  $OPAM_EXEC_OPTS \\" >> "$WORK"/nonswitchcall.sh

printf "%s\n" "switch create \\" > "$WORK"/switchcreateargs.sh
if [ "$YES" = ON ] && [ "${DKML_OPAM_FORCE_INTERACTIVE:-OFF}" = OFF ]; then printf "%s\n" "  --yes \\" >> "$WORK"/switchcreateargs.sh; fi
printf "%s\n" "  --jobs=$NUMCPUS \\" >> "$WORK"/switchcreateargs.sh

# Only the compiler should be created; no local .opam files will be auto-installed so that
# the `opam option` done later in this script can be set.
printf "%s\n" "  --no-install \\" >> "$WORK"/switchcreateargs.sh

# Add the extra repository, if any
FIRST_REPOS=
EXTRAREPONAMES=
add_extra_repo() {
    add_extra_repo_ARG=$1
    shift
    add_extra_repo_NAME=$(printf "%s" "$add_extra_repo_ARG" | $DKMLSYS_SED 's@=.*@@')
    add_extra_repo_REPO=$(printf "%s" "$add_extra_repo_ARG" | $DKMLSYS_SED 's@^[^=]*=@@')
    EXTRAREPONAMES="$EXTRAREPONAMES $add_extra_repo_NAME"
    FIRST_REPOS="${FIRST_REPOS}$add_extra_repo_NAME,"
    # Add it
    if [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/$add_extra_repo_NAME" ] && [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/$add_extra_repo_NAME.tar.gz" ]; then
        {
            cat "$WORK"/nonswitchexec.sh
            # `--kind local` is so we get file:/// rather than git+file:/// which would waste time with git
            case "$add_extra_repo_REPO" in
                /* | ?:* | file://) # /a/b/c or C:\Windows or file://
                    printf "  repository add %s '%s' --yes --dont-select --kind local" "$add_extra_repo_NAME" "$add_extra_repo_REPO"
                    ;;
                *)
                    printf "  repository add %s '%s' --yes --dont-select" "$add_extra_repo_NAME" "$add_extra_repo_REPO"
                    ;;
            esac
            if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
        } > "$WORK"/repoadd.sh
        log_shell "$WORK"/repoadd.sh
    fi
}
if [ -n "$EXTRAREPOCMDS" ]; then
    eval "$EXTRAREPOCMDS"
fi

if is_unixy_windows_build_machine; then
    # create fdopen-mingw-xxx-yyy as rank=2 if not already exists; rank=0 and rank=1 defined in init-opam-root.sh
    # shellcheck disable=SC2154
    if [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/fdopen-mingw-$dkml_root_version-$OCAMLVERSION" ] && [ ! -e "$OPAMROOTDIR_BUILDHOST/repo/fdopen-mingw-$dkml_root_version-$OCAMLVERSION.tar.gz" ]; then
        # Use the snapshot of fdopen-mingw (https://github.com/fdopen/opam-repository-mingw) that comes with ocaml-opam Docker image.
        # `--kind local` is so we get file:/// rather than git+file:/// which would waste time with git
        if [ -x /usr/bin/cygpath ]; then
            # shellcheck disable=SC2154
            OPAMREPOS_MIXED=$(/usr/bin/cygpath -am "$DKMLPARENTHOME_BUILDHOST\\opam-repositories\\$dkml_root_version")
        else
            OPAMREPOS_MIXED="$DKMLPARENTHOME_BUILDHOST/opam-repositories/$dkml_root_version"
        fi
        OPAMREPO_WINDOWS_OCAMLOPAM="$OPAMREPOS_MIXED/fdopen-mingw/$OCAMLVERSION"
        {
            cat "$WORK"/nonswitchexec.sh
            printf "  repository add fdopen-mingw-%s-%s '%s' --yes --dont-select --kind local --rank=2" "$dkml_root_version" "$OCAMLVERSION" "$OPAMREPO_WINDOWS_OCAMLOPAM"
            if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
        } > "$WORK"/repoadd.sh
        log_shell "$WORK"/repoadd.sh
    fi

    printf "%s\n" "  $EXTRAREPONAMES diskuv-$dkml_root_version fdopen-mingw-$dkml_root_version-$OCAMLVERSION default \\" > "$WORK"/repos-choice.lst
    printf "  --repos='%s%s' %s\n" "$FIRST_REPOS" "diskuv-$dkml_root_version,fdopen-mingw-$dkml_root_version-$OCAMLVERSION,default" "\\" >> "$WORK"/switchcreateargs.sh
else
    printf "%s\n" "  $EXTRAREPONAMES diskuv-$dkml_root_version default \\" > "$WORK"/repos-choice.lst
    printf "  --repos='%s%s' %s\n" "$FIRST_REPOS" "diskuv-$dkml_root_version,default" "\\" >> "$WORK"/switchcreateargs.sh
fi

if [ "$BUILD_OCAML_BASE" = ON ]; then
    # ex. '"ocaml-variants" {= "4.12.0+options"}'
    invariants=$(printf "ocaml-variants.%s%s\n" \
        "$OCAMLVARIANT$OCAML_OPTIONS" \
        "$EXTRAINVARIANTS"
    )
else
    # ex. '"ocaml-system" {= "4.12.1"}'
    invariants=$(printf "ocaml-system.%s%s\n" \
        "$OCAMLVERSION" \
        "$EXTRAINVARIANTS"
    )
fi
printf "  --packages='%s' %s\n" "$invariants" "\\" >> "$WORK"/switchcreateargs.sh
printf "'%s'" "$invariants" >> "$WORK"/invariant_for_base.formula.head.txt

if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s\n" "  --debug-level 2 \\" >> "$WORK"/switchcreateargs.sh; fi

{
    printf "%s\n" "#!$DKML_POSIX_SHELL"
    # Ignore any switch the developer gave. We are creating our own.
    printf "%s\n" "export OPAMSWITCH="
    printf "%s\n" "export OPAM_SWITCH_PREFIX="
    if [ -n "${OPAM_SWITCH_CFLAGS:-}" ]; then printf "export CFLAGS=\"\${CFLAGS:-} \""; escape_string_for_shell "$OPAM_SWITCH_CFLAGS"; printf "\n"; fi
    printf "exec env DKMLDIR='%s' DKML_TARGET_ABI='%s' '%s' \"\$@\"\n" "$DKMLDIR" "$DKMLPLATFORM" "$DKMLDIR/vendor/dkml-compiler/src/standard-compiler-env-to-ocaml-configure-launcher.sh"
} > "$WORK"/switch-create-prehook.sh
chmod +x "$WORK"/switch-create-prehook.sh

if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s\n" "+ ! is_minimal_opam_switch_present \"$OPAMSWITCHFINALDIR_BUILDHOST\"" >&2; fi
if ! is_minimal_opam_switch_present "$OPAMSWITCHFINALDIR_BUILDHOST"; then
    # clean up any partial install
    printf "%s\n" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec.sh $OPAM_EXEC_OPTS switch remove \\" > "$WORK"/switchremoveargs.sh
    if [ "$YES" = ON ]; then printf "%s\n" "  --yes \\" >> "$WORK"/switchremoveargs.sh; fi
    printf "  '%s'\n" "$OPAMSWITCHNAME_EXPAND" >> "$WORK"/switchremoveargs.sh
    log_shell "$WORK"/switchremoveargs.sh || rm -rf "$OPAMSWITCHFINALDIR_BUILDHOST"

    # do real install
    printf "%s\n" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec.sh $OPAM_EXEC_OPTS -0 '$WORK/switch-create-prehook.sh' \\" > "$WORK"/switchcreateexec.sh
    cat "$WORK"/switchcreateargs.sh >> "$WORK"/switchcreateexec.sh
    printf "  '%s'\n" "$OPAMSWITCHNAME_EXPAND" >> "$WORK"/switchcreateexec.sh
    log_shell "$WORK"/switchcreateexec.sh

    # the switch create already set the invariant
    NEEDS_INVARIANT=OFF
else
    # We need to upgrade each Opam switch's selected/ranked Opam repository choices whenever Diskuv OCaml
    # has an upgrade. If we don't the PINNED_PACKAGES_* may fail.
    # We know from `diskuv-$dkml_root_version` what Diskuv OCaml version the Opam switch is using, so
    # we have the logic to detect here when it is time to upgrade!
    {
        cat "$WORK"/nonswitchexec.sh
        printf "%s\n" "  repository list --short"
    } > "$WORK"/list.sh
    log_shell "$WORK"/list.sh > "$WORK"/list
    UPGRADE_REPO=OFF
    if awk -v N="diskuv-$dkml_root_version" '$1==N {exit 1}' "$WORK"/list; then
        UPGRADE_REPO=ON
    elif is_unixy_windows_build_machine && awk -v N="fdopen-mingw-$dkml_root_version-$OCAMLVERSION" '$1==N {exit 1}' "$WORK"/list; then
        UPGRADE_REPO=ON
    elif [ -n "$EXTRAREPONAMES" ]; then
        printf "%s" "$EXTRAREPONAMES" | $DKMLSYS_TR ' ' '\n' > "$WORK"/extrarepos
        while IFS= read -r _reponame; do
            if awk -v N="$_reponame" '$1==N {exit 1}' "$WORK"/list; then
                UPGRADE_REPO=ON
            fi
        done < "$WORK"/extrarepos
    fi
    if [ "$UPGRADE_REPO" = ON ]; then
        # Time to upgrade. We need to set the repository (almost instantaneous) and then
        # do a `opam update` so the switch has the latest repository definitions.
        {
            cat "$WORK"/nonswitchexec.sh
            printf "%s" "  repository set-repos"
            if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
            cat "$WORK"/repos-choice.lst
        } > "$WORK"/setrepos.sh
        log_shell "$WORK"/setrepos.sh

        {
            cat "$WORK"/nonswitchexec.sh
            printf "%s" "  update"
            if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
        } > "$WORK"/update.sh
        log_shell "$WORK"/update.sh
    fi

    # A DKML upgrade could have changed the invariant; we do not change it here; instead we wait until after
    # the pins and options (especially the wrappers) have changed because changing the invariant can recompile
    # _all_ packages (many of them need wrappers, and many of them need a pin upgrade to support a new OCaml version)
    NEEDS_INVARIANT=ON
fi

# END opam switch create
# --------------------------------

install -d "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR"

# --------------------------------
# BEGIN opam option
#
# Most of these options are tied to the $dkml_root_version, so we use $dkml_root_version
# as a cache key. If an option does not depend on the version we use ".once" as the cache
# key.

# Two operators: option setenv(OP1)"NAME OP2 VALUE"
#
# OP1
# ---
#   `=` will reset and `+=` will append (from opam option --help)
#
# OP2
# ---
#   http://opam.ocaml.org/doc/Manual.html#Environment-updates
#   `=` overrides the environment variable
#   `+=` prepends to the environment variable without adding a path separator (`;` or `:`) at the end if empty

SETPATH=

# Add PATH=<system ocaml>:$EXTRAPATH:$PATH
#   Add PATH=<system ocaml> if system ocaml. (Especially on Windows and for DKSDK, the system ocaml may not necessarily be on the system PATH)
if [ "$BUILD_OCAML_BASE" = OFF ]; then
    SETPATH="$DKML_OCAMLHOME_ABSBINDIR_BUILDHOST;$SETPATH"
fi
#   Add PATH=$EXTRAPATH
if [ -n "$EXTRAPATH" ]; then
    SETPATH="$EXTRAPATH;$SETPATH"
fi
#   Remove leading and trailing and duplicated separators
SETPATH=$(printf "%s" "$SETPATH" | $DKMLSYS_SED 's/^;*//; s/;*$//; s/;;*/;/g')
#   Add the setenv command
if [ -n "$SETPATH" ]; then
    # Use Win32 (;) or Unix (:) path separators
    if is_unixy_windows_build_machine; then
        SETPATH_WU=$SETPATH # already has semicolons
    else
        SETPATH_WU=$(printf "%s" "$SETPATH" | $DKMLSYS_TR ';' ':')
    fi
    add_do_setenv_option "PATH+=$SETPATH_WU"
fi

# Run the `var` commands
if [ -n "$DO_VARS" ]; then
    {
        printf "#!%s\n" "$DKML_POSIX_SHELL"
        printf ". '%s'\n" "$DKMLDIR"/vendor/dkml-runtime-common/unix/crossplatform-functions.sh

        # [do_setenv_option 'NAME=VALUE'] and [do_setenv_option 'NAME+=VALUE'] remove all
        # matching entries from the Opam setenv options, and then add it to the
        # Opam setenv options.
        printf "do_var() {\n"
        printf "  do_var_ARG=\$1\n"
        printf "  shift\n"
        # shellcheck disable=SC2016
        printf "  do_var_NAME=\$(%s)\n" \
            'printf "%s" "$do_var_ARG" | PATH=/usr/bin:/bin sed "s/=.*//"'
        # shellcheck disable=SC2016
        printf "  %s > '%s'/do_var_value.%s.txt\n" \
            'printf "%s" "$do_var_ARG"' \
            "$WORK" \
            '$$'
        printf "  do_var_ARG_CHKSUM=\$(sha256compute '%s'/do_var_value.%s.txt)\n" \
            "$WORK" \
            '$$'
        printf "  if [ -e '%s'/setenv-\${do_var_NAME}.\${do_var_ARG_CHKSUM}.once ]; then return 0; fi\n" \
            "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR"
        # shellcheck disable=SC2016
        printf "  do_var_VALUE=\$(%s)\n" \
            'printf "%s" "$do_var_ARG" | PATH=/usr/bin:/bin sed "s/^[^=]*=//"'
        # VALUE, since it is an OCaml value, will have escaped backslashes and quotes
        printf "  do_var_VALUE=\$(escape_arg_as_ocaml_string \"\$do_var_VALUE\")\n"

        #   Example: var ${do_var_NAME}=\"${do_var_VALUE}\""
        printf "  ";  cat "$WORK"/nonswitchcall.sh
        printf "    var \${do_var_NAME}=\\\"\${do_var_VALUE}\\\" "
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi; printf "\n"

        #       Done. Don't repeat anymore
        printf "  touch '%s'/setenv-\${do_var_NAME}.\${do_var_ARG_CHKSUM}.once\n" \
            "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR"

        printf "}\n"

        printf "%s" "$DO_VARS" ; printf "\n"
    } > "$WORK"/setvars.sh
    log_shell "$WORK"/setvars.sh
fi

# Run the `option setenv` commands
if [ -n "$DO_SETENV_OPTIONS" ]; then
    {
        printf "#!%s\n" "$DKML_POSIX_SHELL"
        printf ". '%s'\n" "$DKMLDIR"/vendor/dkml-runtime-common/unix/crossplatform-functions.sh

        printf "modifications=OFF\n"

        #   Example: opam option setenv | sed "s/]/\n/g; s/\[/\n/g" > commands_env.txt; do
        printf "rm -f '%s'/commands_env.txt\n" \
            "$WORK"
        printf "make_commands_env() {\n"
        printf "  if [ -e '%s'/commands_env.txt ]; then return 0; fi\n" \
            "$WORK"
        cat "$WORK"/nonswitchcall.sh
        printf "    option setenv | %s > '%s'/commands_env.txt\n" \
            'sed "s/]/\n/g; s/\[/\n/g"' \
            "$WORK"
        printf "}\n"

        printf "remove_setenv() {\n"
        printf "  remove_setenv_NAME=\$1\n"
        printf "  shift\n"
        printf "  remove_setenv_OP=\$1\n"
        printf "  shift\n"

        #   Example: cat commands_env.txt | awk '$1=="DKML_3P_PREFIX_PATH"{print}' | while read remove_setenv_VALUE; do
        printf "  make_commands_env\n"
        printf "  cat '%s'/commands_env.txt | awk -v \"NAME=\$remove_setenv_NAME\" -v \"OP=\$remove_setenv_OP\" '\$1==NAME && \$2==OP {print}' > '%s'/do_setenv_option_vars.%s.txt\n" \
            "$WORK" \
            "$WORK" \
            '$$'
        printf "  cat '%s'/do_setenv_option_vars.%s.txt | while IFS="" read -r remove_setenv_VALUE; do\n" \
            "$WORK" \
            '$$'
        #       Example: option setenv-="${remove_setenv_VALUE}"
        printf "    ";  cat "$WORK"/nonswitchcall.sh
        printf "      option setenv-=\"\${remove_setenv_VALUE}\"\n"
        #   Example: done
        printf "  done\n"

        printf "}\n"

        # [do_setenv_option 'NAME=VALUE'] and [do_setenv_option 'NAME+=VALUE'] remove all
        # matching entries from the Opam setenv options, and then add it to the
        # Opam setenv options.
        printf "do_setenv_option() {\n"
        printf "  do_setenv_option_ARG=\$1\n"
        printf "  shift\n"
        # shellcheck disable=SC2016
        printf "  do_setenv_option_NAME=\$(%s)\n" \
            'printf "%s" "$do_setenv_option_ARG" | PATH=/usr/bin:/bin sed "s/+*=.*//"'
        # shellcheck disable=SC2016
        printf "  do_setenv_option_OP=\$(%s)\n" \
            'printf "%s" "$do_setenv_option_ARG" | PATH=/usr/bin:/bin sed "s/^[^+=]*//; s/=.*/=/"'
        # shellcheck disable=SC2016
        printf "  %s > '%s'/do_setenv_option_value.%s.txt\n" \
            'printf "%s" "$do_setenv_option_ARG"' \
            "$WORK" \
            '$$'
        printf "  do_setenv_option_ARG_CHKSUM=\$(sha256compute '%s'/do_setenv_option_value.%s.txt)\n" \
            "$WORK" \
            '$$'
        printf "  if [ -e '%s'/setenv-\${do_setenv_option_NAME}.\${do_setenv_option_ARG_CHKSUM}.once ]; then return 0; fi\n" \
            "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR"
        # shellcheck disable=SC2016
        printf "  do_setenv_option_VALUE=\$(%s)\n" \
            'printf "%s" "$do_setenv_option_ARG" | PATH=/usr/bin:/bin sed "s/^[^=]*=//"'
        # VALUE, since it is an OCaml value, will have escaped backslashes and quotes
        printf "  do_setenv_option_VALUE=\$(escape_arg_as_ocaml_string \"\$do_setenv_option_VALUE\")\n"

        # No clean way to remove a setenv entry. We print any existing entries
        # and then remove each separately.
        printf "  remove_setenv \$do_setenv_option_NAME \$do_setenv_option_OP\n"

        #   Example: option setenv+="${do_setenv_option_NAME} = \"${do_setenv_option_VALUE}\""
        printf "  ";  cat "$WORK"/nonswitchcall.sh
        printf "    option setenv+=\"\${do_setenv_option_NAME} \$do_setenv_option_OP \\\\\"\${do_setenv_option_VALUE}\\\\\"\" "
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi; printf "\n"

        printf "  modifications=ON\n"
        #       Done. Don't repeat anymore
        printf "  touch '%s'/setenv-\${do_setenv_option_NAME}.\${do_setenv_option_ARG_CHKSUM}.once\n" \
            "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR"

        printf "}\n"

        printf "%s" "$DO_SETENV_OPTIONS" ; printf "\n"

        # Since Opam 2.1.0 (and perhaps later) do not rewrite the <switch>/environment
        # file with a `setenv+=`, we force a rebuild by removing the environment and
        # then running opam env. Confer https://github.com/ocaml/opam/pull/3691
        printf "if [ \"\$modifications\" = ON ]; then\n"
        printf "  '%s' -f '%s'\n" "$DKMLSYS_RM" "$OPAMSWITCHFINALDIR_BUILDHOST/.opam-switch/environment"
        printf "  ";  cat "$WORK"/nonswitchcall.sh
        printf "    env > /dev/null\n"
        printf "  if [ ! -e '%s' ]; then echo 'FATAL: Failed to regenerate: %s'; exit 107; fi\n" \
            "$OPAMSWITCHFINALDIR_BUILDHOST/.opam-switch/environment" \
            "$OPAMSWITCHFINALDIR_BUILDHOST/.opam-switch/environment"
        printf "fi\n"
    } > "$WORK"/setenv.sh
    log_shell "$WORK"/setenv.sh
fi

if [ "$DISKUV_TOOLS_SWITCH" = OFF ] && \
        [ ! -e "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/$WRAP_COMMANDS_CACHE_KEY" ]; then
    # We can't put with-dkml.exe into Diskuv System switches because with-dkml.exe currently needs a system switch to compile itself.
    printf "%s" "$WITHDKMLEXE_BUILDHOST" | sed 's/\\/\\\\/g' > "$WORK"/dow.path
    DOW_PATH=$(cat "$WORK"/dow.path)
    {
        cat "$WORK"/nonswitchexec.sh
        printf "  option wrap-build-commands='[\"%s\"]' " "$DOW_PATH"
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
    } > "$WORK"/wbc.sh
    log_shell "$WORK"/wbc.sh
    {
        cat "$WORK"/nonswitchexec.sh
        printf "  option wrap-install-commands='[\"%s\"]' " "$DOW_PATH"
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
    } > "$WORK"/wbc.sh
    log_shell "$WORK"/wbc.sh
    {
        cat "$WORK"/nonswitchexec.sh
        printf "  option wrap-remove-commands='[\"%s\"]' " "$DOW_PATH"
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
    } > "$WORK"/wbc.sh
    log_shell "$WORK"/wbc.sh

    # Done. Don't repeat anymore
    touch "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/$WRAP_COMMANDS_CACHE_KEY"
fi

option_command() {
    option_command_OPTION=$1
    shift
    option_command_VALUE=$1
    shift
    printf "%s|%s" "$dkml_root_version" "$option_command_VALUE" > "$WORK"/"$option_command_OPTION".key
    option_command_CACHE_KEY="$option_command_OPTION"."$dkml_root_version".$(sha256compute "$WORK"/"$option_command_OPTION".key)
    if [ ! -e "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/$option_command_CACHE_KEY" ]; then
        option_command_ESCAPED=$(escape_args_for_shell "$option_command_VALUE")
        {
            cat "$WORK"/nonswitchexec.sh
            printf "  option %s=[%s] " "$option_command_OPTION" "$option_command_ESCAPED"
            if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
        } > "$WORK"/option-"$option_command_OPTION".sh
        log_shell "$WORK"/option-"$option_command_OPTION".sh

        # Done. Don't repeat anymore
        touch "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/$option_command_CACHE_KEY"
    fi
}
option_command pre-build-commands "$PREBUILDS"
option_command post-install-commands "$POSTINSTALLS"
option_command pre-remove-commands "$PREREMOVES"

# END opam option
# --------------------------------

# --------------------------------
# BEGIN opam pin add
#
# Since opam pin add is way too slow for hundreds of pins, we directly add the pins to the
# switch-state file. And since as an escape hatch we want developer to be able to override
# the pins, we only insert the pins if there are no other pins.
# The only thing we force pin is ocaml-variants if we are on Windows.
#
# Also, the pins are tied to the $dkml_root_version, so we use $dkml_root_version
# as a cache key. When the cache key changes (aka an upgrade) the pins are reset.

# Set DKML_POSIX_SHELL
autodetect_posix_shell

# Set DKMLPARENTHOME_BUILDHOST
set_dkmlparenthomedir

# We insert our pins if no pinned: [ ] section
# OR it is empty like:
#   pinned: [
#   ]
# OR the dkml_root_version changed
get_opam_switch_state_toplevelsection "$OPAMSWITCHFINALDIR_BUILDHOST" pinned > "$WORK"/pinned
PINNED_NUMLINES=$(awk 'END{print NR}' "$WORK"/pinned)
if [ "$PINNED_NUMLINES" -le 2 ] || ! [ -e "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/pins-set.$dkml_root_version" ]; then
    # The pins have to be sorted
    {
        # Input: dune-configurator,2.9.0
        # Output:  "dune-configurator.2.9.0"
        printf "%s" "$PINNED_PACKAGES_DKML_PATCHES $PINNED_PACKAGES_OPAM" | xargs -n1 printf '  "%s"\n' | sed 's/,/./'

        # fdopen-mingw has pins that must be used since we've trimmed the fdopen repository
        if is_unixy_windows_build_machine; then
            # Input: opam pin add --yes --no-action -k version "0install" "2.17"
            # Input (older versions): opam pin add --yes --no-action -k version 0install 2.17
            # Output:   "0install.2.17"
            # Caution: `tr` on MSYS2 only operates on standard input and output; no named file argument.
            tr -d '"' < "$DKMLPARENTHOME_BUILDHOST/opam-repositories/$dkml_root_version/fdopen-mingw/$OCAMLVERSION/pins.txt" | \
            awk -v dquot='"' 'NF>=2 { l2=NF-1; l1=NF; print "  " dquot $l2 "." $l1 dquot}'
        fi
    } | sort > "$WORK"/new-pinned

    # The pins should also be unique
    sort -u "$WORK"/new-pinned > "$WORK"/new-pinned.uniq
    if ! cmp -s "$WORK"/new-pinned "$WORK"/new-pinned.uniq; then
        printf "%s\n" "FATAL: The pins should be unique! Instead we have some duplicated entries that may lead to problems:" >&2
        diff "$WORK"/new-pinned "$WORK"/new-pinned.uniq >&2 || true
        printf "%s\n" "(Debugging) PINNED_PACKAGES_DKML_PATCHES=$PINNED_PACKAGES_DKML_PATCHES" >&2
        printf "%s\n" "(Debugging) PINNED_PACKAGES_OPAM=$PINNED_PACKAGES_OPAM" >&2
        printf "%s\n" "(Debugging) Pins at '$DKMLPARENTHOME_BUILDHOST/opam-repositories/$dkml_root_version/fdopen-mingw/$OCAMLVERSION/pins.txt'" >&2
        exit 1
    fi

    # Make the new switch state
    {
        # everything except any old pinned section
        delete_opam_switch_state_toplevelsection "$OPAMSWITCHFINALDIR_BUILDHOST" pinned

        printf "%s\n" 'pinned: ['
        cat "$WORK"/new-pinned
        printf "%s\n" ']'
    } > "$WORK"/new-switch-state

    # Reset the switch state
    mv "$WORK"/new-switch-state "$OPAMSWITCHFINALDIR_BUILDHOST"/.opam-switch/switch-state

    # Done for this DKML version
    touch "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/pins-set.$dkml_root_version"
fi

# For Windows when we need to build an OCaml base, mimic the ocaml-opam Dockerfile by pinning `ocaml-variants` to our custom version
if [ "$BUILD_OCAML_BASE" = ON ] && is_unixy_windows_build_machine; then
    if ! get_opam_switch_state_toplevelsection "$OPAMSWITCHFINALDIR_BUILDHOST" pinned | grep -q "ocaml-variants.$OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS"; then
        OPAM_PIN_ADD_ARGS="pin add"
        if [ "$YES" = ON ]; then OPAM_PIN_ADD_ARGS="$OPAM_PIN_ADD_ARGS --yes"; fi
        {
            cat "$WORK"/nonswitchexec.sh
            printf "%s" "  ${OPAM_PIN_ADD_ARGS} -k version ocaml-variants '$OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS'"
        } > "$WORK"/pinadd.sh
        log_shell "$WORK"/pinadd.sh
    fi
fi

# END opam pin add
# --------------------------------

# --------------------------------
# BEGIN opam post create hook

if [ -n "$HOOK_POSTCREATE" ]; then
    HOOK_KEY_POSTCREATE=$(sha256compute "$HOOK_POSTCREATE")
    if [ ! -e "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/hook-postcreate.$dkml_root_version.$HOOK_KEY_POSTCREATE" ]; then
        # If Windows, expect the commands to be executed in Windows/DOS context,
        # not a MSYS2 context. So use mixed and host paths rather than Unix paths.
        if [ -x /usr/bin/cygpath ]; then
            DKMLSYS_ENV_MIXED=$(/usr/bin/cygpath -am "$DKMLSYS_ENV")
        else
            DKMLSYS_ENV_MIXED=$DKMLSYS_ENV
        fi
        {
            cat "$WORK"/nonswitchexec.sh
            printf "  exec -- '%s' 'OPAMEXE=%s' '__INTERNAL__DKMLDIR=%s' '%s' '%s'" "$DKMLSYS_ENV_MIXED" "$OPAMEXE" "$DKMLDIR" "$DKML_HOST_POSIX_SHELL" "$HOOK_POSTCREATE"
        } > "$WORK"/postcreate.sh
        log_shell "$WORK"/postcreate.sh

        # Done until the next DKML version or the next update to the hook
        touch "$OPAMSWITCHFINALDIR_BUILDHOST/$OPAM_CACHE_SUBDIR/hook-postcreate.$dkml_root_version.$HOOK_KEY_POSTCREATE"
    fi
fi

# END opam post create hook
# --------------------------------

# --------------------------------
# BEGIN opam switch set-invariant

if [ "$NEEDS_INVARIANT" = ON ]; then
    # We also should change the switch invariant if an upgrade occurred. The best way to detect
    # that we need to upgrade after the switch invariant change is to see if the switch-config changed
    OLD_HASH=$(sha256compute "$OPAMSWITCHFINALDIR_BUILDHOST/.opam-switch/switch-config")
    {
        cat "$WORK"/nonswitchexec.sh
        printf "  switch set-invariant --packages="
        if [ "$BUILD_OCAML_BASE" = ON ]; then
            cat "$WORK"/invariant_for_base.formula.head.txt
            cat "$WORK"/invariant_for_base.formula.tail.txt
        else
            printf "'ocaml-system.%s%s'" "$OCAMLVERSION" "$EXTRAINVARIANTS"
        fi
    } > "$WORK"/set-invariant.sh
    log_shell "$WORK"/set-invariant.sh

    NEW_HASH=$(sha256compute "$OPAMSWITCHFINALDIR_BUILDHOST/.opam-switch/switch-config")
    if [ ! "$OLD_HASH" = "$NEW_HASH" ]; then
        {
            cat "$WORK"/nonswitchexec.sh
            printf "  upgrade --fixup"
            if [ "$YES" = ON ]; then printf " --yes"; fi
            if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s" " --debug-level 2"; fi
        } > "$WORK"/upgrade.sh
        log_shell "$WORK"/upgrade.sh
    fi
fi

# END opam switch set-invariant
# --------------------------------
