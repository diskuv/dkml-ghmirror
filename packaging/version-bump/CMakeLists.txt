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

function(stage_self_Changes BUMP_LEVEL NEW_VERSION_SEMVER OUTPUT_LIST_VARIABLE)
    file(READ ${PROJECT_SOURCE_DIR}/contributors/changes/v${NEW_VERSION_SEMVER}.md versionChanges)
    file(READ ${PROJECT_SOURCE_DIR}/CHANGES.md priorChanges)

    # First line in CHANGES.md should be a top-level heading "# CHANGES" to
    # be valid Markdown. So strip it so we can add it back.
    string(REGEX REPLACE "^# CHANGES[^\n]*\n" "" priorChanges "${priorChanges}")

    string(TIMESTAMP now_YYYYMMDD "%Y-%m-%d")
    string(REPLACE "@@YYYYMMDD@@" ${now_YYYYMMDD} versionChanges "${versionChanges}")

    string(STRIP "${versionChanges}" versionChanges)
    string(STRIP "${priorChanges}" priorChanges)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/_replace/${BUMP_LEVEL}/CHANGES.md "# CHANGES\n\n${versionChanges}\n\n${priorChanges}")

    # Add to list
    set(retval ${OUTPUT_LIST_VARIABLE})
    list(APPEND retval ${PROJECT_SOURCE_DIR}/CHANGES.md)
    set(${OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_GitTag_command)
    set(noValues)
    set(singleValues SOURCE_DIR BUMP_LEVEL OUTPUT_FILE CONTEXT)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(tag_COMMANDS)

    if(ARG_BUMP_LEVEL STREQUAL PRERELEASE)
        # Prereleases can always be overwritten, so delete the tag if present
        list(APPEND tag_COMMANDS
            COMMAND ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${ARG_CONTEXT}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -D GIT_TAG_TO_DELETE=${DKML_VERSION_SEMVER_NEW_PRERELEASE}
            -P ${CMAKE_CURRENT_LIST_DIR}/delete-tag-if-present.cmake)
    endif()

    add_custom_command(OUTPUT ${ARG_OUTPUT_FILE}
        WORKING_DIRECTORY ${ARG_SOURCE_DIR}
        DEPENDS
        ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver
        ${ARG_DEPENDS}

        ${tag_COMMANDS}
        COMMAND ${GIT_EXECUTABLE} tag -a ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}} -m ${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
        VERBATIM
        USES_TERMINAL
    )
endfunction()

