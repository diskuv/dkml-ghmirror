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

# Calculate what the new prerelease would be
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

set_new_prerelease_version()
file(CONFIGURE OUTPUT new-version CONTENT "@DKML_VERSION_SEMVER_NEW_PRERELEASE@" @ONLY NEWLINE_STYLE UNIX)

# ----------------
#
set(versionBumpTargetDepends)

# ----------------
#

# Stage a new version of version.cmake and README.md
set(version.cmake_STAGED_PRERELEASE ${CMAKE_CURRENT_BINARY_DIR}/version-new_prerelease.cmake)
set(README_STAGED_PRERELEASE ${CMAKE_CURRENT_BINARY_DIR}/README-new_prerelease.md)

function(stage_self REL_FILENAME)
    file(READ ${PROJECT_SOURCE_DIR}/${REL_FILENAME} contents)
    string(REPLACE "${DKML_VERSION_CMAKEVER}" "${DKML_VERSION_CMAKEVER_NEW_PRERELEASE}" contents_NEW "${contents}")

    if(contents STREQUAL "${contents_NEW}")
        message(FATAL_ERROR "The old version ${DKML_VERSION_CMAKEVER} was not found in ${PROJECT_SOURCE_DIR}/version.cmake")
    endif()

    file(WRITE ${PROJECT_SOURCE_DIR}/${REL_FILENAME} "${contents_NEW}")
endfunction()

stage_self(version.cmake)
stage_self(README.md)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/self/committed
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-version
    COMMAND ${CMAKE_COMMAND} -E copy ${version.cmake_STAGED_PRERELEASE} version.cmake
    COMMAND ${CMAKE_COMMAND} -E copy ${README_STAGED_PRERELEASE} README.md
    COMMAND ${GIT_EXECUTABLE} -c core.safecrlf=false add version.cmake README.md
    COMMAND ${GIT_EXECUTABLE} commit -m "Bump version: ${DKML_VERSION_SEMVER} -> ${DKML_VERSION_SEMVER_NEW_PRERELEASE}"
    VERBATIM)

list(APPEND versionBumpTargetDepends ${CMAKE_CURRENT_BINARY_DIR}/self/committed)

#
# ----------------

# ----------------
#
function(bump_synced_projects)
    foreach(proj IN LISTS syncedProjects)
        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/${proj})

        # Set <proj>_SOURCE_DIR
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})

        if(NOT srcDir)
            message(FATAL_ERROR "No FetchContent_MakeAvailable(${proj}) has been performed in dependencies/")
        endif()

        if(NOT EXISTS ${srcDir}/bump-version.cmake)
            message(STATUS "Skipping prerelease bump of ${proj} since it has no bump-version.cmake")
            continue()
        endif()

        add_custom_command(OUTPUT ${outputDir}/bumped-prerelease
            WORKING_DIRECTORY ${srcDir}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-version
            COMMAND ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D DKML_VERSION_OPAMVER=${DKML_VERSION_OPAMVER}
            -D DKML_VERSION_SEMVER=${DKML_VERSION_SEMVER}
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_PRERELEASE}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_PRERELEASE}
            -D "DKML_RELEASE_PARTICIPANT_MODULE=${CMAKE_CURRENT_LIST_DIR}/DkMLReleaseParticipant.cmake"
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -P bump-version.cmake
            VERBATIM
            USES_TERMINAL
        )

        add_custom_command(OUTPUT ${outputDir}/tagged
            MAIN_DEPENDENCY ${outputDir}/bumped-prerelease
            WORKING_DIRECTORY ${srcDir}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-version

            # Prereleases can always be overwritten, so delete the tag if present
            COMMAND ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -D GIT_TAG_TO_DELETE=${DKML_VERSION_SEMVER_NEW_PRERELEASE}
            -P ${CMAKE_CURRENT_LIST_DIR}/delete-tag-if-present.cmake
            COMMAND ${GIT_EXECUTABLE} tag -a ${DKML_VERSION_SEMVER_NEW_PRERELEASE} -m ${DKML_VERSION_OPAMVER_NEW_PRERELEASE}
            COMMAND ${GIT_EXECUTABLE} push --atomic origin main ${DKML_VERSION_SEMVER_NEW_PRERELEASE}
            VERBATIM
            USES_TERMINAL
        )

        # list(APPEND versionBumpTargetDepends ${outputDir}/tagged)
    endforeach()
endfunction()

bump_synced_projects()

add_custom_target(VersionBumpPrelease
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-version ${versionBumpTargetDepends}
    VERBATIM)