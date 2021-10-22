#!/bin/sh
# -------------------------------------------------------
# create-opam-switch.sh [-b BUILDTYPE -p PLATFORM | [-b BUILDTYPE] -s]
#
# Purpose:
# 1. Create an OPAMSWITCH (`opam switch create`) as
#    a local switch that corresponds to the PLATFORM's BUILDTYPE
#    or to the 'diskuv-system' switch. The created switch will have a working
#    OCaml system compiler.
#
# Prerequisites:
# * An OPAMROOT created by `init-opam-root.sh`
#
# -------------------------------------------------------
set -euf

# ------
# pinned
# ------
#
# The format is `PACKAGE_NAME,PACKAGE_VERSION`. Notice the **comma** inside the quotes!

# These MUST BE IN SYNC with installtime\unix\private\reproducible-fetch-ocaml-opam-repo-9-trim.sh's PACKAGES_TO_REMOVE.
# Summary: DKML provides patches for these
PINNED_PACKAGES_DKML_PATCHES="
    dune-configurator,2.9.0
    bigstringaf,0.8.0
    ppx_expect,v0.14.1
    digestif,1.0.1
    ocp-indent,1.8.2-windowssupport
    mirage-crypto,0.10.4-windowssupport
    mirage-crypto-ec,0.10.4-windowssupport
    mirage-crypto-pk,0.10.4-windowssupport
    mirage-crypto-rng,0.10.4-windowssupport
    mirage-crypto-rng-async,0.10.4-windowssupport
    mirage-crypto-rng-mirage,0.10.4-windowssupport
    ocamlbuild,0.14.0
    core_kernel,v0.14.2
    feather,0.3.0
    ctypes,0.19.2-windowssupport-r4
    ctypes-foreign,0.19.2-windowssupport-r4
    "

# These MUST BE IN SYNC with installtime\unix\private\reproducible-fetch-ocaml-opam-repo-9-trim.sh's PACKAGES_TO_REMOVE.
# Summary: Packages which need to be pinned and come from the central Opam repository.
#
# Callouts:
# * ppxlib incorrectly did not use a major version bump and caused major breaking changes to downstream packages.
#   That is, ppxlib.0.23.0 breaks ppx_variants_conv.v0.14.1. PR to fix is https://github.com/janestreet/ppx_variants_conv/pull/9
# * ocamlformat-rpc-lib,0.18.0 may be needed (it is part of the good set), but since everything else is 0.19.0 we unpin it.
# * ocaml-compiler-libs,v0.12.4 and jst-config,v0.14.1 and dune-build-info,2.9.1 are part of the good set, but not part of the fdopen repository snapshot. So we remove it in
#   reproducible-fetch-ocaml-opam-repo-9-trim.sh so the default Opam repository is used.
PINNED_PACKAGES_OPAM="
    ppxlib,0.22.0

    "

# ------------------
# BEGIN Command line processing

