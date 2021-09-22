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

PINNED_PACKAGES=

# DKML provides patches for these
PINNED_PACKAGES="
    $PINNED_PACKAGES
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

# These incorrectly did not use a major version bump and caused major breaking changes to downstream packages
 # ppxlib.0.23.0 breaks ppx_variants_conv.v0.14.1. PR to fix is https://github.com/janestreet/ppx_variants_conv/pull/9
PINNED_PACKAGES="
    $PINNED_PACKAGES
    ppxlib,0.22.0
    "

# Security fixes
PINNED_PACKAGES="
    $PINNED_PACKAGES
    "

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    create-opam-switch.sh -h                          Display this help message" >&2
    echo "    create-opam-switch.sh -b BUILDTYPE -p PLATFORM    Create the Opam switch" >&2
    echo "    create-opam-switch.sh -b BUILDTYPE -t OPAMSWITCH  Create the Opam switch in directory OPAMSWITCH/_opam" >&2
    echo "    create-opam-switch.sh [-b BUILDTYPE] -s           Expert. Create the diskuv-system switch" >&2
    echo "Options:" >&2
    echo "    -p PLATFORM: The target platform or 'dev'" >&2
    echo "    -t OPAMSWITCH: The target Opam switch. A subdirectory _opam will be created for your Opam switch" >&2
    echo "    -s: Select the 'diskuv-system' switch" >&2
    echo "    -b BUILDTYPE: The build type which is one of:" >&2
    echo "        Debug" >&2
    echo "        Release - Most optimal code. Should be faster than ReleaseCompat* builds" >&2
    echo "        ReleaseCompatPerf - Compatibility with 'perf' monitoring tool." >&2
    echo "        ReleaseCompatFuzz - Compatibility with 'afl' fuzzing tool." >&2
    echo "    -y Say yes to all questions" >&2
}

PLATFORM=
BUILDTYPE=
DISKUV_SYSTEM_SWITCH=OFF
TARGET_OPAMSWITCH=
YES=OFF
while getopts ":h:b:p:st:y" opt; do
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
        t)
            TARGET_OPAMSWITCH=$OPTARG
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

if [ -z "$TARGET_OPAMSWITCH" ] && [ -z "$PLATFORM" ] && [ "$DISKUV_SYSTEM_SWITCH" = OFF ]; then
    usage
    exit 1
elif [ -n "$TARGET_OPAMSWITCH" ] && [ -z "$BUILDTYPE" ]; then
    usage
    exit 1
elif [ -n "$PLATFORM" ] && [ -z "$BUILDTYPE" ]; then
    usage
    exit 1
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
    PLATFORM=dev
fi
if [ -n "$TARGET_OPAMSWITCH" ]; then
    PLATFORM=dev
    # shellcheck disable=SC2034
    BUILDDIR="." # build directory will be the same as TOPDIR, not build/dev/Debug
    # shellcheck disable=SC2034
    TOPDIR_CANDIDATE="$TARGET_OPAMSWITCH"
fi

# shellcheck disable=SC1091
if [ -n "${BUILDTYPE:-}" ] || [ -n "${BUILDDIR:-}" ]; then
    # shellcheck disable=SC1091
    . "$DKMLDIR"/runtime/unix/_common_build.sh
else
    # shellcheck disable=SC1091
    . "$DKMLDIR"/runtime/unix/_common_tool.sh
fi
# shellcheck disable=SC1091
. "$DKMLDIR"/.dkmlroot # set $dkml_root_version

# To be portable whether we build scripts in the container or not, we
# change the directory to always be in the TOPDIR (just like the container
# sets the directory to be /work mounted to TOPDIR)
cd "$TOPDIR"

# From here onwards everything should be run using RELATIVE PATHS ...
# >>>>>>>>>

# --------------------------------
# BEGIN opam switch create

# Set BUILDHOST_ARCH
build_machine_arch
if [ $PLATFORM = dev ]; then
    TARGET_ARCH=$BUILDHOST_ARCH
else
    TARGET_ARCH=$PLATFORM
fi

echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec \\" > "$WORK"/nonswitchexec.sh
if [ "$DISKUV_SYSTEM_SWITCH" = ON ]; then
    # Set $DiskuvOCamlHome and other vars
    autodetect_dkmlvars

    # Set OPAMROOTDIR_BUILDHOST and OPAMROOTDIR_EXPAND
    set_opamrootdir

    # Set OPAMSWITCHFINALDIR_BUILDHOST and OPAMSWITCHDIR_EXPAND of `diskuv-system` switch
    set_opamswitchdir_of_system

    echo "  -s \\" >> "$WORK"/nonswitchexec.sh
