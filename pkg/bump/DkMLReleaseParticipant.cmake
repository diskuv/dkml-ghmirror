include(${CMAKE_CURRENT_LIST_DIR}/DkMLReleaseParticipant_core.cmake)

# TODO: This file should be renamed DkMLBumpVersionParticipant.cmake

if(NOT DKML_RELEASE_OCAML_VERSION)
    message(FATAL_ERROR "Missing -D DKML_RELEASE_OCAML_VERSION=xx")
endif()

if(NOT regex_DKML_VERSION_OPAMVER)
    message(FATAL_ERROR "Missing -D regex_DKML_VERSION_OPAMVER=xx")
endif()

if(NOT regex_DKML_VERSION_SEMVER)
    message(FATAL_ERROR "Missing -D regex_DKML_VERSION_SEMVER=xx")
endif()

if(NOT DKML_VERSION_OPAMVER_NEW)
    message(FATAL_ERROR "Missing -D DKML_VERSION_OPAMVER_NEW=xx")
endif()

if(NOT DKML_VERSION_SEMVER_NEW)
    message(FATAL_ERROR "Missing -D DKML_VERSION_SEMVER_NEW=xx")
endif()

macro(_DkMLReleaseParticipant_Finish_Replace VERSION_TYPE)
    if(contents STREQUAL "${contents_NEW}")
        string(FIND "${contents_NEW}" "${DKML_VERSION_${VERSION_TYPE}_NEW}" idempotent)

        if(idempotent LESS 0)
            cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
            message(FATAL_ERROR "The old version(s) ${regex_DKML_VERSION_${VERSION_TYPE}} were not found in ${FILENAME_ABS} or the file already had the new version ${DKML_VERSION_${VERSION_TYPE}_NEW} derived from the DKML_VERSION_CMAKEVER value in version.cmake")
        endif()

        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_${VERSION_TYPE}_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endmacro()

# 1.2.1-2 -> 1.2.1-3
function(DkMLReleaseParticipant_PlainReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    string(REGEX REPLACE
        "${regex_DKML_VERSION_SEMVER}"
        "${DKML_VERSION_SEMVER_NEW}"
        contents_NEW "${contents}")

    _DkMLReleaseParticipant_Finish_Replace(SEMVER)
endfunction()

# version: "1.2.1~prerel2" -> version: "1.2.1~prerel3"
function(DkMLReleaseParticipant_OpamReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version: \"${regex_DKML_VERSION_OPAMVER}\""
        "\\1version: \"${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")
    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# (version 1.2.1~prerel2) -> (version 1.2.1~prerel3)
function(DkMLReleaseParticipant_DuneProjectReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)[(]version ${regex_DKML_VERSION_OPAMVER}[)]"
        "\\1(version ${DKML_VERSION_OPAMVER_NEW})"
        contents_NEW "${contents_NEW}")
    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# dkml-apps,1.2.1~prerel2 -> dkml-apps,1.2.1~prerel3
# dkml-exe,1.2.1~prerel2 -> dkml-exe,1.2.1~prerel3
# with-dkml,1.2.1~prerel2 -> with-dkml,1.2.1~prerel3
function(_DkMLReleaseParticipant_HelperApps REL_FILENAME SEPARATOR)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    set(regex_SEPARATOR "${SEPARATOR}")
    string(REPLACE "." "[.]" regex_SEPARATOR "${regex_SEPARATOR}")
    string(REPLACE "~" "[~]" regex_SEPARATOR "${regex_SEPARATOR}")

    foreach(pkg IN ITEMS dkml-apps dkml-exe with-dkml)
        string(REGEX REPLACE # Match at beginning of line: ^|\n
            "(^|\n)([ ]*)${pkg}${regex_SEPARATOR}${regex_DKML_VERSION_OPAMVER}"
            "\\1\\2${pkg}${SEPARATOR}${DKML_VERSION_OPAMVER_NEW}"
            contents_NEW "${contents_NEW}")
    endforeach()

    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# dkml-apps.1.2.1~prerel2 -> dkml-apps.1.2.1~prerel3
# dkml-exe.1.2.1~prerel2 -> dkml-exe.1.2.1~prerel3
# with-dkml.1.2.1~prerel2 -> with-dkml.1.2.1~prerel3
function(DkMLReleaseParticipant_PkgsReplace REL_FILENAME)
    _DkMLReleaseParticipant_HelperApps(${REL_FILENAME} ".")
endfunction()

# OCAML_DEFAULT_VERSION=4.14.0 -> OCAML_DEFAULT_VERSION=4.14.2
function(DkMLReleaseParticipant_CreateOpamSwitchReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)OCAML_DEFAULT_VERSION=[0-9.]+"
        "\\1OCAML_DEFAULT_VERSION=${DKML_RELEASE_OCAML_VERSION}"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_RELEASE_OCAML_VERSION}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# version = "1.2.1~prerel2" -> version = "1.2.1~prerel3"
function(DkMLReleaseParticipant_MetaReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version *= *\"${regex_DKML_VERSION_OPAMVER}\""
        "\\1version = \"${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# version: "4.14.0~v1.2.1~prerel2" -> version: "4.14.0~v1.2.1~prerel3"
# "dkml-runtime-common-native" {= "1.0.1"} -> "dkml-runtime-common-native" {= "1.0.2"}
# "dkml-runtime-common-native" {>= "1.0.1"} -> "dkml-runtime-common-native" {= "1.0.2"}
function(DkMLReleaseParticipant_DkmlBaseCompilerReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version: \"([0-9.]*)[~]v${regex_DKML_VERSION_OPAMVER}\""
        "\\1version: \"${DKML_RELEASE_OCAML_VERSION}~v${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    string(REGEX REPLACE
        "(^|\n[ ]*)\"dkml-runtime-common-native\" {>?= \"${regex_DKML_VERSION_OPAMVER}\"}"
        "\\1\"dkml-runtime-common-native\" {= \"${DKML_VERSION_OPAMVER_NEW}\"}"
        contents_NEW "${contents_NEW}")

    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# ("DEFAULT_DKML_COMPILER", "4.14.0-v1.1.0-prerel15"); -> ("DEFAULT_DKML_COMPILER", "4.14.0-v1.2.1-3");
function(DkMLReleaseParticipant_ModelReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "\"DEFAULT_DKML_COMPILER\", \"([0-9.]*)-v${regex_DKML_VERSION_SEMVER}\""
        "\"DEFAULT_DKML_COMPILER\", \"${DKML_RELEASE_OCAML_VERSION}-v${DKML_VERSION_SEMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    _DkMLReleaseParticipant_Finish_Replace(SEMVER)
endfunction()

function(DkMLReleaseParticipant_GitAddAndCommit)
    if(DRYRUN)
        return()
    endif()

    get_property(relFiles GLOBAL PROPERTY DkMLReleaseParticipant_REL_FILES)

    if(NOT relFiles)
        return()
    endif()

    execute_process(
        COMMAND
        ${GIT_EXECUTABLE} -c core.safecrlf=false add ${relFiles}
        COMMAND_ERROR_IS_FATAL ANY
    )
    execute_process(
        COMMAND
        ${GIT_EXECUTABLE} commit -m "Version: ${DKML_VERSION_SEMVER_NEW}"
        ENCODING UTF-8
        COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()