usage() {
    echo "Creates a local Opam switch with a working compiler.">&2
    echo "  Will pre-pin package versions based on the installed Diskuv OCaml distribution." >&2
    echo "  Will set switch options pin package versions needed to compile on Windows." >&2
    echo "Usage:" >&2
    echo "    create-opam-switch.sh -h                                   Display this help message" >&2
    echo "    create-opam-switch.sh -b BUILDTYPE -p PLATFORM             (Deprecated) Create the Opam switch" >&2
    echo "    create-opam-switch.sh [-u OFF] -b BUILDTYPE -d OPAMSWITCH  Create the Opam switch in directory OPAMSWITCH/_opam" >&2
    echo "    create-opam-switch.sh [-b BUILDTYPE] -s                    Expert. Create the diskuv-system switch" >&2
    echo "Options:" >&2
    echo "    -p PLATFORM: The target platform or 'dev'" >&2
    echo "    -d OPAMSWITCH: The target Opam switch. A subdirectory _opam will be created for your Opam switch" >&2
    echo "    -s: Select the 'diskuv-system' switch" >&2
    echo "    -b BUILDTYPE: The build type which is one of:" >&2
    echo "        Debug" >&2
    echo "        Release - Most optimal code. Should be faster than ReleaseCompat* builds" >&2
    echo "        ReleaseCompatPerf - Compatibility with 'perf' monitoring tool." >&2
    echo "        ReleaseCompatFuzz - Compatibility with 'afl' fuzzing tool." >&2
    echo "    -u ON|OFF: User mode. If OFF, sets Opam --root to <STATEDIR>/opam." >&2
    echo "       Defaults to ON; ie. using Opam 2.2+ default root" >&2
    echo "    -y Say yes to all questions" >&2
    echo "Post Create Switch Hook:" >&2
    echo "    If (-d OPAMSWITCH) is specified, and OPAMSWITCH/buildconfig/opam/hook-switch-postcreate.txt exists," >&2
    echo "    then the Opam commands in hook-switch-postcreate.txt will be executed." >&2
    echo "    If (-d OPAMSWITCH) is not specified, and <top>/buildconfig/opam/hook-switch-postcreate.txt exists where," >&2
    echo "    the <top> directory contains dune-project, then the Opam commands in hook-switch-postcreate.txt" >&2
    echo "    will be executed." >&2
    echo "    The Opam commands should be platform-neutral, and will be executed after the switch has been initially" >&2
    echo "    created with a minimal OCaml compiler, and after DKML pins and options are set for the switch." >&2
    echo "    Example: opam pin add --yes opam-lib https://github.com/ocaml/opam.git#1.2" >&2
}

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    PLATFORM=
fi
BUILDTYPE=
DISKUV_SYSTEM_SWITCH=OFF
STATEDIR=
YES=OFF
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    USERMODE=OFF
else
    USERMODE=ON
fi
while getopts ":h:b:p:sd:uy" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            PLATFORM=$OPTARG
        ;;
        b )
            BUILDTYPE=$OPTARG
        ;;
        s )
            DISKUV_SYSTEM_SWITCH=ON
        ;;
        d)
            STATEDIR=$OPTARG
        ;;
        u )
            # shellcheck disable=SC2034
            USERMODE=$OPTARG
        ;;
        y)
            YES=ON
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    if [ -z "$STATEDIR" ] && [ -z "$PLATFORM" ] && [ "$DISKUV_SYSTEM_SWITCH" = OFF ]; then
        usage
        exit 1
    elif [ -n "$STATEDIR" ] && [ -z "$BUILDTYPE" ]; then
        usage
        exit 1
    elif [ -n "$PLATFORM" ] && [ -z "$BUILDTYPE" ]; then
        usage
        exit 1
    fi
else
    if [ -z "$STATEDIR" ] && [ "$DISKUV_SYSTEM_SWITCH" = OFF ]; then
        usage
        exit 1
    elif [ -n "$STATEDIR" ] && [ -z "$BUILDTYPE" ]; then
        usage
        exit 1
    fi
fi

# END Command line processing
# ------------------

if [ -z "${DKMLDIR:-}" ]; then
    DKMLDIR=$(dirname "$0")
    DKMLDIR=$(cd "$DKMLDIR/../.." && pwd)
fi
if [ ! -e "$DKMLDIR/.dkmlroot" ]; then echo "FATAL: Not embedded within or launched from a 'diskuv-ocaml' Local Project" >&2 ; exit 1; fi

# `diskuv-system` is the host architecture, so use `dev` as its platform
if [ "$DISKUV_SYSTEM_SWITCH" = ON ]; then
    if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
        PLATFORM=dev
    fi
fi
if [ -n "$STATEDIR" ]; then
    if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
        PLATFORM=dev
    fi
    # shellcheck disable=SC2034
    DKML_DUNE_BUILD_DIR="." # build directory will be the same as TOPDIR, not build/dev/Debug
    # shellcheck disable=SC2034
    TOPDIR_CANDIDATE="$STATEDIR"
fi

