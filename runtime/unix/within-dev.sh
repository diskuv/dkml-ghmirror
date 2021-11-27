#!/bin/bash
# --------------------------
# within-dev.sh
#
# Analog of within-sandbox.sh and sandbox-entrypoint.sh. Most of the same environment variables should be set albeit with different values.
# --------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
    echo "Usage:" >&2
    echo "    within-dev.sh -h                          Display this help message." >&2
    echo "    within-dev.sh -h                          Display this help message." >&2
    echo "    within-dev.sh [-p PLATFORM] [-b BUILDTYPE] command ...  (Deprecated) Run the command and any arguments in the dev platform." >&2
    echo "       -p PLATFORM: The target platform used. Defaults to 'dev'. DKML_TOOLS_DIR and DKML_DUNE_BUILD_DIR will be based on this" >&2
    echo "       -b BUILDTYPE: If specified, will set DKML_DUNE_BUILD_DIR in the dev platform" >&2
    echo "    within-dev.sh -d STATEDIR [-u OFF] command ...  Run the command and any arguments in the environment of STATEDIR." >&2
    echo "       -u ON|OFF: User mode. Currently unused except to influence the temporary directory, but passthrough the user mode of the calling script" >&2
    echo "       -d STATEDIR: State directory. Currently unused except to influence the temporary directory, but passthrough the user mode of the calling script" >&2
    echo "Advanced Options:" >&2
    echo "       -c: If specified, compilation flags like CC are added to the environment." >&2
    echo "             This can take several seconds on Windows since vcdevcmd.bat needs to run" >&2
    echo "       -0 PREHOOK_SINGLE: If specified, the script will be 'eval'-d upon" >&2
    echo "             entering the Build Sandbox _before_ any the opam command is run." >&2
    echo "       -1 PREHOOK_DOUBLE: If specified, the Bash statements will be 'eval'-d, 'dos2unix'-d and 'eval'-d" >&2
    echo "             upon entering the Build Sandbox _before_ any other commands are run but" >&2
    echo "             _after_ the PATH has been established." >&2
    echo "             It behaves similar to:" >&2
    echo '               eval "the PREHOOK_DOUBLE you gave" > /tmp/eval.sh' >&2
    echo '               eval /tmp/eval.sh' >&2
    echo '             Useful for setting environment variables (possibly from a script).' >&2
}

# no arguments should display usage
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    # shellcheck disable=SC2034
    export PLATFORM=dev
fi
BUILDTYPE=
PREHOOK_SINGLE=
PREHOOK_DOUBLE=
COMPILATION=OFF
STATEDIR=
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    USERMODE=OFF
else
    USERMODE=ON
fi
while getopts ":hb:p:0:1:cu:d:" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            PLATFORM=$OPTARG
        ;;
        b )
            # shellcheck disable=SC2034
            BUILDTYPE=$OPTARG
        ;;
        0 )
            PREHOOK_SINGLE=$OPTARG
        ;;
        1 )
            PREHOOK_DOUBLE=$OPTARG
        ;;
        c )
            COMPILATION=ON
        ;;
        d )
            STATEDIR=$OPTARG
        ;;
        u )
            # shellcheck disable=SC2034
            USERMODE=$OPTARG
        ;;
        \? )
            echo "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# END Command line processing
# ------------------

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR"/../.. && pwd)

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    if [ -n "${BUILDTYPE:-}" ] || [ -n "${DKML_DUNE_BUILD_DIR:-}" ]; then
        # shellcheck disable=SC1091
        . "$DKMLDIR"/runtime/unix/_common_build.sh
    else
        # shellcheck disable=SC1091
        . "$DKMLDIR"/runtime/unix/_common_tool.sh
    fi
else
    if [ -n "${STATEDIR:-}" ]; then
        # shellcheck disable=SC1091
        . "$DKMLDIR"/runtime/unix/_common_build.sh
    else
        # shellcheck disable=SC1091
        . "$DKMLDIR"/runtime/unix/_common_tool.sh
    fi
