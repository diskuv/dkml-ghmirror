#!/bin/sh
set -euf

OUTPUT_FILE='@WITH_COMPILER_SH@'

#       shellcheck disable=SC1091
. '@dkml-runtime-common_SOURCE_DIR@/unix/crossplatform-functions.sh'

autodetect_compiler "${OUTPUT_FILE}"
if [ "${DKML_BUILD_TRACE:-}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
  echo "=== ${OUTPUT_FILE} ===" >&2
  cat "${OUTPUT_FILE}" >&2
  echo '=== (done) ===' >&2
fi