# shellcheck disable=SC1091
if [ -n "${BUILDTYPE:-}" ] || [ -n "${DKML_DUNE_BUILD_DIR:-}" ] || [ -n "${STATEDIR:-}" ]; then
    # shellcheck disable=SC1091
    . "$DKMLDIR"/runtime/unix/_common_build.sh
else
    # shellcheck disable=SC1091
    . "$DKMLDIR"/runtime/unix/_common_tool.sh
fi

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# --------------------------------
# BEGIN opam switch create

# Set NUMCPUS if unset from autodetection of CPUs
autodetect_cpus

# Set BUILDHOST_ARCH
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    build_machine_arch
    if [ "$PLATFORM" = dev ]; then
        TARGET_ARCH=$BUILDHOST_ARCH
    else
        TARGET_ARCH=$PLATFORM
    fi
fi

# Set $DiskuvOCamlHome and other vars
autodetect_dkmlvars || true

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
OPAM_SWITCH_CC=
OPAM_SWITCH_ASPP=
OPAM_SWITCH_AS=
case "$BUILDTYPE" in
    Debug*) BUILD_DEBUG=ON; BUILD_RELEASE=OFF ;;
    Release*) BUILD_DEBUG=OFF; BUILD_RELEASE=ON ;;
    *) BUILD_DEBUG=OFF; BUILD_RELEASE=OFF
esac
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
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
    #   just set it in `within-dev` or `sandbox-entrypoint.sh`.
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
    case "$TARGET_ARCH" in
        windows_*)    TARGET_LINUXARM32=OFF ;;
        linux_arm32*) TARGET_LINUXARM32=ON ;;
        *)            TARGET_LINUXARM32=OFF
    esac
    case "$TARGET_ARCH" in
        *_x86 | linux_arm32*) TARGET_32BIT=ON ;;
        *) TARGET_32BIT=OFF
    esac
    case "$TARGET_ARCH" in
        linux_x86_64) TARGET_CANENABLEFRAMEPOINTER=ON ;;
        *) TARGET_CANENABLEFRAMEPOINTER=OFF
    esac

    if [ $TARGET_LINUXARM32 = ON ]; then
        # -Os optimizes for size. Useful for CPUs with small cache sizes. Confer https://wiki.gentoo.org/wiki/GCC_optimization
        OPAM_SWITCH_CFLAGS="$OPAM_SWITCH_CFLAGS -Os"
    fi
