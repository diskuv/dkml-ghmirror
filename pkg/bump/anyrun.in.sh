#!/bin/sh
set -euf

# Add opamrun and cmdrun to PATH
opamsw='@opamsw@'
if [ -x /usr/bin/cygpath ]; then opamsw=$(/usr/bin/cygpath -au "$opamsw"); fi
export PATH="$opamsw/.ci/sd4/opamrun:$PATH"

# Using cmdrun will add $OPAMROOT
cmdrun "$@"
