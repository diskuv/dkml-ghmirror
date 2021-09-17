#!/bin/bash
set -euf -o pipefail

# This file is a transliteration of `install-world.ps1`.
# Consider the variable and method naming of PowerShell scripts to be authoritative.

# DKML_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/diskuv-ocaml"
# DKMLVARS_SH="$DKML_DATA/dkmlvars.sh"

# cat <<EOF
# DiskuvOCamlVarsVersion=1
# DiskuvOCamlHome='/c/Users/beckf/AppData/Local/Programs/DiskuvOCaml/2'
# DiskuvOCamlBinaryPaths='/c/Users/beckf/AppData/Local/Programs/DiskuvOCaml/2/bin'
# EOF

HereDir=$(dirname "$0")
HereDir=$(cd "$HereDir" && pwd)

DkmlDir=$(cd "$HereDir/../.." && pwd)
if [[ ! -e "$DkmlDir/.dkmlroot" ]]; then echo "FATAL: Not embedded in a 'diskuv-ocaml' repository" >&2 ; exit 1; fi

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

# ----------------------------------------------------------------
# BEGIN Setup machine

ProgressActivity="Setup machine"

env ParentProgressId=$ProgressId "$HereDir"/setup-machine.sh

# END Setup machine
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Setup home

ProgressActivity="Setup home"

env ParentProgressId=$ProgressId "$HereDir"/setup-home.sh

# END Setup home
# ----------------------------------------------------------------