else
    if [ "$DKSDK_CMAKEVAL_CMAKE_SYSTEM_NAME" = Linux ] && [ "$DKSDK_CMAKEVAL_CMAKE_SIZEOF_VOID_P" = 8 ]; then
        case "$DKSDK_CMAKEVAL_CMAKE_C_COMPILER_ID" in
            Clang | GNU) TARGET_CANENABLEFRAMEPOINTER=ON ;; # _not_ AppleClang
            *) TARGET_CANENABLEFRAMEPOINTER=OFF ;;
        esac
    else
        TARGET_CANENABLEFRAMEPOINTER=OFF
    fi
    if [ "$DKSDK_CMAKEVAL_CMAKE_SIZEOF_VOID_P" = 4 ]; then
        TARGET_32BIT=ON
    else
        TARGET_32BIT=OFF
    fi

    # example command: _CMAKE_C_FLAGS_FOR_CONFIG="$DKSDK_CMAKEVAL_CMAKE_C_FLAGS_DEBUG"
    _DKSDK_CONFIG_UPPER=$(printf "%s" "$DKSDK_CONFIG" | tr '[:lower:]' '[:upper:]')
    printf "_CMAKE_C_FLAGS_FOR_CONFIG=\"\$DKSDK_CMAKEVAL_CMAKE_C_FLAGS_%s\"" "$_DKSDK_CONFIG_UPPER" > "$WORK"/cflags.source
    # shellcheck disable=SC1091
    . "$WORK"/cflags.source

    OPAM_SWITCH_CFLAGS="$OPAM_SWITCH_CFLAGS $DKSDK_CMAKEVAL_CMAKE_C_FLAGS $_CMAKE_C_FLAGS_FOR_CONFIG"
    OPAM_SWITCH_CC="$DKSDK_CMAKEVAL_CMAKE_C_COMPILER"
    OPAM_SWITCH_ASPP= # CMake does not give options to tell you how to generate preprocessor printout. OCaml ./configure should be able to figure it out
    OPAM_SWITCH_AS=
    if [ -n "$DKSDK_CMAKEVAL_CMAKE_ASM_MASM_COMPILER" ]; then
        OPAM_SWITCH_AS="$DKSDK_CMAKEVAL_CMAKE_ASM_MASM_COMPILER"
    elif [ -n "$DKSDK_CMAKEVAL_CMAKE_ASM_COMPILER" ]; then
        OPAM_SWITCH_AS="$DKSDK_CMAKEVAL_CMAKE_ASM_COMPILER"
    fi
    if cmake_flag_on "$DKSDK_CMAKEVAL_MSVC"; then
        # Never print Microsoft logo (unneeded; set by OCaml ./configure)
        # [ -n "$OPAM_SWITCH_CC" ] && OPAM_SWITCH_CC="$OPAM_SWITCH_CC /nologo"
        # [ -n "$OPAM_SWITCH_ASPP" ] && OPAM_SWITCH_ASPP="$OPAM_SWITCH_ASPP /nologo"
        # [ -n "$OPAM_SWITCH_AS" ] && OPAM_SWITCH_AS="$OPAM_SWITCH_AS /nologo"
        # Always use dash (-) form of options rather than slash (/) options. Makes MSYS2 not try
        # to think the option is a filepath and try to translate it.
        OPAM_SWITCH_CFLAGS=$(printf "%s" "$OPAM_SWITCH_CFLAGS" | sed 's# /# -#g')
        OPAM_SWITCH_CC=$(printf "%s" "$OPAM_SWITCH_CC" | sed 's# /# -#g')
        OPAM_SWITCH_ASPP=$(printf "%s" "$OPAM_SWITCH_ASPP" | sed 's# /# -#g')
        OPAM_SWITCH_AS=$(printf "%s" "$OPAM_SWITCH_AS" | sed 's# /# -#g')
    fi
fi
if [ $BUILD_DEBUG = ON ] && [ $TARGET_CANENABLEFRAMEPOINTER = ON ]; then
    # Frame pointer should be on in Debug mode.
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-fp
fi
if [ "$BUILDTYPE" = ReleaseCompatPerf ] && [ $TARGET_CANENABLEFRAMEPOINTER = ON ]; then
    # If we need Linux `perf` we need frame pointers enabled
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-fp
fi
if [ $BUILD_RELEASE = ON ]; then
    # All release builds should get flambda optimization
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-flambda
fi
if cmake_flag_on "${DKSDK_HAVE_AFL:-OFF}" || [ "$BUILDTYPE" = ReleaseCompatFuzz ]; then
    # If we need fuzzing we must add AFL. If we have a fuzzing compiler, use AFL in OCaml.
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-afl
fi
if [ $TARGET_32BIT = ON ]; then
    OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS="$OCAML_VARIANT_FOR_SWITCHES_IN_32BIT_WINDOWS"
else
    OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS="$OCAML_VARIANT_FOR_SWITCHES_IN_64BIT_WINDOWS"
fi

# Make launchers for opam switch create <...> and for opam <...>
OPAM_SWITCH_CREATE_PREHOOK=
if [ "$DISKUV_SYSTEM_SWITCH" = ON ]; then
    # Set OPAMROOTDIR_BUILDHOST, OPAMROOTDIR_EXPAND, DKMLPLUGIN_BUILDHOST and WITHDKMLEXE_BUILDHOST
    set_opamrootdir

    # Set OPAMSWITCHFINALDIR_BUILDHOST and OPAMSWITCHDIR_EXPAND of `diskuv-system` switch
    set_opamswitchdir_of_system

    OPAM_EXEC_OPTS="-s"