fi

if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    # Set DKML_VCPKG_HOST_TRIPLET
    platform_vcpkg_triplet
fi

# Set DKML_VCPKG_MANIFEST_DIR if necessary
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    if [ -e "$TOPDIR/vcpkg.json" ]; then
        DKML_VCPKG_MANIFEST_DIR="$TOPDIR"
        if [ -x /usr/bin/cygpath ]; then DKML_VCPKG_MANIFEST_DIR=$(/usr/bin/cygpath -aw "$DKML_VCPKG_MANIFEST_DIR"); fi
        export DKML_VCPKG_MANIFEST_DIR
    else
        unset DKML_VCPKG_MANIFEST_DIR
    fi
fi

# Essential environment values.
LAUNCHER_ARGS=()

# On Windows always disable the Automatic Unix ⟶ Windows Path Conversion
# described at https://www.msys2.org/docs/filesystem-paths/
disambiguate_filesystem_paths

# If and only if [-b DKML_DUNE_BUILD_DIR] specified
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    if [ -n "${BUILDTYPE:-}" ]; then
        LAUNCHER_ARGS+=(
            DKML_DUNE_BUILD_DIR="${BUILD_BASEPATH}$DKML_DUNE_BUILD_DIR"
        )
    fi
else
    if [ -n "${DKML_DUNE_BUILD_DIR:-}" ]; then
        LAUNCHER_ARGS+=(
            DKML_DUNE_BUILD_DIR="$DKML_DUNE_BUILD_DIR"
        )
    fi
fi

# Autodetect DKMLSYS_*
autodetect_system_binaries

# Reset PATH to the system PATH.
#
# Alternative: Normalize the PATH. But for reproducibility just use the system PATH.
#
# Note: If we end up with any double quotes in the Windows PATH passed to
# vsdevcmd.bat then we will get '\Microsoft was unexpected at this time'
# (https://social.msdn.microsoft.com/Forums/vstudio/en-US/21821c4a-b415-4b55-8779-1d22694a8f82/microsoft-was-unexpected-at-this-time?forum=vssetup).
# That will happen if we have trailing slashes in our PATH (which Opam.exe internally cygpaths
# and escapes).
autodetect_system_path # Autodetect DKML_SYSTEM_PATH
PATH="$DKML_SYSTEM_PATH"

# # Autodetect DKMLVARS and add to PATH
# autodetect_dkmlvars || true
# if [ -n "${DKMLBINPATHS_UNIX:-}" ]; then
#     ENV_PATH_PREFIX="$DKMLBINPATHS_UNIX"
# else
#     ENV_PATH_PREFIX=
# fi

# # Add prefix if specified
# if [ -n "$ENV_PATH_PREFIX" ]; then
#     ENV_PATH_PREFIX=$(printf "%s" "$ENV_PATH_PREFIX" | $DKMLSYS_SED 's#/:#:#g; s#/$##') # remove trailing slashes
#     PATH="$ENV_PATH_PREFIX:$PATH"
# fi
# printf "%s\n" "PATH ={within-dev.sh#2} $PATH" >&2

# Make a script to run any prehooks
{
    printf "#!/bin/sh\n\n"

    # [sanitize_path]
    # At this point the prehook may have set the PATH to be a Windows style path (ex. `opam env`).
    # So subsequent commands like `env`, `bash` and `rm` will need the PATH converted back to UNIX.
    # Especially ensure /usr/bin:/bin is present in PATH even if redundant so
    # `trap 'rm -rf "$WORK"' EXIT` handler can find 'rm'.
    # We use a missing /usr/bin to trigger the PATH mutation since:
    # - MSYS2 mounts /usr/bin as /bin (so /bin is automatically converted to /usr/bin in MSYS2 PATH)
    cat <<EOF
sanitize_path() {
    if [ -x /usr/bin/cygpath ]; then PATH=\$(/usr/bin/cygpath --path "\$PATH"); fi
    case "\$PATH" in
        /usr/bin) ;;
        *:/usr/bin) ;;
        /usr/bin:*) ;;
        *:/usr/bin:*) ;;
        *)
            PATH=/usr/bin:/bin:"\$PATH"
    esac
}