else
    if [ -z "${BUILDTYPE:-}" ]; then echo "check_state nonempty BUILDTYPE" >&2; exit 1; fi
    # Set OPAMSWITCHFINALDIR_BUILDHOST, OPAMSWITCHNAME_BUILDHOST, OPAMSWITCHDIR_EXPAND, OPAMSWITCHISGLOBAL
    set_opamrootandswitchdir

    echo "  -p $PLATFORM \\" >> "$WORK"/nonswitchexec.sh
    if [ -n "$TARGET_OPAMSWITCH" ]; then
        echo "  -t $TARGET_OPAMSWITCH \\" >> "$WORK"/nonswitchexec.sh
    else
        echo "  -b $BUILDTYPE \\" >> "$WORK"/nonswitchexec.sh
    fi
fi

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
OPAM_SWITCH_CREATE_PREHOOK=
OCAML_OPTIONS=
OPAM_SWITCH_CFLAGS=
OPAM_SWITCH_CC=
OPAM_SWITCH_ASPP=
OPAM_SWITCH_AS=
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
    windows_*)    TARGET_LINUXARM32=OFF; TARGET_WINDOWS=ON ;;
    linux_arm32*) TARGET_LINUXARM32=ON; TARGET_WINDOWS=OFF ;;
    *)            TARGET_LINUXARM32=OFF; TARGET_WINDOWS=OFF
esac
case "$BUILDTYPE" in
    Debug*) BUILD_DEBUG=ON; BUILD_RELEASE=OFF ;;
    Release*) BUILD_DEBUG=OFF; BUILD_RELEASE=ON ;;
    *) BUILD_DEBUG=OFF; BUILD_RELEASE=OFF
esac
case "$TARGET_ARCH" in
    *_x86 | linux_arm32*) TARGET_32BIT=ON ;;
    *) TARGET_32BIT=OFF
esac
case "$TARGET_ARCH" in
    linux_x86_64) TARGET_CANOMITFRAMEPOINTER=ON ;;
    *) TARGET_CANOMITFRAMEPOINTER=OFF
esac

# Frame pointers is only a 64-bit Linux thing.
# Confer: https://github.com/ocaml/ocaml/blob/e93f6f8e5f5a98e7dced57a0c81535481297c413/configure#L17455-L17472
if [ $BUILD_DEBUG = ON ] && [ $TARGET_CANOMITFRAMEPOINTER = ON ]; then
    # Frame pointer is always on in Debug mode.
    # Windows does not support frame pointers.
    # On Linux we need it for `perf`.
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-fp
fi
if [ $BUILD_RELEASE = ON ]; then
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-flambda
fi
if [ $TARGET_LINUXARM32 = ON ]; then
    # -Os optimizes for size. Useful for CPUs with small cache sizes. Confer https://wiki.gentoo.org/wiki/GCC_optimization
    OPAM_SWITCH_CFLAGS="$OPAM_SWITCH_CFLAGS -Os"
fi
if [ $TARGET_32BIT = ON ]; then
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-32bit
fi
if [ "$BUILDTYPE" = ReleaseCompatPerf ] && [ $TARGET_WINDOWS = OFF ]; then
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-fp
elif [ "$BUILDTYPE" = ReleaseCompatFuzz ]; then
    OCAML_OPTIONS="$OCAML_OPTIONS",ocaml-option-afl
fi

echo "switch create \\" > "$WORK"/switchcreateargs.sh
if [ "$YES" = ON ]; then echo "  --yes \\" >> "$WORK"/switchcreateargs.sh; fi

if is_unixy_windows_build_machine; then
    # shellcheck disable=SC2154
    echo "  diskuv-$dkml_root_version fdopen-mingw-$dkml_root_version default \\" > "$WORK"/repos-choice.lst
    echo "  --repos='diskuv-$dkml_root_version,fdopen-mingw-$dkml_root_version,default' \\" >> "$WORK"/switchcreateargs.sh
    echo "  --packages='ocaml-variants.$OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS$OCAML_OPTIONS' \\" >> "$WORK"/switchcreateargs.sh
else
    echo "  diskuv-$dkml_root_version default \\" > "$WORK"/repos-choice.lst
    echo "  --repos='diskuv-$dkml_root_version,default' \\" >> "$WORK"/switchcreateargs.sh
    echo "  --packages='ocaml-variants.4.12.0+options$OCAML_OPTIONS' \\" >> "$WORK"/switchcreateargs.sh
fi
if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "  --debug-level 2 \\" >> "$WORK"/switchcreateargs.sh; fi