else
    if [ -z "${BUILDTYPE:-}" ]; then echo "check_state nonempty BUILDTYPE" >&2; exit 1; fi
    # Set OPAMSWITCHFINALDIR_BUILDHOST, OPAMSWITCHNAME_BUILDHOST, OPAMSWITCHDIR_EXPAND, OPAMSWITCHISGLOBAL, DKMLPLUGIN_BUILDHOST and WITHDKMLEXE_BUILDHOST
    set_opamrootandswitchdir

    if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
        OPAM_EXEC_OPTS="-p $PLATFORM"
        if [ -n "$STATEDIR" ]; then
            OPAM_EXEC_OPTS="$OPAM_EXEC_OPTS -t $STATEDIR"
        else
            OPAM_EXEC_OPTS="$OPAM_EXEC_OPTS -b $BUILDTYPE"
        fi
    else
        OPAM_EXEC_OPTS="  -d '$STATEDIR' -u $USERMODE"
    fi
fi
printf "%s\n" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec \\" > "$WORK"/nonswitchexec.sh
printf "%s\n" "  $OPAM_EXEC_OPTS \\" >> "$WORK"/nonswitchexec.sh

printf "%s\n" "switch create \\" > "$WORK"/switchcreateargs.sh
if [ "$YES" = ON ]; then printf "%s\n" "  --yes \\" >> "$WORK"/switchcreateargs.sh; fi
printf "%s\n" "  --jobs=$NUMCPUS \\" >> "$WORK"/switchcreateargs.sh

# Only the compiler should be created; no local .opam files will be auto-installed so that
# the `opam option` done later in this script can be set.
printf "%s\n" "  --no-install \\" >> "$WORK"/switchcreateargs.sh

if is_unixy_windows_build_machine; then
    # shellcheck disable=SC2154
    printf "%s\n" "  diskuv-$dkml_root_version fdopen-mingw-$dkml_root_version default \\" > "$WORK"/repos-choice.lst
    printf "%s\n" "  --repos='diskuv-$dkml_root_version,fdopen-mingw-$dkml_root_version,default' \\" >> "$WORK"/switchcreateargs.sh
    printf "%s\n" "  --packages='ocaml-variants.$OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS$OCAML_OPTIONS' \\" >> "$WORK"/switchcreateargs.sh
else
    printf "%s\n" "  diskuv-$dkml_root_version default \\" > "$WORK"/repos-choice.lst
    printf "%s\n" "  --repos='diskuv-$dkml_root_version,default' \\" >> "$WORK"/switchcreateargs.sh
    printf "%s\n" "  --packages='ocaml-variants.4.12.0+options$OCAML_OPTIONS' \\" >> "$WORK"/switchcreateargs.sh
fi
if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then printf "%s\n" "  --debug-level 2 \\" >> "$WORK"/switchcreateargs.sh; fi

# We'll use the bash builtin `set` which quotes spaces correctly.
OPAM_SWITCH_CREATE_PREHOOK="echo OPAMSWITCH=; echo OPAM_SWITCH_PREFIX=" # Ignore any switch the developer gave. We are creating our own.
if [ -n "${OPAM_SWITCH_CFLAGS:-}" ]; then OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';'; CFLAGS='$OPAM_SWITCH_CFLAGS'; set | grep ^CFLAGS="; fi
if [ -n "${OPAM_SWITCH_CC:-}" ]; then     OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';';     CC='$OPAM_SWITCH_CC'    ; set | grep ^CC="; fi
if [ -n "${OPAM_SWITCH_ASPP:-}" ]; then   OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';';   ASPP='$OPAM_SWITCH_ASPP'  ; set | grep ^ASPP="; fi
if [ -n "${OPAM_SWITCH_AS:-}" ]; then     OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';';     AS='$OPAM_SWITCH_AS'    ; set | grep ^AS="; fi

