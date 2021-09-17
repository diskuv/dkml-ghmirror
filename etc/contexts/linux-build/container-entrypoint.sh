#!/bin/bash
set -euf -o pipefail

# Passthrough environment variables
ENV_CMD=(env)
OPAMROOT=${OPAMROOT:-}
if [ -n "$OPAMROOT" ]; then ENV_CMD+=(OPAMROOT="$OPAMROOT"); fi
OPAMSWITCH=${OPAMSWITCH:-}
if [ -n "$OPAMSWITCH" ]; then ENV_CMD+=(OPAMSWITCH="$OPAMSWITCH"); fi

# Passthrough or enable DKML_BUILD_TRACE
DKML_BUILD_TRACE=${DKML_BUILD_TRACE:-ON}
ENV_CMD+=(DKML_BUILD_TRACE="$DKML_BUILD_TRACE")

# ---------------
# Setup the chroot
# https://wiki.alpinelinux.org/wiki/Alpine_Linux_in_a_chroot

# shellcheck disable=SC2154
if [ ! -e $chroot_dir/usr/bin/npm ]; then
    echo "FATAL: Did you set the \$chroot_dir environment variable to the Build Sandbox chroot directory? It is missing the npm binary"
    exit 1
fi

if ! mount -t proc none "$chroot_dir"/proc; then
    echo "FATAL: You need to be running in a --privileged Docker container"
    exit 2
fi

mount -o bind /sys "$chroot_dir"/sys

# ---------------------------

# Use same technique of dockcross so we can let the developer see their own files with their own user/group
addgroup -g "$BUILDER_GID" "$BUILDER_GROUP"
adduser -D -G "$BUILDER_GROUP" -u "$BUILDER_UID" "$BUILDER_USER"

# Enter chroot to create the same entries for user/group
chroot "$chroot_dir" addgroup -g "$BUILDER_GID" "$BUILDER_GROUP"
chroot "$chroot_dir" adduser -D -G "$BUILDER_GROUP" -u "$BUILDER_UID" "$BUILDER_USER"

# Enter chroot
if [ "$DKML_BUILD_TRACE" = ON ]; then set -x; fi
exec chroot "$chroot_dir" su-exec "$BUILDER_USER" "${ENV_CMD[@]}" bash -l /opt/build-sandbox/sandbox-entrypoint.sh "$@"
