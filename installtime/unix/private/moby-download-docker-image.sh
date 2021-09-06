#!/usr/bin/env bash
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
# moby-download-docker-image.sh MOBYDIR DOCKER_IMAGE DOCKER_TARGET_ARCH
#
# Windows: Meant to be called from Cygwin so there is a working `jq` for the Moby download-frozen-image-v2.sh.
# If we use native Windows jq then we run into `jq` shell quoting failures, and MSYS2 has no `jq`.

set -euf -o pipefail

MOBYDIR=$1
shift

FROZEN_SCRIPT=$1
shift

DOCKER_IMAGE=$1
shift

DOCKER_TARGET_ARCH=$1
shift

# DOCKER_IMAGE=ocaml/opam:windows-msvc-20H2-ocaml-4.12@sha256:e7b6e08cf22f6caed6599f801fbafbc32a93545e864b83ab42aedbd0d5835b55, DOCKER_TARGET_ARCH=arm64
# -> SIMPLE_NAME=ocaml-opam-windows-msvc-20H2-ocaml-4-12-sha256-e7b6e08cf22f6caed6599f801fbafbc32a93545e864b83ab42aedbd0d5835b55-arm64
# !!!Keep in sync with moby-extract-opam-root.sh (refactor into common place if we share more than twice)!!!
SIMPLE_NAME=$DOCKER_IMAGE
SIMPLE_NAME=${SIMPLE_NAME//\//-}
SIMPLE_NAME=${SIMPLE_NAME//:/-}
SIMPLE_NAME=${SIMPLE_NAME//@/-}
SIMPLE_NAME=${SIMPLE_NAME//./-}
SIMPLE_NAME=$SIMPLE_NAME-$DOCKER_TARGET_ARCH

# Quick exit if we already have a Docker image downloaded. They are huge!
if [[ -e "$MOBYDIR"/layers-"$SIMPLE_NAME".txt ]]; then
    exit 0
fi

# Run the Moby download script, which relies on `jq`
# For MSYS2 on Windows, let the files named `json` be translated to Windows paths
which jq >&2
env TARGETARCH="$DOCKER_TARGET_ARCH" MSYS2_ARG_CONV_EXCL='json' "$FROZEN_SCRIPT" "$MOBYDIR" "$DOCKER_IMAGE"

# dump out the layers in order
if [[ -x /usr/bin/cygpath ]]; then
    JQ_MANIFEST_JSON=$(/usr/bin/cygpath -aw "$MOBYDIR"/manifest.json)
else
    JQ_MANIFEST_JSON="$MOBYDIR"/manifest.json
fi
[[ ! -e "$MOBYDIR"/manifest.json ]] || jq -r '.[].Layers | .[]' "$JQ_MANIFEST_JSON" > "$MOBYDIR"/layers-"$SIMPLE_NAME".txt

# we need to rename manifest.json and repositories so that multiple images can live in the same directory
[[ ! -e "$MOBYDIR"/manifest.json ]] || mv "$MOBYDIR"/manifest.json "$MOBYDIR"/manifest-"$SIMPLE_NAME".json
[[ ! -e "$MOBYDIR"/repositories  ]] || mv "$MOBYDIR"/repositories  "$MOBYDIR"/repositories-"$SIMPLE_NAME"
