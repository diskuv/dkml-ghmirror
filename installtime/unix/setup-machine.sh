#!/bin/bash
set -euf -o pipefail

# This file is a transliteration of `setup-machine.ps1`.
# Consider the variable and method naming of PowerShell scripts to be authoritative.

HereDir=$(dirname "$0")
HereDir=$(cd "$HereDir" && pwd)

DkmlDir=$(cd "$HereDir/../.." && pwd)
if [ ! -e "$DkmlDir/.dkmlroot" ]; then echo "FATAL: Not embedded in a 'diskuv-ocaml' repository" >&2 ; exit 1; fi

ParentProgressId=${ParentProgressId:--1}

# ----------------------------------------------------------------
# Progress Reporting

ProgressStep=0
ProgressActivity=
ProgressTotalSteps=2
ProgressId=$((ParentProgressId + 1))
WriteProgressStep() {
    # TODO: Would be nice to have a progress bar!
    local PercentComplete=$((100 * ProgressStep / ProgressTotalSteps))
    echo "($PercentComplete%) $ProgressActivity"
    ProgressStep=$((ProgressStep + 1))
}

# -------------------------
# TODO!

echo "FATAL: TODO. This will be released in a later version." >&2