EOF

    if [ -n "$PREHOOK_SINGLE" ]; then
        if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then
            printf '%s\n' 'printf "+ [eval] ...\n" >&2'
            printf '%s\n' "'$DKMLSYS_SED' 's/^/+| /' '$PREHOOK_SINGLE' >&2"
        fi
        printf '%s\n' ". '$PREHOOK_SINGLE'"
        printf '%s\n\n' 'sanitize_path'
    fi

    if [ -n "$PREHOOK_DOUBLE" ]; then
        PREHOOK_DOUBLE_SQ=$(printf '%s' "$PREHOOK_DOUBLE" | escape_stdin_for_single_quote)
        if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then
            printf "printf %s '%s' >&2\n" \
                '"%s\n"' \
                "+ [eval] $PREHOOK_DOUBLE_SQ"
        fi
        # the `awk ...` is dos2unix equivalent
        cat <<EOF
if ! eval '$PREHOOK_DOUBLE_SQ' > '$WORK'/prehook.eval; then
    printf "FATAL: The following prehook failed:\n>>>\n%s\n<<<\n" '$PREHOOK_DOUBLE_SQ' >&2
    exit 107
fi
awk '{ sub(/\r$/,""); print }' '$WORK'/prehook.eval > '$WORK'/prehook.dos2unix.eval
rm -f '$WORK'/prehook.eval
. '$WORK'/prehook.dos2unix.eval
sanitize_path
rm -f '$WORK'/prehook.dos2unix.eval

EOF
    fi

    printf 'exec env "$@"\n'
} > "$WORK"/launch-prehooks.sh
"$DKMLSYS_CHMOD" +x "$WORK"/launch-prehooks.sh

# Autodetect compiler like Visual Studio on Windows.
# Whether or not compilation is needed, make a launcher that uses the system PATH plus optionally
# any compiler PATH and optionally any other compiler environment variables.
LAUNCHER="$WORK"/launch-dev-compiler.sh
if [ "$COMPILATION" = ON ]; then
    # If we have an Opam switch with a Opam command wrapper, we don't need to waste a few seconds detecting the compiler.
    if [ -z "${OPAM_SWITCH_PREFIX:-}" ] || [ ! -e "$OPAM_SWITCH_PREFIX"/.dkml/wrap-commands.exist ]; then
        set +e
        autodetect_compiler "$LAUNCHER"
        EXITCODE=$?
        set -e
        if [ $EXITCODE -ne 0 ]; then
            echo "FATAL: Your system is missing a compiler, which should be installed if you have completed the Diskuv OCaml installation"
            exit 1
        fi
    fi
fi
if [ ! -e "$LAUNCHER" ]; then
    create_system_launcher "$LAUNCHER"
fi

# If macOS then make sure we are running the correct architecture.
# Can really only switch if the launched command is a Universal binary.
if [ "${DKML_FEATUREFLAG_CMAKE_PLATFORM:-OFF}" = OFF ]; then
    case "$PLATFORM" in
        darwin_arm64)
            # arm64 will be tried first, and then arm64e (Apple Silicon)
            LAUNCHER_ARGS+=(/usr/bin/arch -arch arm64)
        ;;
        darwin_x86_64)
            LAUNCHER_ARGS+=(/usr/bin/arch -arch x86_64)
        ;;
    esac
fi

# print PATH for troubleshooting
if [ "${DKML_BUILD_TRACE:-ON}" = ON ]; then echo "+ [PATH] $PATH" >&2; fi

# run the requested command (cannot `exec` since the launcher script is a temporary file
# that needs to be cleaned up after execution)
set +u # allow empty LAUNCHER_ARGS
log_shell "$LAUNCHER" "$WORK"/launch-prehooks.sh "${LAUNCHER_ARGS[@]}" "$@"