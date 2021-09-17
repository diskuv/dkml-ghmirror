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
# download-moby-downloader.sh MOBYDIR
#
# Downloads and patches `download-frozen-image-v2.sh` and places it in MOBYDIR

set -euf -o pipefail

MOBYDIR=$1
shift

if [ -x "$MOBYDIR"/download-frozen-image-v2.sh ]; then
    exit 0
fi

install -d "$MOBYDIR"
cd "$MOBYDIR"

rm -f _download-frozen-image-v2.sh __download-frozen-image-v2.sh
curl -s https://raw.githubusercontent.com/moby/moby/6a60efc39bdb6d465d0a56d254fc0f889fa43dce/contrib/download-frozen-image-v2.sh -o _download-frozen-image-v2.sh

# replace 'case ... application/vnd.docker.image.rootfs.diff.tar.gzip)' with 'case ... application/vnd.docker.image.rootfs.diff.tar.gzip | application/vnd.docker.image.rootfs.foreign.diff.tar.gzip)'
sed -i 's#application/vnd.docker.image.rootfs.diff.tar.gzip)#application/vnd.docker.image.rootfs.diff.tar.gzip | application/vnd.docker.image.rootfs.foreign.diff.tar.gzip)#g' \
    _download-frozen-image-v2.sh

chmod +x _download-frozen-image-v2.sh
mv _download-frozen-image-v2.sh download-frozen-image-v2.sh
