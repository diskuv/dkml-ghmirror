set(DKML_RELEASE_OCAML_VERSION 4.14.0)
include(${PROJECT_SOURCE_DIR}/version.cmake)

find_program(GIT_EXECUTABLE NAMES git DOC "Git" REQUIRED)
set(BUMP2VERSION_EXECUTABLE "${CONDA_EXECUTABLE}" run -n "${CONDA_ENVIRONMENT}" --live-stream bump2version)

set(syncedProjects
    diskuv-opam-repository
    dkml-compiler
    dkml-runtime-common
    dkml-runtime-distribution
)

# ----------------
#
# Pre-calculate content for new prerelease,patch,etc. bumped versions
function(set_new_prerelease_version)
    if(DKML_VERSION_PRERELEASE)
        math(EXPR new_prerelease "${DKML_VERSION_PRERELEASE} + 1")
        set(new_patch "${DKML_VERSION_PATCH}")
    else()
        set(new_prerelease 1)
        math(EXPR new_patch "${DKML_VERSION_PATCH} + 1")
    endif()

    set(DKML_VERSION_CMAKEVER_NEW_PRERELEASE ${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${new_patch}.${new_prerelease} PARENT_SCOPE)
    set(DKML_VERSION_SEMVER_NEW_PRERELEASE ${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${new_patch}-${new_prerelease} PARENT_SCOPE)
    set(DKML_VERSION_OPAMVER_NEW_PRERELEASE ${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${new_patch}~prerel${new_prerelease} PARENT_SCOPE)
endfunction()

function(set_new_patch_version)
    if(DKML_VERSION_PRERELEASE)
        set(new_patch "${DKML_VERSION_PATCH}") # Pre-releases are _before_ a non-prerelease
    else()
        math(EXPR new_patch "${DKML_VERSION_PATCH} + 1") # No pre-release
    endif()

    set(DKML_VERSION_CMAKEVER_NEW_PATCH ${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${new_patch} PARENT_SCOPE)
    set(DKML_VERSION_SEMVER_NEW_PATCH ${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${new_patch} PARENT_SCOPE)
    set(DKML_VERSION_OPAMVER_NEW_PATCH ${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${new_patch} PARENT_SCOPE)
endfunction()

set_new_prerelease_version()
set_new_patch_version()
file(CONFIGURE OUTPUT new-PRERELEASE-semver CONTENT "@DKML_VERSION_SEMVER_NEW_PRERELEASE@" @ONLY NEWLINE_STYLE UNIX)
file(CONFIGURE OUTPUT new-PATCH-semver CONTENT "@DKML_VERSION_SEMVER_NEW_PATCH@" @ONLY NEWLINE_STYLE UNIX)

# ----------------
#

# ----------------
#
function(stage_self_VersionReplace BUMP_LEVEL NEW_VERSION_CMAKEVER NEW_PUBLICVERSION_CMAKEVER OUTPUT_LIST_VARIABLE REL_FILENAME)
    file(READ ${PROJECT_SOURCE_DIR}/${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REPLACE
        "DKML_VERSION_CMAKEVER \"${DKML_VERSION_CMAKEVER}\""
        "DKML_VERSION_CMAKEVER \"${NEW_VERSION_CMAKEVER}\""
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        message(FATAL_ERROR "The version ${DKML_VERSION_CMAKEVER} was not found in ${PROJECT_SOURCE_DIR}/${REL_FILENAME}")
    endif()

    if(NOT(BUMP_LEVEL STREQUAL "PRERELEASE"))
        # PATCH, MINOR or MAJOR
        set(contents_LAST ${contents_NEW})
        string(REPLACE
            "DKML_PUBLICVERSION_CMAKEVER \"${DKML_PUBLICVERSION_CMAKEVER}\""
            "DKML_PUBLICVERSION_CMAKEVER \"${NEW_PUBLICVERSION_CMAKEVER}\""
            contents_NEW "${contents_NEW}")

        if(contents_LAST STREQUAL "${contents_NEW}")
            message(FATAL_ERROR "The public version ${DKML_PUBLICVERSION_CMAKEVER} was not found in ${PROJECT_SOURCE_DIR}/${REL_FILENAME}")
        endif()
    endif()

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/_replace/${BUMP_LEVEL}/${REL_FILENAME} "${contents_NEW}")

    # Add to list
    set(retval ${${OUTPUT_LIST_VARIABLE}})
    list(APPEND retval ${PROJECT_SOURCE_DIR}/${REL_FILENAME})
    set(${OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(stage_self_DkMLReplace BUMP_LEVEL NEW_VERSION_SEMVER OUTPUT_LIST_VARIABLE REL_FILENAME)
    file(READ ${PROJECT_SOURCE_DIR}/${REL_FILENAME} contents)
    string(REGEX REPLACE "DkML [0-9.-]+" "DkML ${NEW_VERSION_SEMVER}" contents_NEW "${contents}")

    if(contents STREQUAL "${contents_NEW}")
        message(FATAL_ERROR "A DkML version was not found in ${PROJECT_SOURCE_DIR}/${REL_FILENAME}")
    endif()

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/_replace/${BUMP_LEVEL}/${REL_FILENAME} "${contents_NEW}")

    # Add to list
    set(retval ${OUTPUT_LIST_VARIABLE})
    list(APPEND retval ${PROJECT_SOURCE_DIR}/${REL_FILENAME})
    set(${OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_bump_commands_for_synced_projects BUMP_LEVEL OUTPUT_LIST_VARIABLE)
    set(retval ${${OUTPUT_LIST_VARIABLE}})

    # For PRERELEASE we want fuzzy matching on any prior PRERELEASE because
    # we expect partial completions during PRERELEASE.
    #
    # For example, a PRERELEASE bump could be successful for half of
    # the packages, but then terminated due to a failure (perhaps this script
    # has a bug!). The failure would get fixed. Then a new PRERELEASE bump
    # occurs. Once it finishes end-to-end without failures ... only then
    # do you do a PATCH (or MINOR or MAJOR) bump.
    if(BUMP_LEVEL STREQUAL "PRERELEASE")
        set(regex_DKML_VERSION_SEMVER "${DKML_VERSION_MAJMINPAT}-[0-9]+")
        set(regex_DKML_VERSION_OPAMVER "${DKML_VERSION_MAJMINPAT}[~]prerel[0-9]+")
    else()
        set(regex_DKML_VERSION_SEMVER "${DKML_VERSION_SEMVER}")
        set(regex_DKML_VERSION_OPAMVER "${DKML_VERSION_OPAMVER}")
    endif()

    string(REPLACE "." "[.]" regex_DKML_VERSION_SEMVER "${regex_DKML_VERSION_SEMVER}")
    string(REPLACE "." "[.]" regex_DKML_VERSION_OPAMVER "${regex_DKML_VERSION_OPAMVER}")

    foreach(proj IN LISTS syncedProjects)
        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/${proj})

        # Set <proj>_SOURCE_DIR
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})

        if(NOT srcDir)
            message(FATAL_ERROR "No FetchContent_MakeAvailable(${proj}) has been performed in dependencies/")
        endif()

        if(NOT EXISTS ${srcDir}/bump-version.cmake)
            message(STATUS "Skipping ${BUMP_LEVEL} bump of ${proj} since it has no bump-version.cmake")
            continue()
        endif()

        add_custom_command(OUTPUT ${outputDir}/bumped-${BUMP_LEVEL}
            WORKING_DIRECTORY ${srcDir}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver
            COMMAND ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D DKML_RELEASE_OCAML_VERSION=${DKML_RELEASE_OCAML_VERSION}
            -D "DKML_RELEASE_PARTICIPANT_MODULE=${CMAKE_CURRENT_LIST_DIR}/DkMLReleaseParticipant.cmake"
            -D regex_DKML_VERSION_OPAMVER=${regex_DKML_VERSION_OPAMVER}
            -D regex_DKML_VERSION_SEMVER=${regex_DKML_VERSION_SEMVER}
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_PRERELEASE}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_PRERELEASE}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -P bump-version.cmake
            VERBATIM
            USES_TERMINAL
        )

        set(tag_COMMANDS)

        if(BUMP_LEVEL STREQUAL PRERELEASE)
            # Prereleases can always be overwritten, so delete the tag if present
            list(APPEND tag_COMMANDS
                COMMAND ${CMAKE_COMMAND}
                --log-context
                -D CMAKE_MESSAGE_CONTEXT=${proj}
                -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
                -D GIT_TAG_TO_DELETE=${DKML_VERSION_SEMVER_NEW_PRERELEASE}
                -P ${CMAKE_CURRENT_LIST_DIR}/delete-tag-if-present.cmake)
        endif()

        add_custom_command(OUTPUT ${outputDir}/tagged-${BUMP_LEVEL}
            MAIN_DEPENDENCY ${outputDir}/bumped-${BUMP_LEVEL}
            WORKING_DIRECTORY ${srcDir}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver

            ${tag_COMMANDS}
            COMMAND ${GIT_EXECUTABLE} tag -a ${DKML_VERSION_SEMVER_NEW_PRERELEASE} -m ${DKML_VERSION_OPAMVER_NEW_PRERELEASE}
            COMMAND ${GIT_EXECUTABLE} push --atomic origin main ${DKML_VERSION_SEMVER_NEW_PRERELEASE}
            VERBATIM
            USES_TERMINAL
        )
        list(APPEND retval ${outputDir}/tagged-${BUMP_LEVEL})
    endforeach()

    # Add to list
    set(${OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_version_bump_target BUMP_LEVEL)
    set(selfModifications)

    if(BUMP_LEVEL STREQUAL "PRERELEASE")
        # PRERELEASE bump
        stage_self_VersionReplace(${BUMP_LEVEL}
            ${DKML_VERSION_CMAKEVER_NEW_${BUMP_LEVEL}}

            # No change to the public version
            ${DKML_PUBLICVERSION_CMAKEVER}
            selfModifications version.cmake)
    else()
        # PATCH, MINOR or MAJOR bump
        stage_self_VersionReplace(${BUMP_LEVEL}
            ${DKML_VERSION_CMAKEVER_NEW_${BUMP_LEVEL}}
            ${DKML_VERSION_CMAKEVER_NEW_${BUMP_LEVEL}}
            selfModifications version.cmake)
        stage_self_DkMLReplace(${BUMP_LEVEL}
            ${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}
            selfModifications README.md)
    endif()

    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/self/committed-${BUMP_LEVEL}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/_replace/${BUMP_LEVEL} .
        COMMAND ${GIT_EXECUTABLE} -c core.safecrlf=false add ${selfModifications}
        COMMAND ${GIT_EXECUTABLE} commit -m "Bump version: ${DKML_VERSION_SEMVER} -> ${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}"
        VERBATIM)

    set(versionBumpTargetDepends ${CMAKE_CURRENT_BINARY_DIR}/self/committed-${BUMP_LEVEL})

    add_bump_commands_for_synced_projects(${BUMP_LEVEL} versionBumpTargetDepends)
    add_custom_target(VersionBump-${BUMP_LEVEL}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver ${versionBumpTargetDepends}
        VERBATIM)
endfunction()

add_version_bump_target(PRERELEASE)
add_version_bump_target(PATCH)