function(add_VersionBump_commands_for_synced_projects)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})

    # For PRERELEASE we want fuzzy matching on any prior PRERELEASE because
    # we expect partial completions during PRERELEASE.
    #
    # For example, a PRERELEASE bump could be successful for half of
    # the packages, but then terminated due to a failure (perhaps this script
    # has a bug!). The failure would get fixed. Then a new PRERELEASE bump
    # occurs. Once it finishes end-to-end without failures ... only then
    # do you do a PATCH (or MINOR or MAJOR) bump.
    if(ARG_BUMP_LEVEL STREQUAL "PRERELEASE")
        set(regex_DKML_VERSION_SEMVER "${DKML_VERSION_MAJMINPAT}-[0-9]+")
        set(regex_DKML_VERSION_OPAMVER "${DKML_VERSION_MAJMINPAT}[~]prerel[0-9]+")
    else()
        set(regex_DKML_VERSION_SEMVER "${DKML_VERSION_SEMVER}")
        set(regex_DKML_VERSION_OPAMVER "${DKML_VERSION_OPAMVER}")
    endif()

    string(REPLACE "." "[.]" regex_DKML_VERSION_SEMVER "${regex_DKML_VERSION_SEMVER}")
    string(REPLACE "." "[.]" regex_DKML_VERSION_OPAMVER "${regex_DKML_VERSION_OPAMVER}")

    foreach(proj IN LISTS syncedProjects)
        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/VersionBump/${proj})

        # Set <proj>_SOURCE_DIR
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})

        if(NOT srcDir)
            message(FATAL_ERROR "No FetchContent_MakeAvailable(${proj}) has been performed in dependencies/")
        endif()

        if(NOT EXISTS ${srcDir}/bump-version.cmake)
            message(FATAL_ERROR "${proj} has no bump-version.cmake")
        endif()

        add_custom_command(OUTPUT ${outputDir}/bumped-${ARG_BUMP_LEVEL}
            WORKING_DIRECTORY ${srcDir}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver
            COMMAND ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D DKML_RELEASE_OCAML_VERSION=${DKML_RELEASE_OCAML_VERSION}
            -D "DKML_RELEASE_PARTICIPANT_MODULE=${CMAKE_CURRENT_LIST_DIR}/DkMLReleaseParticipant.cmake"
            -D regex_DKML_VERSION_OPAMVER=${regex_DKML_VERSION_OPAMVER}
            -D regex_DKML_VERSION_SEMVER=${regex_DKML_VERSION_SEMVER}
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -P bump-version.cmake
            VERBATIM
            USES_TERMINAL
        )

        add_GitTag_command(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            SOURCE_DIR ${srcDir}
            CONTEXT ${proj}
            OUTPUT_FILE ${outputDir}/tagged-${ARG_BUMP_LEVEL}
            DEPENDS
            ${outputDir}/bumped-${ARG_BUMP_LEVEL})
        list(APPEND retval ${outputDir}/tagged-${ARG_BUMP_LEVEL})
    endforeach()

    # Add to list
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_GitPush_command)
    set(noValues)
    set(singleValues SOURCE_DIR BUMP_LEVEL OUTPUT_FILE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    add_custom_command(OUTPUT ${ARG_OUTPUT_FILE}
        WORKING_DIRECTORY ${ARG_SOURCE_DIR}
        DEPENDS
        ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver
        ${ARG_DEPENDS}

        COMMAND ${GIT_EXECUTABLE} push --atomic origin main ${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}
        VERBATIM
        USES_TERMINAL
    )
endfunction()

function(add_GitPush_commands_for_synced_projects)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})

    foreach(proj IN LISTS syncedProjects)
        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/GitPush/${proj})

        # Set <proj>_SOURCE_DIR
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})

        if(NOT srcDir)
            message(FATAL_ERROR "No FetchContent_MakeAvailable(${proj}) has been performed in dependencies/")
        endif()

        add_GitPush_command(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            SOURCE_DIR ${srcDir}
            OUTPUT_FILE ${outputDir}/pushed-${ARG_BUMP_LEVEL}
            DEPENDS
            ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver
            ${ARG_DEPENDS})
        list(APPEND retval ${outputDir}/pushed-${ARG_BUMP_LEVEL})
    endforeach()

    # Add to list
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_all_targets BUMP_LEVEL)
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
        stage_self_Changes(${BUMP_LEVEL}
            ${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}
            selfModifications)
    endif()

    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/self/bumped-${BUMP_LEVEL}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/_replace/${BUMP_LEVEL} .
        COMMAND ${GIT_EXECUTABLE} -c core.safecrlf=false add ${selfModifications}
        COMMAND ${GIT_EXECUTABLE} commit -m "Bump version: ${DKML_VERSION_SEMVER} -> ${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}"
        VERBATIM)
    add_GitTag_command(
        BUMP_LEVEL ${BUMP_LEVEL}
        CONTEXT self
        OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/self/tagged-${BUMP_LEVEL}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/self/bumped-${BUMP_LEVEL})
    add_GitPush_command(
        BUMP_LEVEL ${BUMP_LEVEL}
        SOURCE_DIR ${PROJECT_SOURCE_DIR}
        OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/self/pushed-${BUMP_LEVEL}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/self/tagged-${BUMP_LEVEL})

    set(versionBumpTargetDepends ${CMAKE_CURRENT_BINARY_DIR}/self/tagged-${BUMP_LEVEL})
    set(gitPushTargetDepends ${CMAKE_CURRENT_BINARY_DIR}/self/pushed-${BUMP_LEVEL})

    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE versionBumpTargetDepends)
    add_GitPush_commands_for_synced_projects(
        BUMP_LEVEL ${BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE gitPushTargetDepends
        DEPENDS ${versionBumpTargetDepends})

    add_custom_target(Package-${BUMP_LEVEL}-Stage1-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver ${versionBumpTargetDepends}
        VERBATIM)
    add_custom_target(Package-${BUMP_LEVEL}-Stage4-GitPush
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver ${gitPushTargetDepends}
        VERBATIM)
    add_dependencies(Package-${BUMP_LEVEL}-Stage4-GitPush Package-${BUMP_LEVEL}-Stage1-VersionBump)
endfunction()

add_all_targets(PRERELEASE)
add_all_targets(PATCH)

# TODO:

# 1. Save the [git push] of all the synced projects until step [2] and [3] are done.

# 2. [release.sh] starting from line ~450 changes [dkml-component-desktop] and
# waits for it to build. The release.sh changes are all to get the code we already checked
# out, and are complicated because release.sh does not let [dune] autogenerate
# all the .opam files. So we run [dune] and add the changed .opam files!
# * However, we'll need to download a version of dune (easy).
# * We'll need to create an opam switch to build [dkml-component-desktop] ... just
# use [setup-dkml] desktop scripts to do that. Actually, can just use
# [dkml-component-desktop] .gitlab-ci.yml (just run the ci/ scripts manually).

# 3. Build [dkml-installer-ocaml]

# 4. Do [git push] of all synced projects _and_ [self]