# We'll use the bash builtin `set` which quotes spaces correctly.
OPAM_SWITCH_CREATE_PREHOOK="echo OPAMSWITCH=; echo OPAM_SWITCH_PREFIX=" # Ignore any switch the developer gave. We are creating our own.
if [ -n "${OPAM_SWITCH_CFLAGS:-}" ]; then OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';'; CFLAGS='$OPAM_SWITCH_CFLAGS'; set | grep ^CFLAGS="; fi
if [ -n "${OPAM_SWITCH_CC:-}" ]; then     OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';';     CC='$OPAM_SWITCH_CC'    ; set | grep ^CC="; fi
if [ -n "${OPAM_SWITCH_ASPP:-}" ]; then   OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';';   ASPP='$OPAM_SWITCH_ASPP'  ; set | grep ^ASPP="; fi
if [ -n "${OPAM_SWITCH_AS:-}" ]; then     OPAM_SWITCH_CREATE_PREHOOK="$OPAM_SWITCH_CREATE_PREHOOK; echo ';';     AS='$OPAM_SWITCH_AS'    ; set | grep ^AS="; fi

if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "+ ! is_minimal_opam_switch_present \"$OPAMSWITCHFINALDIR_BUILDHOST\"" >&2; fi
if ! is_minimal_opam_switch_present "$OPAMSWITCHFINALDIR_BUILDHOST"; then
    # clean up any partial install
    echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec -p '$PLATFORM' switch remove \\" > "$WORK"/switchremoveargs.sh
    if [ "$YES" = ON ]; then echo "  --yes \\" >> "$WORK"/switchremoveargs.sh; fi
    echo "  $OPAMSWITCHDIR_EXPAND" >> "$WORK"/switchremoveargs.sh
    "$SHELL" "$WORK"/switchremoveargs.sh || rm -rf "$OPAMSWITCHFINALDIR_BUILDHOST"

    # do real install
    echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec -p '$PLATFORM' -1 '$OPAM_SWITCH_CREATE_PREHOOK' \\" > "$WORK"/switchcreateexec.sh
    cat "$WORK"/switchcreateargs.sh >> "$WORK"/switchcreateexec.sh
    echo "  $OPAMSWITCHDIR_EXPAND" >> "$WORK"/switchcreateexec.sh
    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then tail -n100 "$WORK"/switchcreateexec.sh >&2; fi
    "$SHELL" "$WORK"/switchcreateexec.sh
else
    # We need to upgrade each Opam switch's selected/ranked Opam repository choices whenever Diskuv OCaml
    # has an upgrade. If we don't the PINNED_PACKAGES may fail.
    # We know from `diskuv-$dkml_root_version` what Diskuv OCaml version the Opam switch is using, so
    # we have the logic to detect here when it is time to upgrade!
    {
        cat "$WORK"/nonswitchexec.sh
        echo "  repository list --short"
    } > "$WORK"/list.sh
    "$SHELL" "$WORK"/list.sh > "$WORK"/list
    if awk -v N="diskuv-$dkml_root_version" '$1==N {exit 1}' "$WORK"/list; then
        # Time to upgrade. We need to set the repository (almost instantaneous) and then
        # do a `opam update` so the switch has the latest repository definitions.
        {
            cat "$WORK"/nonswitchexec.sh
            echo "  repository set-repos \\"
            if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "  --debug-level 2 \\"; fi
            cat "$WORK"/repos-choice.lst
        } > "$WORK"/setrepos.sh
        "$SHELL" "$WORK"/setrepos.sh

        {
            echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec \\"
            cat "$WORK"/nonswitchexec.sh
            echo "  update \\"
            if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "  --debug-level 2 \\"; fi
        } > "$WORK"/update.sh
        "$SHELL" "$WORK"/update.sh
    fi
fi

# END opam switch create
# --------------------------------

# --------------------------------
# BEGIN opam option

# Set PLATFORM_VCPKG_TRIPLET
platform_vcpkg_triplet

if is_unixy_windows_build_machine; then
    PKG_CONFIG_PATH_ADD="$DKMLPLUGIN_BUILDHOST\\vcpkg\\$dkml_root_version\\installed\\$PLATFORM_VCPKG_TRIPLET\\lib\\pkgconfig"
else
    PKG_CONFIG_PATH_ADD="$DKMLPLUGIN_BUILDHOST/vcpkg/$dkml_root_version/installed/$PLATFORM_VCPKG_TRIPLET/lib/pkgconfig"
fi

