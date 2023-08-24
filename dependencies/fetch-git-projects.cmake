# This script exists, isolated from the other declarations, to allow the
# DkML project to get the correct versions in its `git-clone.sh`.
#
# This script is patterned after dksdk-cmake's script of the same name.
#
# It can be run in two ways:
# 1. In script mode with -D FETCH_GIT_EXPORT_TYPE=shell -P. That will output (on the
# standard output) shell variables of the form GIT_TAG_<name>=<value>.
# The name will be sanitized as a C identifier with
# string(MAKE_C_IDENTIFIER) and then upper-cased. So dkml-compiler would be
# GIT_TAG_DKML_COMPILER.
# 2. Included in a CMakeLists.txt

include(FetchContent)

function(FetchGit)
    # Parsing
    set(prefix ARG)
    set(noValues)
    set(singleValues GIT_REPOSITORY GIT_TAG)
    set(multiValues)
    cmake_parse_arguments(
        PARSE_ARGV 1 # start after the <name>
        ${prefix}
        "${noValues}" "${singleValues}" "${multiValues}"
    )

    set(name ${ARGV0}) # the <name>

    if(CMAKE_SCRIPT_MODE_FILE)
        if(FETCH_GIT_EXPORT_TYPE STREQUAL shell)
            string(MAKE_C_IDENTIFIER "${name}" nameSanitized)
            string(TOUPPER "${nameSanitized}" nameSanitizedUpper)

            if(DEFINED ENV{GIT_TAG_${nameSanitizedUpper}})
                set(value "GIT_TAG_${nameSanitizedUpper}='$ENV{GIT_TAG_${nameSanitizedUpper}}'")
            else()
                set(value "GIT_TAG_${nameSanitizedUpper}='${ARG_GIT_TAG}'")
            endif()
            if(FETCH_GIT_EXPORT_FILE)
                file(APPEND "${FETCH_GIT_EXPORT_FILE}" "${value}\n")
            else()
                message(NOTICE "${value}")
            endif()
        else()
            message(FATAL_ERROR "-D FETCH_GIT_EXPORT_TYPE= is not defined or is not 'shell'")
        endif()
    else()
        FetchContent_Declare(${name}
            GIT_REPOSITORY ${ARG_GIT_REPOSITORY}
            GIT_TAG ${ARG_GIT_TAG}
        )
    endif()
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    if(FETCH_GIT_EXPORT_FILE)
        file(WRITE "${FETCH_GIT_EXPORT_FILE}" "")
    endif()
endif()

FetchGit(diskuv-opam-repository
    GIT_REPOSITORY https://github.com/diskuv/diskuv-opam-repository.git
    GIT_TAG main # 315a344b354e883c0884eefdb7869a20d1ef5803 # 1.2.1-prerel1
)
FetchGit(dkml-compiler
    GIT_REPOSITORY https://github.com/diskuv/dkml-compiler.git
    GIT_TAG main # fd73aa1567099344e5d12c7acbc2a13cf1a9cd20 # 1.2.1-prerel1 + commits
)
FetchGit(dkml-component-desktop
    GIT_REPOSITORY https://gitlab.com/dkml/components/dkml-component-desktop.git
    GIT_TAG main
)
FetchGit(dkml-install-api
    GIT_REPOSITORY https://github.com/diskuv/dkml-install-api.git
    GIT_TAG 0.5 # TODO: Release this to opam repository
)
FetchGit(dkml-installer-ocaml
    GIT_REPOSITORY https://github.com/diskuv/dkml-installer-ocaml.git
    GIT_TAG main
)
FetchGit(dkml-installer-ocaml-byte
    GIT_REPOSITORY https://github.com/diskuv/dkml-installer-ocaml-byte.git
    GIT_TAG main
)
FetchGit(dkml-runtime-apps
    GIT_REPOSITORY https://github.com/diskuv/dkml-runtime-apps.git
    GIT_TAG main
)
FetchGit(dkml-runtime-common
    GIT_REPOSITORY https://github.com/diskuv/dkml-runtime-common.git
    GIT_TAG main # 90426df0bdda1e0cb7675b6f746aa152b222c6c8 # 1.2.1-prerel1 + commits
)
FetchGit(dkml-runtime-distribution
    GIT_REPOSITORY https://github.com/diskuv/dkml-runtime-distribution.git
    GIT_TAG main # b1a1403eded259a49a57134054633df526d3addb # 1.2.1-prerel1 + commits
)
FetchGit(dkml-component-curl
    GIT_REPOSITORY https://github.com/diskuv/dkml-component-curl.git
    GIT_TAG main
)
FetchGit(dkml-component-ocamlrun
    GIT_REPOSITORY https://github.com/diskuv/dkml-component-ocamlrun.git
    GIT_TAG main
)
FetchGit(dkml-component-ocamlcompiler
    GIT_REPOSITORY https://github.com/diskuv/dkml-component-ocamlcompiler.git
    GIT_TAG main
)
FetchGit(dkml-component-unixutils
    GIT_REPOSITORY https://github.com/diskuv/dkml-component-unixutils.git
    GIT_TAG main
)
FetchGit(dkml-component-opam
    GIT_REPOSITORY https://github.com/diskuv/dkml-component-opam.git
    GIT_TAG main # daadfea83269e07b2e880e085e0a468b2ddeae6e
)
FetchGit(dkml-c-probe
    GIT_REPOSITORY https://github.com/diskuv/dkml-c-probe.git
    GIT_TAG main # 20802884d9f5da9030d368cf48aec3f8ddf63c76 # Past v3.0.0
)
FetchGit(dkml-workflows
    # GIT_REPOSITORY https://github.com/diskuv/dkml-workflows.git GIT_TAG v1
    # GIT_REPOSITORY https://github.com/diskuv/dkml-workflows-prerelease.git GIT_TAG 36e82632d9a4a789817dcadb23bf81755a7c9dd1 # has SKIP_OPAM_MODIFICATIONS
    GIT_REPOSITORY https://github.com/diskuv/dkml-workflows-prerelease.git
    GIT_TAG v1
)