if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then printf "%s\n" "+ ! is_minimal_opam_switch_present \"$OPAMSWITCHFINALDIR_BUILDHOST\"" >&2; fi
if ! is_minimal_opam_switch_present "$OPAMSWITCHFINALDIR_BUILDHOST"; then
    # clean up any partial install
    printf "%s\n" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec $OPAM_EXEC_OPTS switch remove \\" > "$WORK"/switchremoveargs.sh
    if [ "$YES" = ON ]; then printf "%s\n" "  --yes \\" >> "$WORK"/switchremoveargs.sh; fi
    printf "  '%s'\n" "$OPAMSWITCHDIR_EXPAND" >> "$WORK"/switchremoveargs.sh
    log_shell "$WORK"/switchremoveargs.sh || rm -rf "$OPAMSWITCHFINALDIR_BUILDHOST"

    # do real install
    printf "%s\n" "exec '$DKMLDIR'/runtime/unix/platform-opam-exec $OPAM_EXEC_OPTS -1 '$OPAM_SWITCH_CREATE_PREHOOK' \\" > "$WORK"/switchcreateexec.sh
    cat "$WORK"/switchcreateargs.sh >> "$WORK"/switchcreateexec.sh
    printf "  '%s'\n" "$OPAMSWITCHDIR_EXPAND" >> "$WORK"/switchcreateexec.sh
    log_shell "$WORK"/switchcreateexec.sh
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
    if awk -v N="diskuv-$dkml_root_version" '$1==N {exit 1}' "$WORK"/list; then
        # Time to upgrade. We need to set the repository (almost instantaneous) and then
        # do a `opam update` so the switch has the latest repository definitions.
        {
            cat "$WORK"/nonswitchexec.sh
            printf "%s" "  repository set-repos"
            if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then printf "%s" " --debug-level 2"; fi
            cat "$WORK"/repos-choice.lst
        } > "$WORK"/setrepos.sh
        log_shell "$WORK"/setrepos.sh

        {
            cat "$WORK"/nonswitchexec.sh
            printf "%s" "  update"
            if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then printf "%s" " --debug-level 2"; fi
        } > "$WORK"/update.sh
        log_shell "$WORK"/update.sh
    fi
fi

# END opam switch create
# --------------------------------

install -d "$OPAMSWITCHFINALDIR_BUILDHOST"/.dkml/opam-cache

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
#   `+=` prepends to the environment variable without adding a path separator (`;` or `:`) at the end if empty
#
# NAME
# ----
# 1. LUV_USE_SYSTEM_LIBUV=yes if Windows which uses vcpkg. See https://github.com/aantron/luv#external-libuv

if is_unixy_windows_build_machine && [ ! -e "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/setenv-LUV_USE_SYSTEM_LIBUV.once" ]; then
    {
        cat "$WORK"/nonswitchexec.sh
        printf "%s" "  option setenv+='LUV_USE_SYSTEM_LIBUV += \"yes\"' "
    } > "$WORK"/setenv.sh
    log_shell "$WORK"/setenv.sh

    # Done. Don't repeat anymore
    touch "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/setenv-LUV_USE_SYSTEM_LIBUV.once"
fi

if [ "$DISKUV_SYSTEM_SWITCH" = OFF ] && \
        [ ! -e "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/wrap-commands.$dkml_root_version" ]; then
    # We can't put with-dkml.exe into Diskuv System switches because with-dkml.exe currently needs a system switch to compile itself.
    printf "%s" "$WITHDKMLEXE_BUILDHOST" | sed 's/\\/\\\\/g' > "$WORK"/dow.path
    DOW_PATH=$(cat "$WORK"/dow.path)
    {
        cat "$WORK"/nonswitchexec.sh
        printf "  option wrap-build-commands='[\"%s\"]' " "$DOW_PATH"
    } > "$WORK"/wbc.sh
    log_shell "$WORK"/wbc.sh
    {
        cat "$WORK"/nonswitchexec.sh
        printf "  option wrap-install-commands='[\"%s\"]' " "$DOW_PATH"
    } > "$WORK"/wbc.sh
    log_shell "$WORK"/wbc.sh
    {
        cat "$WORK"/nonswitchexec.sh
        printf "  option wrap-remove-commands='[\"%s\"]' " "$DOW_PATH"
    } > "$WORK"/wbc.sh
    log_shell "$WORK"/wbc.sh

    # Done. Don't repeat anymore
    touch "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/wrap-commands.$dkml_root_version"
