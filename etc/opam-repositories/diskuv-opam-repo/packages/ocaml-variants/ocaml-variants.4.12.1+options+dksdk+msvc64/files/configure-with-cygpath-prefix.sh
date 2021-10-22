#!/usr/bin/env dash
set -eufx

CFGPREFIX="$1"
shift
CFGPREFIX=$(cygpath -am "$CFGPREFIX")

exec ./configure --prefix="$CFGPREFIX" "$@"