# Opam `PKG_CONFIG_PATH += "xxx"` requires that `xxx` is a valid Opam string. Escape all the backslashes.
PKG_CONFIG_PATH_ADD=$(echo "${PKG_CONFIG_PATH_ADD}" | sed 's#\\#\\\\#g')

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
# 1. PKG_CONFIG_PATH
# 2. LUV_USE_SYSTEM_LIBUV=yes if Windows which uses vcpkg. See https://github.com/aantron/luv#external-libuv
{
    echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec \\"
    cat "$WORK"/nonswitchexec.sh
    echo "  option setenv='PKG_CONFIG_PATH += \"$PKG_CONFIG_PATH_ADD\"' "
} > "$WORK"/setenv.sh
"$SHELL" "$WORK"/setenv.sh

if is_unixy_windows_build_machine; then
    {
        echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec \\"
        cat "$WORK"/nonswitchexec.sh
        echo "  option setenv+='LUV_USE_SYSTEM_LIBUV += \"yes\"' "
    } > "$WORK"/setenv.sh
    "$SHELL" "$WORK"/setenv.sh
fi

# END opam option
# --------------------------------

# --------------------------------
# BEGIN opam pin add

# Set DKML_POSIX_SHELL
autodetect_posix_shell

# Create: pin.sh "$OPAMROOTDIR_EXPAND" "$OPAMSWITCHDIR_EXPAND"
{
    echo "#!$DKML_POSIX_SHELL"
    echo 'set -euf'
    # shellcheck disable=2016
    echo '_OPAMROOTDIR=$1'
    echo 'shift'
    # shellcheck disable=2016
    echo '_OPAMSWITCHDIR=$1'
    echo 'shift'
    # shellcheck disable=2016
    echo 'eval $(opam env --root "$_OPAMROOTDIR" --switch "$_OPAMSWITCHDIR" --set-root --set-switch)'
    if [ -x /usr/bin/cygpath ]; then
        # PATH may be a Windows path. For now we need it to be a UNIX path or else commands
        # like 'opam' will not be found.
        # Always add in standard /usr/bin:/bin paths as well.
        # shellcheck disable=2016
        echo 'PATH=$(/usr/bin/cygpath --path "$PATH"):/usr/bin:/bin'
    fi
    if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo 'set -x'; fi
} > "$WORK"/pin.sh

OPAM_PIN_ADD_ARGS="pin add"
if [ "$YES" = ON ]; then OPAM_PIN_ADD_ARGS="$OPAM_PIN_ADD_ARGS --yes"; fi
NEED_TO_PIN=OFF

# For Windows mimic the ocaml-opam Dockerfile by pinning `ocaml-variants` to our custom version
if is_unixy_windows_build_machine; then
    if ! get_opam_switch_state_toplevelsection "$OPAMSWITCHFINALDIR_BUILDHOST" pinned | grep -q "ocaml-variants.$OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS"; then
        echo "opam ${OPAM_PIN_ADD_ARGS} -k version ocaml-variants '$OCAML_VARIANT_FOR_SWITCHES_IN_WINDOWS'" >> "$WORK"/pin.sh
        NEED_TO_PIN=ON
    fi
fi

# Pin the versions of the packages for which we have patches (etc/opam-repositories/diskuv-opam-repo/packages)
# Each ___ in `for package_tuple in __ __ __` is `PACKAGE_NAME,PACKAGE_VERSION`. Notice the **comma**!
# Even though technically we may not need the patches for non-Windows systems, we want the same code
# running in both Unix and Windows, right?!
# We add --no-action so the package is not automatically installed but simply pinned.
for package_tuple in ${PINNED_PACKAGES}; do
    # $1 = package_name; $2 = package_version
    expr=$(echo set -- "$package_tuple" | sed 's/,/ /g')
    eval "$expr"
    # accumulate
    if ! get_opam_switch_state_toplevelsection "$OPAMSWITCHFINALDIR_BUILDHOST" pinned | grep -q "$1.$2"; then
        echo "opam ${OPAM_PIN_ADD_ARGS} --no-action -k version '$1' '$2'" >> "$WORK"/pin.sh
        NEED_TO_PIN=ON
    fi
done

# Execute all of the accumulated `opam pin add` at once
if [ "$NEED_TO_PIN" = ON ]; then
    {
        echo "exec '$DKMLDIR'/runtime/unix/platform-opam-exec \\"
        cat "$WORK"/nonswitchexec.sh
        echo "  exec -- bash '$WORK_EXPAND'/pin.sh '$OPAMROOTDIR_EXPAND' '$OPAMSWITCHDIR_EXPAND' "
    } > "$WORK"/launchpin.sh
    "$SHELL" "$WORK"/launchpin.sh
fi

# END opam pin add
# --------------------------------