fi

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
if [ "$PINNED_NUMLINES" -le 2 ] || ! [ -e "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/pins-set.$dkml_root_version" ]; then
    # The pins have to be sorted
    {
        # Input: dune-configurator,2.9.0
        # Output:  "dune-configurator.2.9.0"
        printf "%s" "$PINNED_PACKAGES_DKML_PATCHES $PINNED_PACKAGES_OPAM" | xargs -n1 printf '  "%s"\n' | sed 's/,/./'

        # fdopen-mingw has pins that must be used since we've trimmed the fdopen repository
        if is_unixy_windows_build_machine; then
            # Input: opam pin add --yes --no-action -k version 0install 2.17
            # Output:   "0install.2.17"
            awk -v dquot='"' 'NF>=2 { l2=NF-1; l1=NF; print "  " dquot $l2 "." $l1 dquot}' "$DKMLPARENTHOME_BUILDHOST/opam-repositories/$dkml_root_version"/fdopen-mingw/pins.txt
        fi
    } | sort > "$WORK"/new-pinned

    # The pins should also be unique
    sort -u "$WORK"/new-pinned > "$WORK"/new-pinned.uniq
    if ! cmp -s "$WORK"/new-pinned "$WORK"/new-pinned.uniq; then
        printf "%s\n" "FATAL: The pins should be unique! Instead we have some duplicated entries that may lead to problems:" >&2
        diff "$WORK"/new-pinned "$WORK"/new-pinned.uniq >&2 || true
        printf "%s\n" "(Debugging) PINNED_PACKAGES_DKML_PATCHES=$PINNED_PACKAGES_DKML_PATCHES" >&2
        printf "%s\n" "(Debugging) PINNED_PACKAGES_OPAM=$PINNED_PACKAGES_OPAM" >&2
        printf "%s\n" "(Debugging) Pins at '$DKMLPARENTHOME_BUILDHOST/opam-repositories/$dkml_root_version/fdopen-mingw/pins.txt'" >&2
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
    touch "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/pins-set.$dkml_root_version"
fi

# For Windows mimic the ocaml-opam Dockerfile by pinning `ocaml-variants` to our custom version
if is_unixy_windows_build_machine; then
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

if [ -n "$STATEDIR" ] && [ -e "$STATEDIR"/buildconfig/opam/hook-switch-postcreate.txt ]; then
    HOOK_POSTCREATE="$STATEDIR"/buildconfig/opam/hook-switch-postcreate.txt
elif [ -z "$STATEDIR" ] && [ -e "$TOPDIR"/buildconfig/opam/hook-switch-postcreate.txt ]; then
    HOOK_POSTCREATE="$TOPDIR"/buildconfig/opam/hook-switch-postcreate.txt
else
    HOOK_POSTCREATE=
fi
if [ -n "$HOOK_POSTCREATE" ]; then
    HOOK_KEY_POSTCREATE=$(md5sum "$HOOK_POSTCREATE" | awk '{print $1}')
    if [ ! -e "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/hook-postcreate.$dkml_root_version.$HOOK_KEY_POSTCREATE" ]; then
        {
            cat "$WORK"/nonswitchexec.sh
            printf "  exec -- %s '%s'" "$DKML_POSIX_SHELL" "$HOOK_POSTCREATE"
        } > "$WORK"/postcreate.sh
        log_shell "$WORK"/postcreate.sh

        # Done until the next DKML version or the next update to the hook
        touch "$OPAMSWITCHFINALDIR_BUILDHOST/.dkml/opam-cache/hook-postcreate.$dkml_root_version.$HOOK_KEY_POSTCREATE"
    fi
fi

# END opam post create hook
# --------------------------------
