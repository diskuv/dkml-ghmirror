#!/bin/sh
# ----------------------------
# Copyright 2021 Diskuv, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------
#
# @jonahbeckford: 2021-09-07
# - This file is licensed differently than the rest of the Diskuv OCaml distribution.
#   Keep the Apache License in this file since this file is part of the reproducible
#   build files.
#
######################################
# moby-extract-opam-root.sh MOBYDIR DOCKER_IMAGE DOCKER_TARGET_ARCH OCAML_OPAM_PORT DESTINATION_OPAM_ROOT
#
# OCAML_OPAM_PORT is either msvc or mingw. Confer https://discuss.ocaml.org/t/ann-ocaml-opam-images-for-docker-for-windows/8179

set -euf

MOBYDIR=$1
shift

DOCKER_IMAGE=$1
shift

DOCKER_TARGET_ARCH=$1
shift

OCAML_OPAM_PORT=$1
shift

DESTINATION_OPAM_ROOT=$1
shift

# DOCKER_IMAGE=ocaml/opam:windows-msvc-20H2-ocaml-4.12@sha256:e7b6e08cf22f6caed6599f801fbafbc32a93545e864b83ab42aedbd0d5835b55, DOCKER_TARGET_ARCH=arm64
# -> SIMPLE_NAME=ocaml-opam-windows-msvc-20H2-ocaml-4-12-sha256-e7b6e08cf22f6caed6599f801fbafbc32a93545e864b83ab42aedbd0d5835b55-arm64
# !!!Keep in sync with moby-download-docker-image.sh (refactor into common place if we share more than twice)!!!
SIMPLE_NAME=$(echo "$DOCKER_IMAGE" | tr /:@. -)
SIMPLE_NAME=$SIMPLE_NAME-$DOCKER_TARGET_ARCH

OUTDIR=$DESTINATION_OPAM_ROOT/$OCAML_OPAM_PORT-$DOCKER_TARGET_ARCH

# Extract the tarballs
# Note: Excluding is less troublesome than including. If we used 'tar xf $t some/directory some/other/directory' and those directories
#       did not exist in the tar, the tar command would fail. Excluding never has that problem.
#       The only things we want are
#         a) the Opam root at `/opam/.opam`
#         b) the `ocaml-env*` executables at `/cygwin64/bin/ocaml-env*.exe` (they have no Cygwin library dependencies)
#         c) the Opam mingw repository at `/cygwin64/home/opam/opam-repository`
#         d) the etcetera files from `cygwin64/etc/` and related files in `cygwin64/usr/share/` so that when ocaml-opam's opam.exe spawns curl.exe in the PATH to download packages
#            and correctly finds build/_tools/common/cygwin/bin/curl.exe, and when the interprocess shared cygwin1.dll dependency
#            gives curl.exe the spawning Cygwin root (ocaml-opam/, not cygwin/) as the location of its etcetera files ... that curl.exe
#            can still read valid SSL certificate authority files. Ditto for any other opam.exe spawned process.
# Note 2: We have to check whether the tar files are actually JSON error files. We do that by checking if the first characters are '{"errors":'

if [ ! -e "$OUTDIR/cygwin64/bin/ocaml-env.exe" ] ||
    [ ! -e "$OUTDIR/cygwin64/home/opam/opam-repository/repo" ] ||
    [ ! -e "$OUTDIR/cygwin64/usr/share/crypto-policies/DEFAULT/openssl.txt" ] ||
    [ ! -e "$OUTDIR/opam/.opam/config" ]
then
    install -d "$OUTDIR"

    # Caution: `tar` may extract some files with '0o000' permissions (especially on Cygwin GNU tar
    # for some 'Administrator' tar entries). Plain ol' POSIX should give us the permission to
    # change those permissions as long as we own the parent directory 'incoming/'.
    #
    # That is "$WORK/incoming/" below.

    # keep large temp files on the same filesystem ('cache') that must already support huge files
    install -d "$MOBYDIR/tmp"
    WORK=$(mktemp -d "$MOBYDIR/tmp/tmp.XXXXXXXXXX")
    # since tar can create 0o000 directories we need to try to change permissions before deleting
    trap 'chmod -R 755 "$WORK"; rm -rf "$WORK"' EXIT

    while IFS= read -r layer_name; do
        layer="$MOBYDIR"/"$layer_name"
        head --bytes=10 "$layer" > "$WORK"/rhs
        if printf '%s' '{"errors":' | cmp -s - "$WORK"/rhs 2>/dev/null; then
            echo "Skipping   $OCAML_OPAM_PORT $layer"
            continue
        fi

        # We want to extract the subfolder Files/ but without many of its subfolders.
        # Some layers may effectively have no files though, so we can't use a 'Files/' argument; if
        # we did we would get 'tar: Files: Not found in archive'.
        # Instead we extract everything with as many --exclude as appropriate, and then rsync the Files/
        # subfolder (if any) into the correct location.
        echo "Scanning   $OCAML_OPAM_PORT $layer"
        install -d "$WORK/incoming"
        tar x --file "$layer" --directory "$WORK/incoming" \
            --overwrite --warning=no-unknown-keyword --wildcards --ignore-zeros \
            --exclude 'Hives/' \
            --exclude 'Files/Program Files/**' \
            --exclude 'Files/Program Files (x86)/**' \
            --exclude 'Files/ProgramData/**' \
            --exclude 'Files/TEMP/**' \
            --exclude 'Files/Users/**' \
            --exclude 'Files/Windows/**' \
            --exclude 'Files/Documents and Settings' \
            --exclude 'Files/.wh.TEMP' \
            --exclude 'Files/BuildTools/**' \
            --exclude 'Files/opam/.opam/repo/state.cache' \
            --exclude 'Files/cygwin-setup-x86_64.exe'
            # Too many ways compilation can fail if we exclude the wrong file in cygwin64/, especially a library we may not see until long time in future
            # --exclude 'Files/opam/.opam/download-cache/**' \ # download cache? getting errors: The archive ... contains multiple root directories. Ie. https://github.com/ocaml-cross/opam-cross-android/issues/4
            # --exclude 'Files/cygwin64/lib/**' \
            # --exclude 'Files/cygwin64/usr/lib' \
            # --exclude 'Files/cygwin64/usr/libexec' \
            # --exclude 'Files/cygwin64/usr/x86_64-w64-mingw32' \
            # --exclude 'Files/cygwin64/var/**'

        # Fix any 0o000 perms
        chmod -R 755 "$WORK/incoming"

        # Copy 'Files/'
        if [ -e "$WORK"/incoming/Files/ ]; then
            echo "Extracting $OCAML_OPAM_PORT $layer"
            # As one more safeguard we avoid 'rsync -p' option so that
            # we do _not_ copy '0o000' permissions
            rsync -a --prune-empty-dirs "$WORK/incoming/Files/" "$OUTDIR/"
        fi

        # Clean up for the next tarball
        rm -rf "$WORK/incoming"

    done < "$MOBYDIR"/layers-"$SIMPLE_NAME".txt

    # Fix up repository config which is pointing to Docker location ...
    #   repositories: [
    #     "default" {"file://C:/cygwin64/home/opam/opam-repository"}
    #   ]
    # We will produce 'default' instead in its actual location like:
    #   file://C:/source/xx/yy/opam-repository
    OPAM_REPOSITORY_LOCAL_URL=file://$(cygpath -am "$OUTDIR"/cygwin64/home/opam/opam-repository)
    cat > "$OUTDIR"/opam/.opam/repo/repos-config <<EOF
repositories: [
"default" {"$OPAM_REPOSITORY_LOCAL_URL"}
]
EOF

fi
