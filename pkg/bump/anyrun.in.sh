#!/bin/sh
set -euf

# Add opamrun and cmdrun to PATH
BINARY_DIR='@CMAKE_CURRENT_BINARY_DIR@'
if [ -x /usr/bin/cygpath ]; then BINARY_DIR=$(/usr/bin/cygpath -au "$BINARY_DIR"); fi
export PATH="$BINARY_DIR/.ci/sd4/opamrun:$PATH"

# Using cmdrun will add $OPAMROOT
cmdrun "$@"
