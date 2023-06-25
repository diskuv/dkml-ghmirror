if(NOT GIT_EXECUTABLE)
    message(FATAL_ERROR "Missing -D GIT_EXECUTABLE=xx")
endif()

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

# 1.2.1-2 -> 1.2.1-3
function(DkMLReleaseParticipant_PlainReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    string(REGEX REPLACE
        "${regex_DKML_VERSION_SEMVER}"
        "${DKML_VERSION_SEMVER_NEW}"
        contents_NEW "${contents}")

    if(contents STREQUAL "${contents_NEW}")
        cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
        message(FATAL_ERROR "The old version(s) ${regex_DKML_VERSION_SEMVER} were not found in ${FILENAME_ABS}")
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_SEMVER_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# version: "1.2.1~prerel2" -> version: "1.2.1~prerel3"
function(DkMLReleaseParticipant_OpamReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version: \"${regex_DKML_VERSION_OPAMVER}\""
        "\\1version: \"${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
        message(FATAL_ERROR "The old version(s) ${regex_DKML_VERSION_OPAMVER} were not found in ${FILENAME_ABS}")
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_OPAMVER_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# (version 1.2.1~prerel2) -> (version 1.2.1~prerel3)
function(DkMLReleaseParticipant_DuneProjectReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)[(]version ${regex_DKML_VERSION_OPAMVER}[)]"
        "\\1(version ${DKML_VERSION_OPAMVER_NEW})"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
        message(FATAL_ERROR "The old version(s) ${regex_DKML_VERSION_OPAMVER} were not found in ${FILENAME_ABS}")
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_OPAMVER_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
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

    if(contents STREQUAL "${contents_NEW}")
        cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
        message(FATAL_ERROR "The old version(s) ${regex_DKML_VERSION_OPAMVER} were not found in ${FILENAME_ABS}")
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_OPAMVER_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# dkml-apps,1.2.1~prerel2 -> dkml-apps,1.2.1~prerel3
# dkml-exe,1.2.1~prerel2 -> dkml-exe,1.2.1~prerel3
# with-dkml,1.2.1~prerel2 -> with-dkml,1.2.1~prerel3
function(DkMLReleaseParticipant_CreateOpamSwitchReplace REL_FILENAME)
    _DkMLReleaseParticipant_HelperApps(${REL_FILENAME} ",")
endfunction()

# dkml-apps.1.2.1~prerel2 -> dkml-apps.1.2.1~prerel3
# dkml-exe.1.2.1~prerel2 -> dkml-exe.1.2.1~prerel3
# with-dkml.1.2.1~prerel2 -> with-dkml.1.2.1~prerel3
function(DkMLReleaseParticipant_PkgsReplace REL_FILENAME)
    _DkMLReleaseParticipant_HelperApps(${REL_FILENAME} ".")
endfunction()

# version = "1.2.1~prerel2" -> version = "1.2.1~prerel3"
function(DkMLReleaseParticipant_MetaReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version *= *\"${regex_DKML_VERSION_OPAMVER}\""
        "\\1version = \"${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
        message(FATAL_ERROR "The old versions ${regex_DKML_VERSION_OPAMVER} were not found in ${FILENAME_ABS}")
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_OPAMVER_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# version: "4.14.0~v1.2.1~prerel2" -> version: "4.14.0~v1.2.1~prerel3"
# "dkml-runtime-common-native" {= "1.0.1"} -> "dkml-runtime-common-native" {= "1.0.2"}
# "dkml-runtime-common-native" {>= "1.0.1"} -> "dkml-runtime-common-native" {= "1.0.2"}
function(DkMLReleaseParticipant_DkmlBaseCompilerReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version: \"([0-9.]*)[~]v${regex_DKML_VERSION_OPAMVER}\""
        "\\1version: \"\\2~v${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    string(REGEX REPLACE
        "(^|\n[ ]*)\"dkml-runtime-common-native\" {>?= \"${regex_DKML_VERSION_OPAMVER}\"}"
        "\\1\"dkml-runtime-common-native\" {= \"${DKML_VERSION_OPAMVER_NEW}\"}"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
        message(FATAL_ERROR "The old version(s) ${regex_DKML_VERSION_OPAMVER} were not found in ${FILENAME_ABS}")
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_OPAMVER_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

function(DkMLReleaseParticipant_GitAddAndCommit)
    if(DRYRUN)
        return()
    endif()

    get_property(relFiles GLOBAL PROPERTY DkMLReleaseParticipant_REL_FILES)
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
