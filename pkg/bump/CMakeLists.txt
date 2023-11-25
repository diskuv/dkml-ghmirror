set(DKML_RELEASE_OCAML_VERSION 4.14.0)
include(${PROJECT_SOURCE_DIR}/version.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLAnyRun.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLBumpLevels.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLPackages.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLPatches.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLPublish.cmake)

if(CMAKE_HOST_WIN32)
    find_program(POWERSHELL_EXECUTABLE NAMES pwsh powershell REQUIRED)
endif()

find_program(GIT_EXECUTABLE NAMES git DOC "Git" REQUIRED)
set(BUMP2VERSION_EXECUTABLE "${CONDA_EXECUTABLE}" run -n "${CONDA_ENVIRONMENT}" --live-stream bump2version)

cmake_path(GET GIT_EXECUTABLE PARENT_PATH GIT_EXECUTABLE_DIR)

set(self_BRANCH next) # self is [dkml]
set(diskuv-opam-repository_BRANCH main)
set(dkml-compiler_BRANCH main)
set(dkml-component-curl_BRANCH main)
set(dkml-component-desktop_BRANCH main)
set(dkml-component-ocamlcompiler_BRANCH main)
set(dkml-component-ocamlrun_BRANCH main)
set(dkml-installer-ocaml_BRANCH main)
set(dkml-installer-ocaml-byte_BRANCH main)
set(dkml-runtime-apps_BRANCH main)
set(dkml-runtime-common_BRANCH main)
set(dkml-runtime-distribution_BRANCH main)
set(dkml-workflows_BRANCH v1)

# Sanity check
foreach(PROJECT IN LISTS DKML_PROJECTS_SYNCED)
    if(NOT ${PROJECT}_BRANCH)
        message(FATAL_ERROR "Missing set(${PROJECT}_BRANCH ...) statement in ${CMAKE_CURRENT_LIST_FILE}")
    endif()
endforeach()

# ----------------
# Make variables for all synced projects _and_ unsynced projects to have a
# opam-install-friendly relative directory to PROJECT_SOURCE_DIR, and a
# short git reference.
# Also make files containing the shortrefs so they can be used in DEPENDS.

set(generatedCacheVariables)
set(clearedCacheVariables)
foreach(PROJECT IN LISTS DKML_PROJECTS_SYNCED DKML_PROJECTS_UNSYNCED)
    FetchContent_GetProperties(${PROJECT})
    if(NOT ${PROJECT}_SOURCE_DIR)
        message(FATAL_ERROR "Missing ${PROJECT}_SOURCE_DIR variable, so missing FetchContent_MakeAvailable(${PROJECT}) in dependencies/CMakeLists.txt")
    endif()
    cmake_path(
        RELATIVE_PATH ${PROJECT}_SOURCE_DIR
        BASE_DIRECTORY ${PROJECT_SOURCE_DIR}
        OUTPUT_VARIABLE ${PROJECT}_REL_SOURCE_DIR)
    # opam 2.1 (and later?) needs opam install ./x/y/z.opam for some odd reason
    set(${PROJECT}_REL_SOURCE_DIR "./${${PROJECT}_REL_SOURCE_DIR}")

    execute_process(
        WORKING_DIRECTORY ${${PROJECT}_SOURCE_DIR}
        COMMAND ${GIT_EXECUTABLE} rev-parse --quiet --verify HEAD
        OUTPUT_STRIP_TRAILING_WHITESPACE
        OUTPUT_VARIABLE gitref
        COMMAND_ERROR_IS_FATAL ANY
    )
    string(SUBSTRING "${gitref}" 0 6 ${PROJECT}_SHORTREF)

    # Add to CMakePresetsGenerated
    list(APPEND generatedCacheVariables "        \"${PROJECT}_GIT_TAG\": {
          \"value\": \"${gitref}\"
        }")
    list(APPEND clearedCacheVariables "        \"${PROJECT}_GIT_TAG\": \"\"")
    # Only write if content has changed
    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/depends/${PROJECT}.shortref" CONTENT "${gitref}")
endforeach()

if(NOT DKML_GOLDEN_SOURCE_CODE)
    list(JOIN generatedCacheVariables ",\n" DKML_GENERATED_CACHE_VARIABLES)
    list(JOIN clearedCacheVariables ",\n" DKML_CLEARED_CACHE_VARIABLES)
    configure_file(CMakePresetsGenerated.in.json "${PROJECT_SOURCE_DIR}/CMakePresetsGenerated.json" @ONLY)
    configure_file(CMakePresetsCleared.in.json "${PROJECT_SOURCE_DIR}/CMakePresetsCleared.json" @ONLY)
endif()

# ----------------
#
function(stage_self_VersionReplace)
    set(noValues)
    set(singleValues BUMP_LEVEL DESTDIR NEW_VERSION_CMAKEVER NEW_PUBLICVERSION_CMAKEVER REL_FILENAME)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    file(READ ${PROJECT_SOURCE_DIR}/${ARG_REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REPLACE
        "DKML_VERSION_CMAKEVER \"${DKML_VERSION_CMAKEVER}\""
        "DKML_VERSION_CMAKEVER \"${ARG_NEW_VERSION_CMAKEVER}\""
        contents_NEW "${contents_NEW}")

    if(NOT(ARG_BUMP_LEVEL STREQUAL "PRERELEASE"))
        # PATCH, MINOR or MAJOR
        set(contents_LAST ${contents_NEW})
        string(REPLACE
            "DKML_PUBLICVERSION_CMAKEVER \"${DKML_PUBLICVERSION_CMAKEVER}\""
            "DKML_PUBLICVERSION_CMAKEVER \"${ARG_NEW_PUBLICVERSION_CMAKEVER}\""
            contents_NEW "${contents_NEW}")
    endif()

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${ARG_DESTDIR}/${ARG_REL_FILENAME} "${contents_NEW}")
endfunction()

function(stage_self_DkMLReplace)
    set(noValues)
    set(singleValues DESTDIR NEW_VERSION_SEMVER REL_FILENAME)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    file(READ ${PROJECT_SOURCE_DIR}/${ARG_REL_FILENAME} contents)
    string(REGEX REPLACE "DkML [0-9.-]+" "DkML ${ARG_NEW_VERSION_SEMVER}" contents_NEW "${contents}")

    if(contents STREQUAL "${contents_NEW}")
        return()
    endif()

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${ARG_DESTDIR}/${ARG_REL_FILENAME} "${contents_NEW}")
endfunction()

function(stage_self_Changes)
    set(noValues)
    set(singleValues DESTDIR NEW_VERSION_SEMVER)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    # Find vX.Y.Z.md. Set DEPENDS
    if(EXISTS ${PROJECT_SOURCE_DIR}/contributors/changes/v${ARG_NEW_VERSION_SEMVER}.md)
        file(READ ${PROJECT_SOURCE_DIR}/contributors/changes/v${ARG_NEW_VERSION_SEMVER}.md versionChanges)
    else()
        set(versionChanges "## ${ARG_NEW_VERSION_SEMVER} (@@YYYYMMDD@@)")
    endif()

    file(READ ${PROJECT_SOURCE_DIR}/CHANGES.md priorChanges)

    # First line in CHANGES.md should be a top-level heading "# CHANGES" to
    # be valid Markdown. So strip it so we can add it back.
    string(REGEX REPLACE "^# CHANGES[^\n]*\n" "" priorChanges "${priorChanges}")

    string(TIMESTAMP now_YYYYMMDD "%Y-%m-%d")
    string(REPLACE "@@YYYYMMDD@@" ${now_YYYYMMDD} versionChanges "${versionChanges}")

    string(STRIP "${versionChanges}" versionChanges)
    string(STRIP "${priorChanges}" priorChanges)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${ARG_DESTDIR}/CHANGES.md "# CHANGES\n\n${versionChanges}\n\n${priorChanges}")
endfunction()

# ----------------
#

function(get_self_modifications)
    # Often bugs are fixed in .cmake files during a bump. Include any of those
    # fixes in -final.
    file(GLOB SELF_MODIFICATIONS LIST_DIRECTORIES false
        RELATIVE ${PROJECT_SOURCE_DIR}
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/CMakeLists.txt
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkML*.cmake)

    # Often the vM.N.O.md changelog is manually modified during the bump as bugs are found.
    # Include them in -final.
    if(NOT EXISTS ${PROJECT_SOURCE_DIR}/contributors/changes/v${DKML_VERSION_SEMVER}.md)
        message(FATAL_ERROR "The changelog file is required: ${PROJECT_SOURCE_DIR}/contributors/changes/v${DKML_VERSION_SEMVER}.md")        
    endif()
    list(APPEND SELF_MODIFICATIONS contributors/changes/v${DKML_VERSION_SEMVER}.md)

    # version.cmake
    list(APPEND SELF_MODIFICATIONS ${PROJECT_SOURCE_DIR}/version.cmake)

    # README.md, CHANGES.md
    if(NOT DKML_VERSION_PRERELEASE)
        list(APPEND SELF_MODIFICATIONS ${PROJECT_SOURCE_DIR}/README.md)
        list(APPEND SELF_MODIFICATIONS ${PROJECT_SOURCE_DIR}/CHANGES.md)
    endif()

    list(REMOVE_DUPLICATES SELF_MODIFICATIONS)
    set(SELF_MODIFICATIONS "${SELF_MODIFICATIONS}" PARENT_SCOPE)
endfunction()

function(generate_self_modifications)
    set(noValues)
    set(singleValues BUMP_LEVEL)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    if(ARG_BUMP_LEVEL STREQUAL "PRERELEASE")
        # PRERELEASE bump
        stage_self_VersionReplace(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            NEW_VERSION_CMAKEVER ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            NEW_PUBLICVERSION_CMAKEVER ${DKML_PUBLICVERSION_CMAKEVER} # No change to the public version
            DESTDIR new/${ARG_BUMP_LEVEL}
            REL_FILENAME version.cmake)
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}/finish)
    else()
        # PATCH, MINOR or MAJOR bump
        stage_self_VersionReplace(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            NEW_VERSION_CMAKEVER ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            NEW_PUBLICVERSION_CMAKEVER ${DKML_PUBLICVERSION_CMAKEVER} # No change to the public version at first
            DESTDIR new/${ARG_BUMP_LEVEL}
            REL_FILENAME version.cmake)
        stage_self_VersionReplace(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            NEW_VERSION_CMAKEVER ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            NEW_PUBLICVERSION_CMAKEVER ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            DESTDIR ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}/finish
            REL_FILENAME version.cmake)
        stage_self_DkMLReplace(
            NEW_VERSION_SEMVER ${DKML_PUBLICVERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            DESTDIR ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}/finish
            REL_FILENAME README.md)
        stage_self_Changes(
            NEW_VERSION_SEMVER ${DKML_PUBLICVERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            DESTDIR ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}/finish)
    endif()
endfunction()

function(add_versionbump_target)
    set(noValues)
    set(singleValues BUMP_LEVEL DKML_VERSION_CMAKEVER_NEW)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${ARG_DKML_VERSION_CMAKEVER_NEW}/semver)

    add_custom_target(Package-VersionBump-${ARG_BUMP_LEVEL}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/new/${ARG_BUMP_LEVEL} .
        VERBATIM)
endfunction()

function(generate_version_files)
    set(noValues)
    set(singleValues DKML_VERSION_CMAKEVER_NEW)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    file(CONFIGURE OUTPUT ${ARG_DKML_VERSION_CMAKEVER_NEW}/semver CONTENT "@ARG_DKML_VERSION_CMAKEVER_NEW@" @ONLY NEWLINE_STYLE UNIX)
    file(CONFIGURE OUTPUT ${ARG_DKML_VERSION_CMAKEVER_NEW}/dkmlroot CONTENT "dkml_root_version=@ARG_DKML_VERSION_CMAKEVER_NEW@" @ONLY NEWLINE_STYLE UNIX)
endfunction()

function(add_all_bump_targets)
    # Make DKML_VERSION_CMAKEVER_NEW_* local to this function.
    # And bump as if we started from the stable PUBLICVERSION rather
    # than the changing VERSION.
    make_bumped_versions(
        VERSIONTYPE VERSION
        MAJOR ${DKML_PUBLICVERSION_MAJOR}
        MINOR ${DKML_PUBLICVERSION_MINOR}
        PATCH ${DKML_PUBLICVERSION_PATCH}
        PRERELEASE "${DKML_PUBLICVERSION_PRERELEASE}")

    foreach(BUMP_LEVEL IN LISTS BUMP_LEVELS)
        set(cmakever_new ${DKML_VERSION_CMAKEVER_NEW_${BUMP_LEVEL}})
        generate_version_files(DKML_VERSION_CMAKEVER_NEW ${cmakever_new})

        generate_self_modifications(BUMP_LEVEL ${BUMP_LEVEL})
        add_versionbump_target(BUMP_LEVEL ${BUMP_LEVEL} DKML_VERSION_CMAKEVER_NEW ${cmakever_new})
    endforeach()
endfunction()
if(DKML_GOLDEN_SOURCE_CODE)
    generate_version_files(DKML_VERSION_CMAKEVER_NEW ${DKML_VERSION_CMAKEVER})
else()
    add_all_bump_targets()
    get_self_modifications()
endif()

# ----------------
#

function(add_VersionBump_target_for_synced_projects)
    set(noValues)
    set(singleValues TARGET FILTER)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)

    # For PRERELEASE we want fuzzy matching on any prior PRERELEASE because
    # we expect partial completions during PRERELEASE.
    #
    # For example, a PRERELEASE bump could be successful for half of
    # the packages, but then terminated due to a failure (perhaps this script
    # has a bug!). The failure would get fixed. Then a new PRERELEASE bump
    # occurs. Once it finishes end-to-end without failures ... only then
    # do you do a PATCH (or MINOR or MAJOR) bump.
    if(DKML_VERSION_PRERELEASE)
        set(regex_DKML_VERSION_SEMVER "${DKML_VERSION_MAJMIN}[.][0-9]-[0-9]+")
        set(regex_DKML_VERSION_OPAMVER "${DKML_VERSION_MAJMIN}[.][0-9][~]prerel[0-9]+")
    else()
        set(regex_DKML_VERSION_SEMVER "${DKML_PUBLICVERSION_SEMVER}")
        set(regex_DKML_VERSION_OPAMVER "${DKML_PUBLICVERSION_OPAMVER}")
    endif()

    string(REPLACE "." "[.]" regex_DKML_VERSION_SEMVER "${regex_DKML_VERSION_SEMVER}")
    string(REPLACE "." "[.]" regex_DKML_VERSION_OPAMVER "${regex_DKML_VERSION_OPAMVER}")

    set(participant ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpVersionParticipant.cmake)
    set(target_SOURCES ${participant})
    set(target_COMMANDS)
    set(bumpedProjects)

    foreach(proj IN LISTS DKML_PROJECTS_SYNCED)
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

        if(ARG_FILTER STREQUAL "PRE_DUNE")
            if(NOT(proj IN_LIST DKML_PROJECTS_PREDUNE))
                continue()
            endif()

            string(APPEND outputDir /PRE)
        elseif(ARG_FILTER STREQUAL "POST_DUNE")
            if(NOT(proj IN_LIST DKML_PROJECTS_POSTDUNE))
                continue()
            endif()

            string(APPEND outputDir /POST)
        elseif(ARG_FILTER STREQUAL "FINAL")
            if(NOT(proj IN_LIST DKML_PROJECTS_FINAL))
                continue()
            endif()

            string(APPEND outputDir /FINAL)
        endif()

        # Queue up COMMANDs rather than add_custom_command() because
        # we want bump-version.cmake to always be run.
        list(APPEND target_COMMANDS
            COMMAND
            ${CMAKE_COMMAND} -E chdir ${srcDir}
            ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D "DKML_BUMP_VERSION_PARTICIPANT_MODULE=${participant}"
            -D DKML_RELEASE_OCAML_VERSION=${DKML_RELEASE_OCAML_VERSION}
            -D regex_DKML_VERSION_OPAMVER=${regex_DKML_VERSION_OPAMVER}
            -D regex_DKML_VERSION_SEMVER=${regex_DKML_VERSION_SEMVER}
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -P bump-version.cmake
        )
        list(APPEND target_SOURCES ${srcDir}/bump-version.cmake)
        list(APPEND bumpedProjects ${proj})
    endforeach()

    list(JOIN bumpedProjects ", " bumpedProjects_SPACES)
    add_custom_target(${ARG_TARGET}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Running bump-version.cmake in ${bumpedProjects_SPACES}"
        DEPENDS ${ARG_DEPENDS}
        ${target_COMMANDS}
        SOURCES ${target_SOURCES}
        VERBATIM USES_TERMINAL)
endfunction()

function(add_PackageUpgrade_target)
    set(noValues)
    set(singleValues OPAMROOT OPAMEXE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)

    if(CMAKE_HOST_WIN32)
        set(bashExecutable ${MSYS2_BASH_RUN})
        string(REPLACE ";" "$<SEMICOLON>" bashExecutable "${bashExecutable}")
    else()
        set(bashExecutable bash)
    endif()

    cmake_path(NATIVE_PATH ARG_OPAMROOT NORMALIZE OPAMROOT_NATIVE)
    set(participant ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpPackagesParticipant.cmake)
    set(target_SOURCES ${participant})
    set(target_COMMANDS)
    set(bumpedProjects)

    foreach(proj IN LISTS DKML_PROJECTS_SYNCED)
        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/PackageUpgrade/${proj})

        # Set <proj>_SOURCE_DIR
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})

        if(NOT srcDir)
            message(FATAL_ERROR "No FetchContent_MakeAvailable(${proj}) has been performed in dependencies/")
        endif()

        if(NOT EXISTS ${srcDir}/bump-packages.cmake)
            continue()
        endif()

        # We queue up the COMMANDs rather than use add_custom_command() because
        # we _always_ want these commands to run.
        #
        # 1. [dkml-installer-ocaml]'s bump-packages.cmake will regenerate the
        # list of components. So any source code can register itself in the
        # dkml-install-api registry.
        # 2. [dkml-runtime-distribution] and [dkml-workflows]'s
        # bump-packages.cmake change their pins and package lists based on the
        # state of the switch (which is a synthesis of all the steps prior)
        #
        # In general, PackageUpgrade _cannot_ model when bump-packages.cmake
        # should be re-run (ie. add_custom_command(DEPENDS)) so we always
        # run the bump-packages.cmake.
        list(APPEND target_SOURCES
            ${srcDir}/bump-packages.cmake)
        list(APPEND target_COMMANDS
            COMMAND
            ${CMAKE_COMMAND} -E chdir
            ${srcDir}
            ${CMAKE_COMMAND} -E env
            OPAMROOT=${OPAMROOT_NATIVE}
            OPAMSWITCH=${DKML_VERSION_CMAKEVER}
            ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D "DKML_BUMP_PACKAGES_PARTICIPANT_MODULE=${participant}"
            -D DKML_RELEASE_DUNE_VERSION=${DKML_RELEASE_DUNE_VERSION}
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -D "OPAM_EXECUTABLE=${ARG_OPAMEXE}"
            -D "BASH_EXECUTABLE=${bashExecutable}"
            -D WITH_COMPILER_SH=${WITH_COMPILER_SH}
            -D TEMP_DIR=${outputDir}/tmp
            -P bump-packages.cmake
        )
        list(APPEND bumpedProjects ${proj})
    endforeach()

    list(JOIN bumpedProjects ", " bumpedProjects_SPACES)
    add_custom_target(Package-Stage06-PackageUpgrade
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Running bump-packages.cmake in ${bumpedProjects_SPACES}"
        DEPENDS ${ARG_DEPENDS}
        ${target_COMMANDS}
        SOURCES ${target_SOURCES}
        VERBATIM USES_TERMINAL)
endfunction()

function(add_RepositoryUpdate_target)
    set(noValues)
    set(singleValues)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)

    set(participant ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpRepositoryParticipant.cmake)
    set(target_SOURCES ${participant})
    set(target_COMMANDS)
    set(bumpedProjects)

    foreach(proj IN LISTS DKML_PROJECTS_SYNCED)
        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/RepositoryUpdate/${proj})

        # Set <proj>_SOURCE_DIR
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})

        if(NOT srcDir)
            message(FATAL_ERROR "No FetchContent_MakeAvailable(${proj}) has been performed in dependencies/")
        endif()

        if(NOT EXISTS ${srcDir}/bump-repository.cmake)
            continue()
        endif()

        # We queue up the COMMANDs rather than use add_custom_command() because
        # we _always_ want these commands to run. We do this because
        # PackageUpgrade (a prior step) has to always run as well.
        list(APPEND target_SOURCES
            ${srcDir}/bump-repository.cmake)
        list(APPEND target_COMMANDS
            COMMAND
            ${CMAKE_COMMAND} -E chdir
            ${srcDir}
            ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D "DKML_BUMP_REPOSITORY_PARTICIPANT_MODULE=${participant}"
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER}
            -D DKML_RELEASE_OCAML_VERSION=${DKML_RELEASE_OCAML_VERSION}
            -D "BUMP_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            -D "DKML_SOURCE_ARCHIVE_DIR=${ARCHIVEDIR}"
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -D "OPAM_EXECUTABLE=${ARG_OPAMEXE}"
            -P bump-repository.cmake
        )
        list(APPEND bumpedProjects ${proj})
    endforeach()

    list(JOIN bumpedProjects ", " bumpedProjects_SPACES)
    add_custom_target(Package-Stage08-RepositoryUpdate
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Running bump-repository.cmake in ${bumpedProjects_SPACES}"
        DEPENDS ${ARG_DEPENDS}
        ${target_COMMANDS}
        COMMAND ${CMAKE_COMMAND} -E echo "Run [promote.sh] in diskuv-opam-repository to promote the update to the central opam repository"
        SOURCES ${target_SOURCES}
        VERBATIM USES_TERMINAL)
    add_dependencies(Package-Stage08-RepositoryUpdate Package-Archive)
endfunction()

function(audit_Git)
    set(noValues)
    set(singleValues SOURCE_DIR)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    execute_process(
        WORKING_DIRECTORY ${ARG_SOURCE_DIR}
        COMMAND ${GIT_EXECUTABLE} rev-parse --quiet --verify HEAD
        OUTPUT_STRIP_TRAILING_WHITESPACE
        OUTPUT_VARIABLE currentCommit)
    message(STATUS "${ARG_SOURCE_DIR}: git commit ${currentCommit}")
endfunction()

function(update_Git_to_branch)
    set(noValues)
    set(singleValues SOURCE_DIR BRANCH)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    execute_process(
        WORKING_DIRECTORY ${ARG_SOURCE_DIR}
        COMMAND ${GIT_EXECUTABLE} branch --show-current
        OUTPUT_STRIP_TRAILING_WHITESPACE
        OUTPUT_VARIABLE currentBranch)

    if(currentBranch)
        # Safety check
        if(NOT(currentBranch STREQUAL "${ARG_BRANCH}"))
            message(FATAL_ERROR "The expected branch was ${ARG_BRANCH} in ${ARG_SOURCE_DIR}, but is actually ${currentBranch}. Change ${CMAKE_CURRENT_FUNCTION_LIST_FILE} if the expected branch is wrong")
        endif()
    else()
        # FetchContent_Declare(GIT_TAG) in CMake 3.23.1 does not change HEAD (aka. no `git switch <branch>`).
        # So we'll do that if it looks like a detached HEAD.
        execute_process(
            COMMAND ${GIT_EXECUTABLE} -C "${ARG_SOURCE_DIR}" switch "${ARG_BRANCH}"
            COMMAND_ERROR_IS_FATAL ANY
        )
        execute_process(
            COMMAND ${GIT_EXECUTABLE} -C "${ARG_SOURCE_DIR}" pull --ff-only
            ERROR_VARIABLE execute_ERROR
        )
        if(execute_ERROR)
            message(FATAL_ERROR "git pull --ff-only failed in branch ${ARG_BRANCH} of ${ARG_SOURCE_DIR}")
        endif()
    endif()
endfunction()

function(add_GitPush_command)
    set(noValues)
    set(singleValues SOURCE_DIR CONTEXT OUTPUT_FILE BRANCH INTENDED_TARGET TAG_SUFFIX)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)
    set(refspec ${DKML_VERSION_SEMVER})

    if(ARG_TAG_SUFFIX)
        string(APPEND refspec "${ARG_TAG_SUFFIX}")
    endif()

    if(DKML_VERSION_PRERELEASE)
        # Prereleases can always be overwritten, so add a leading +
        # (similar to --force) to force overwrite the git tag if present.
        # We don't use --force since that would apply to the [<currentBranch>]
        # branch as well (which we want to fail if it is not a fast-forward
        # commit).
        string(PREPEND refspec "+")
    endif()

    # We want the git tagging to be done always. We settle for doing
    # it in each re-configure by deleting the output file during re-configure.
    file(REMOVE ${ARG_OUTPUT_FILE})

    add_custom_command(
        OUTPUT ${ARG_OUTPUT_FILE}
        WORKING_DIRECTORY ${ARG_SOURCE_DIR}
        DEPENDS ${ARG_DEPENDS}

        # git tag
        COMMAND
        ${CMAKE_COMMAND}
        -D CMAKE_MESSAGE_CONTEXT=${ARG_CONTEXT}
        -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
        -D "DKML_VERSION_PRERELEASE_NEW=${DKML_VERSION_PRERELEASE}"
        -D "DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER}${ARG_TAG_SUFFIX}"
        -D "DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER}"
        -P ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/idempotent-tag.cmake
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${ARG_OUTPUT_FILE}

        # git push
        COMMAND ${GIT_EXECUTABLE} push --atomic origin "${ARG_BRANCH}" ${refspec}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${ARG_OUTPUT_FILE}

        VERBATIM
        USES_TERMINAL
    )
endfunction()

function(add_GitPush_commands_for_synced_projects)
    set(noValues)
    set(singleValues OUTPUT_LIST_VARIABLE INTENDED_TARGET)
    set(multiValues DEPENDS INCLUDE EXCLUDE)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)
    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})

    foreach(proj IN LISTS DKML_PROJECTS_SYNCED)
        if(ARG_INCLUDE)
            if(NOT proj IN_LIST ARG_INCLUDE)
                continue()
            endif()
        endif()
        if(ARG_EXCLUDE)
            if(proj IN_LIST ARG_EXCLUDE)
                continue()
            endif()
        endif()

        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/GitPush/${proj})

        # Set <proj>_SOURCE_DIR
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})
        set(branch ${${proj}_BRANCH})

        if(NOT srcDir)
            message(FATAL_ERROR "No FetchContent_MakeAvailable(${proj}) has been performed in dependencies/")
        endif()

        if(NOT branch)
            message(FATAL_ERROR "No set(${proj}_BRANCH) was set in ${CMAKE_CURRENT_FUNCTION_LIST_FILE}")
        endif()

        add_GitPush_command(
            SOURCE_DIR ${srcDir}
            CONTEXT ${proj}
            OUTPUT_FILE ${outputDir}/pushed
            BRANCH ${branch}
            INTENDED_TARGET ${ARG_INTENDED_TARGET}
            DEPENDS ${ARG_DEPENDS})
        list(APPEND retval ${outputDir}/pushed)
    endforeach()

    # Add to list
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(get_flavor_packages)
    set(noValues)
    set(singleValues OUTPUT_PKGS_VARIABLE OUTPUT_PKGVERS_VARIABLE OUTPUT_DEPENDS)
    set(multiValues FLAVORS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(pkgvers)
    set(depends)

    macro(grok PKGS_TXT)
        # Read non-comment, non-blank lines that have a dot (.) in them
        file(STRINGS ${PKGS_TXT} strings REGEX "^[^#] *[a-z].*[.]")
        list(APPEND pkgvers ${strings})
        list(APPEND depends ${PKGS_TXT})
    endmacro()

    FetchContent_GetProperties(dkml-runtime-distribution)
    foreach(FLAVOR IN LISTS ARG_FLAVORS)
        string(TOLOWER "${FLAVOR}" lowerFlavor)
        grok(${dkml-runtime-distribution_SOURCE_DIR}/src/none/${lowerFlavor}-anyver-pkgs.txt)
        grok(${dkml-runtime-distribution_SOURCE_DIR}/src/none/${lowerFlavor}-${DKML_RELEASE_OCAML_VERSION}-pkgs.txt)
    endforeach()

    list(TRANSFORM pkgvers REPLACE "[.].*" "" OUTPUT_VARIABLE pkgs)

    set(${ARG_OUTPUT_PKGS_VARIABLE} ${pkgs} PARENT_SCOPE)
    set(${ARG_OUTPUT_PKGVERS_VARIABLE} ${pkgvers} PARENT_SCOPE)
    set(${ARG_OUTPUT_DEPENDS} ${depends} PARENT_SCOPE)
endfunction()

# ----------------------------------------------------------------------------------

if(DKML_GOLDEN_SOURCE_CODE)
    foreach(proj IN LISTS DKML_PROJECTS_SYNCED)
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})
        audit_Git(SOURCE_DIR ${srcDir})
    endforeach()
else()
    foreach(proj IN LISTS DKML_PROJECTS_SYNCED)
        FetchContent_GetProperties(${proj})
        set(srcDir ${${proj}_SOURCE_DIR})
        set(branch ${${proj}_BRANCH})
        update_Git_to_branch(SOURCE_DIR ${srcDir} BRANCH ${branch})
    endforeach()
endif()

get_flavor_packages(
    FLAVORS Dune
    OUTPUT_PKGS_VARIABLE DUNE_FLAVOR_PKGS
    OUTPUT_PKGVERS_VARIABLE DUNE_FLAVOR_PKGVERS
    OUTPUT_DEPENDS DEPENDS_FLAVORS_Dune)
get_flavor_packages(
    FLAVORS CI Full
    OUTPUT_PKGS_VARIABLE FULL_NOT_DUNE_FLAVOR_PKGS
    OUTPUT_PKGVERS_VARIABLE FULL_NOT_DUNE_FLAVOR_PKGVERS
    OUTPUT_DEPENDS DEPENDS_FLAVORS_CI_Full)

# dune.3.6.2+shim -> 3.6.2
set(DKML_RELEASE_DUNE_VERSION ${DUNE_FLAVOR_PKGVERS})
list(FILTER DKML_RELEASE_DUNE_VERSION INCLUDE REGEX "^dune[.]")
string(REPLACE "dune." "" DKML_RELEASE_DUNE_VERSION "${DKML_RELEASE_DUNE_VERSION}")
string(REGEX REPLACE "[+].*" "" DKML_RELEASE_DUNE_VERSION "${DKML_RELEASE_DUNE_VERSION}")

# DUNE_FLAVOR_PKGVERS with [dune.X+shim] replaced by [dune.X]
set(duneFlavorPkgVers ${DUNE_FLAVOR_PKGVERS})
list(FILTER duneFlavorPkgVers EXCLUDE REGEX "^dune[.]")
list(APPEND duneFlavorPkgVers dune.${DKML_RELEASE_DUNE_VERSION})
list(JOIN duneFlavorPkgVers " " DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS)
file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/depends/DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS
    CONTENT "${DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS}")

# FULL_NOT_DUNE_FLAVOR_PKGVERS without [conf-withdkml]
# * [conf-withdkml] pulls in an external [with-dkml.exe] which is not
# repeatable (ie. not hermetic).
set(fullNoDuneNoWithdkmlPkgVers ${FULL_NOT_DUNE_FLAVOR_PKGVERS})
list(FILTER fullNoDuneNoWithdkmlPkgVers EXCLUDE REGEX "^conf-withdkml[.]")
list(JOIN fullNoDuneNoWithdkmlPkgVers " " FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS)
file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/depends/FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS
    CONTENT "${FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS}")

# -----------------------------------
# GenerateLaunchers
# -----------------------------------
set(WITH_COMPILER_SH ${CMAKE_CURRENT_BINARY_DIR}/with-compiler.sh) # Used by generate-compiler-launcher.sh and upsert-*.sh

function(add_GenerateLaunchers_target)
    FetchContent_GetProperties(dkml-workflows)

    # SECONDARY_SWITCH: Same as dkml-component-desktop's .gitlab-ci.yml [variables:]
    #
    # SKIP_OPAM_MODIFICATIONS:
    # We go further than current (2023-06) dkml-component-desktop by
    # setup-dkml not installing _any_ switches. We do that entirely with
    # CMake so we can set the FetchContent based local pins.

    if(NOT SKIP_CMDRUN)
        if(CMAKE_HOST_WIN32)
            set(runSetupScript "${POWERSHELL_EXECUTABLE}" "${dkml-workflows_SOURCE_DIR}/test/pc/setup-dkml-${DKML_TARGET_ABI}.ps1"
                -PC_PROJECT_DIR "${CMAKE_CURRENT_BINARY_DIR}"
                -SECONDARY_SWITCH true
                -SKIP_OPAM_MODIFICATIONS true)
        else()
            set(runSetupScript sh "${dkml-workflows_SOURCE_DIR}/test/pc/setup-dkml-${DKML_TARGET_ABI}.sh"
                "--PC_PROJECT_DIR=${CMAKE_CURRENT_BINARY_DIR}"
                --SECONDARY_SWITCH=true
                --SKIP_OPAM_MODIFICATIONS=true)
            if(DKML_HOST_LINUX_DOCKER)
                list(APPEND runSetupScript --in_docker=true)
            else()
                list(APPEND runSetupScript --in_docker=false)
            endif()
        endif()
        add_custom_command(
            OUTPUT ${anyrun_OUTPUTS}
            COMMENT "Creating [cmdrun] and [opamrun] scripts"
            COMMAND ${runSetupScript}
            VERBATIM
            USES_TERMINAL
        )
    endif()

    FetchContent_GetProperties(dkml-runtime-common)
    FetchContent_GetProperties(dkml-compiler)
    configure_file(generate-compiler-launcher.in.sh ${CMAKE_CURRENT_BINARY_DIR}/generate-compiler-launcher.sh
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        @ONLY NEWLINE_STYLE UNIX)

    if(CMAKE_HOST_WIN32)
        set(GEN_COMPILER_COMMAND ${MSYS2_BASH_RUN} ${CMAKE_CURRENT_BINARY_DIR}/generate-compiler-launcher.sh)
        set(GEN_COMPILER_DEPENDS ${MSYS2_BASH})
    else()
        set(GEN_COMPILER_COMMAND ${CMAKE_CURRENT_BINARY_DIR}/generate-compiler-launcher.sh)
        set(GEN_COMPILER_DEPENDS)
    endif()

    add_custom_command(
        OUTPUT ${WITH_COMPILER_SH}
        COMMENT "Creating [with-compiler.sh] script"
        DEPENDS ${GEN_COMPILER_DEPENDS} ${CMAKE_CURRENT_BINARY_DIR}/generate-compiler-launcher.sh
        COMMAND ${GEN_COMPILER_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
    add_custom_target(Package-GenerateLaunchers
        DEPENDS ${WITH_COMPILER_SH}
    )
endfunction()

configure_file(anyrun.in.sh ${CMAKE_CURRENT_BINARY_DIR}/anyrun.sh
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    @ONLY NEWLINE_STYLE UNIX)

function(anyrun SCRIPT OUTVAR)
    if(SKIP_CMDRUN)
        if(CMAKE_HOST_WIN32)
            set(${OUTVAR} ${MSYS2_BASH_RUN} ${SCRIPT} PARENT_SCOPE)
        else()
            set(${OUTVAR} sh -x ${SCRIPT} PARENT_SCOPE)
        endif()
    else()
        if(CMAKE_HOST_WIN32)
            set(${OUTVAR} ${MSYS2_BASH_RUN} "${CMAKE_CURRENT_BINARY_DIR}/anyrun.sh" ${SCRIPT} PARENT_SCOPE)
        else()
            set(${OUTVAR} "${CMAKE_CURRENT_BINARY_DIR}/anyrun.sh" ${SCRIPT} PARENT_SCOPE)
        endif()
    endif()
endfunction()

# -----------------------------------
function(get_switch_path)
    set(noValues)
    set(singleValues OUTPUT_SWITCH_PATH)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(${ARG_OUTPUT_SWITCH_PATH} ${anyrun_OPAMROOT}/${DKML_VERSION_CMAKEVER} PARENT_SCOPE)
endfunction()

function(prepare_upsert_variables)
    set(noValues)
    set(singleValues ID OUTPUT_SWITCH_NAME OUTPUT_WORKING_DIRECTORY OUTPUT_SWITCH_PATH OUTPUT_UPSERT_UTILS)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    get_switch_path(OUTPUT_SWITCH_PATH switchPath)

    set(workdir ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/${ARG_ID})
    FetchContent_GetProperties(dkml-runtime-common)
    set(UPSERT_UTILS ${workdir}/upsert-utils.sh)

    configure_file(upsert-utils.in.sh ${workdir}/upsert-utils.sh
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        @ONLY NEWLINE_STYLE UNIX)

    if(ARG_OUTPUT_SWITCH_NAME)
        set(${ARG_OUTPUT_SWITCH_NAME} ${DKML_VERSION_CMAKEVER} PARENT_SCOPE)
    endif()

    set(${ARG_OUTPUT_WORKING_DIRECTORY} ${workdir} PARENT_SCOPE)
    set(${ARG_OUTPUT_SWITCH_PATH} ${switchPath} PARENT_SCOPE)
    set(${ARG_OUTPUT_UPSERT_UTILS} ${UPSERT_UTILS} PARENT_SCOPE)
endfunction()

# -----------------------------------
# OpamSwitch: DuneFlavor and FullFlavor
# -----------------------------------

# The DuneFlavor target creates the "dkml" switch.
#
# The target is responsible for creating the opam root,
# and the opam switch with FetchContent-synced versions of dkml-base-compiler
# (with its dependencies), and the dkml-runtime-distribution-synced versions of
# the Dune flavor distribution.
#
# Among other things, the Dune distribution will have a working [dune] so
# that dkml-component-desktop (in later targets) can do [dune build *.opam] to
# update its own .opam files.
#
# This logic is similar as is performed by dkml-component-desktop, although
# only one switch is needed here. (Perhaps it is time to merge the logic?)
# See its README.md for how it works.
#
# The FullFlavor target can then add the dkml-runtime-distribution-synced
# versions of the Full flavor distribution.
function(add_Flavor_targets)
    set(noValues)
    set(singleValues OUTPUT_LIST_VARIABLE_DUNE OUTPUT_LIST_VARIABLE_FULL)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)

    prepare_upsert_variables(
        ID sw
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SWITCH_NAME SWITCH_NAME # Used by upsert-dkml-switch
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH_PATH switchPath
    )

    # For [upstream-dkml-pkgs-flavor-full-not-dune.in.sh] we want all the
    # _latest_ package versions from diskuv-opam-repository, except those from:
    # 1. dkml-runtime-apps (we have special logic to install dkml-runtime-apps
    # in [upsert-dkml-pkgs-flavor-full-not-dune.in.sh])
    # 2. dune. done in [upstream-dkml-pkgs-flavor-dune.in.sh]
    # 3. dkml-runtime-common and dkml-runtime-distribution and
    # dkml-compiler_PACKAGES [upstream-dkml-pkgs-compiler.in.sh]
    # 4. ocaml-option-32bit (can't install this but we can ignore it because
    # ocaml-option-32bit.1 is in central opam repository, and ocaml-option-32bit.2
    # is just a new version in diskuv-opam-repository. WOULD BE NICE TO UPSTREAM
    # IT!)
    # 5. dkml-option-debuginfo and dkml-option-minsize. Only makes sense in
    # diskuv-opam-repository, and definitely not pinned.
    # 6. conf-withdkml. Can't assume that withdkml is installed on the machine,
    # and [dkml init] will install it anyways.
    get_dune_PACKAGES(
        DUNE_VERSION ${DKML_RELEASE_DUNE_VERSION}
        OUTPUT_VARIABLE dune_PACKAGES)
    DkMLPatches_GetPackageVersions(
        DUNE_VERSION ${DKML_RELEASE_DUNE_VERSION}
        OCAML_VERSION ${DKML_RELEASE_OCAML_VERSION}
        SYNCHRONIZED_PACKAGES ${DKML_PROJECTS_SYNCED}
        EXCLUDE_PACKAGES
        ${dkml-runtime-apps_PACKAGES}
        ${dune_PACKAGES}
        ${dkml-component_PACKAGES}
        ${dkml-installer_PACKAGES}
        ${dkml-runtime_PACKAGES}
        ${dkml-compiler_PACKAGES}
        ${dkml-workflows_PACKAGES}
        ocaml-option-32bit
        dkml-option-debuginfo
        dkml-option-minsize
        conf-withdkml

        OUTPUT_VARIABLE DKML_UNMANAGED_PATCHED_PACKAGES_PKGVERS)
    list(JOIN DKML_UNMANAGED_PATCHED_PACKAGES_PKGVERS " " DKML_UNMANAGED_PATCHED_PACKAGES_SPACED_PKGVERS)
    string(MD5 DKML_UNMANAGED_PATCHED_PACKAGES_PKGVERS_CKSUM "${DKML_UNMANAGED_PATCHED_PACKAGES_PKGVERS}")
    set(dkml-runtime-apps_REL_OPAMFILES ${dkml-runtime-apps_PACKAGES})
    list(TRANSFORM dkml-runtime-apps_REL_OPAMFILES PREPEND "${dkml-runtime-apps_REL_SOURCE_DIR}/")
    list(TRANSFORM dkml-runtime-apps_REL_OPAMFILES APPEND ".opam")

    # dkml-runtime-apps: [opam-dkml] is deprecated; we don't install it
    set(dkml-runtime-apps_REL_INSTALLABLE_OPAMFILES ${dkml-runtime-apps_REL_OPAMFILES})
    list(REMOVE_ITEM dkml-runtime-apps_REL_INSTALLABLE_OPAMFILES "${dkml-runtime-apps_REL_SOURCE_DIR}/opam-dkml.opam")
    list(JOIN dkml-runtime-apps_REL_INSTALLABLE_OPAMFILES " " dkml-runtime-apps_SPACED_REL_INSTALLABLE_OPAMFILES)

    # Evaluate the git references at CMake configure time so that
    # the various add_custom_commands() can be retriggered when
    # git references change.
    FetchContent_GetProperties(diskuv-opam-repository)
    execute_process(
        WORKING_DIRECTORY ${diskuv-opam-repository_SOURCE_DIR}
        COMMAND ${GIT_EXECUTABLE} rev-parse --quiet --verify HEAD
        OUTPUT_STRIP_TRAILING_WHITESPACE
        OUTPUT_VARIABLE DISKUV_OPAM_REPOSITORY_GITREF
        COMMAND_ERROR_IS_FATAL ANY
    )

    # Checksum to retrigger introspection
    FetchContent_GetProperties(dkml-runtime-distribution)
    file(GLOB pkgs_txt_lst LIST_DIRECTORIES false
        ${dkml-runtime-distribution_SOURCE_DIR}/src/none/*-anyver-pkgs.txt
        ${dkml-runtime-distribution_SOURCE_DIR}/src/none/*-${DKML_RELEASE_OCAML_VERSION}-pkgs.txt)
    set(DKML_DISTRIBUTION_PKGS_CKSUM)

    foreach(pkgs_txt IN LISTS pkgs_txt_lst)
        file(MD5 ${pkgs_txt} pkgs_txt_HASH)
        string(APPEND DKML_DISTRIBUTION_PKGS_CKSUM ${pkgs_txt_HASH})
    endforeach()

    string(MD5 DKML_DISTRIBUTION_PKGS_CKSUM "${DKML_DISTRIBUTION_PKGS_CKSUM}")

    # Other values used in configure_file()
    set(DKML_ROOT_DIR ${opamsw}/dkmldir) # Used by upsert-*.sh scripts
    cmake_host_system_information(RESULT DKML_HOSTNAME QUERY HOSTNAME) # Used by upsert-dkml-switch

    if(EXISTS ${PROJECT_SOURCE_DIR}/flag-dkml-debug-env-failures)
        set(FLAG_DKML_DEBUG_ENV_FAILURES 1)
    endif()

    FetchContent_GetProperties(diskuv-opam-repository) # Used by upsert-dkml-switch
    FetchContent_GetProperties(dkml-compiler) # Used by upsert-dkml-pkgs-compiler
    FetchContent_GetProperties(dkml-runtime-common) # Used by upsert-dkml-pkgs-compiler
    FetchContent_GetProperties(dkml-runtime-distribution) # Used in DKML_ROOT_DIR (create-switch.sh and init-opam-root.sh)
    FetchContent_GetProperties(dkml-runtime-apps) # Used by upsert-dkml-pkgs-flavor-full-not-dune
    FetchContent_GetProperties(dkml-component-desktop) # Use by upsert-dkml-pkgs-introspect
    set(DISKUV_OPAM_REPOSITORY_NAME_NEW diskuv-${DKML_VERSION_SEMVER}) # Used by upsert-dkml-pkgs-flavor-full-not-dune

    foreach(p IN ITEMS
        upsert-dkml-switch
        upsert-dkml-pkgs-compiler
        upsert-dkml-pkgs-flavor-dune
        upsert-dkml-pkgs-flavor-full-not-dune
        upsert-dkml-pkgs-introspect)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-dkml-switch.sh upsert_dkml_switch_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-compiler.sh upsert_dkml_pkgs_compiler_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-flavor-dune.sh upsert_dkml_pkgs_dune_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-flavor-full-not-dune.sh upsert_dkml_pkgs_full_not_dune_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-introspect.sh upsert_dkml_pkgs_introspect_COMMAND)

    # nit: This can be execute_process() or add_custom_command()
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/dkmlroot ${DKML_ROOT_DIR}/.dkmlroot

        # Needed by create-opam-switch.sh and init-opam-root.sh
        COMMAND "${CMAKE_COMMAND}" -E copy_directory ${dkml-runtime-common_SOURCE_DIR} ${DKML_ROOT_DIR}/vendor/drc

        # Needed by create-opam-switch.sh
        COMMAND "${CMAKE_COMMAND}" -E copy_directory ${dkml-runtime-distribution_SOURCE_DIR} ${DKML_ROOT_DIR}/vendor/drd
        COMMAND_ERROR_IS_FATAL ANY
    )

    set(switchCreated ${opamsw}/switch.created)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}

        # There is no file within a switch that gets updated when and only when
        # the switch is created. Some timestamps (like switch-config) are
        # updated frequently for unrelated opam commands, and some timestamps
        # (like environment) are rarely updated.
        # So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch] command.
        OUTPUT ${switchCreated}
        BYPRODUCTS
        ${switchPath}/.opam-switch/switch-config
        ${switchPath}/.opam-switch/environment
        MAIN_DEPENDENCY upsert-dkml-switch.in.sh
        DEPENDS
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${CMAKE_CURRENT_BINARY_DIR}/depends/diskuv-opam-repository.shortref # for init-opam-root.sh
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-runtime-common.shortref # needed by dkml-runtime-distribution
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-runtime-distribution.shortref # src/unix/create-opam-switch.sh, src/unix/private/init-opam-root.sh etc.
        COMMENT "Creating/updating ${DKML_VERSION_CMAKEVER} opam switch"

        # We don't make a separate CMake command for creating the opam root
        # because there is no good way (in CMake) to tell if the opam root
        # has been completed successfully. The best is checking whether the
        # repositories exist, but opam may at its own discretion use a .tar.gz
        # rather than a directory for its copy of the repository.
        COMMAND ${upsert_dkml_switch_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${switchCreated}
        VERBATIM
        USES_TERMINAL
    )
    set(compilerCreated ${opamsw}/compiler.created)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}

        # Compiler binaries often do not have timestamps updated due to
        # opam seeing no changes. So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch] command.
        OUTPUT ${compilerCreated}
        BYPRODUCTS ${switchPath}/bin/ocamlopt.opt${CMAKE_EXECUTABLE_SUFFIX}
        MAIN_DEPENDENCY upsert-dkml-pkgs-compiler.in.sh
        DEPENDS
        ${switchCreated}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-compiler.shortref # dkml-base-compiler.opam
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-runtime-common.shortref # dkml-runtime-common-native.opam
        COMMENT "Creating/updating ${DKML_VERSION_CMAKEVER} compiler"
        COMMAND ${upsert_dkml_pkgs_compiler_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${compilerCreated}
        VERBATIM
        USES_TERMINAL
    )
    set(duneFlavorOutput ${DUNE_FLAVOR_PKGS})
    list(REMOVE_ITEM duneFlavorOutput ${PACKAGES_WITHOUT_META})
    list(TRANSFORM duneFlavorOutput PREPEND "${switchPath}/lib/" OUTPUT_VARIABLE duneFlavorOutput)
    list(TRANSFORM duneFlavorOutput APPEND "/META" OUTPUT_VARIABLE duneFlavorOutput)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${duneFlavorOutput}
        MAIN_DEPENDENCY upsert-dkml-pkgs-flavor-dune.in.sh
        DEPENDS
        ${compilerCreated}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${CMAKE_CURRENT_BINARY_DIR}/depends/DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS
        COMMENT "Creating/updating ${DKML_VERSION_CMAKEVER} distribution - Dune flavor"
        COMMAND ${upsert_dkml_pkgs_dune_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
    add_custom_target(Package-Stage02-DuneFlavor
        DEPENDS ${duneFlavorOutput} ${DEPENDS_FLAVORS_Dune}
        VERBATIM
    )
    set(${OUTPUT_LIST_VARIABLE_DUNE} ${duneFlavorOutput} PARENT_SCOPE)

    # -----------------------------------
    # Sequentially the Stage3 target runs here. The Stage3 is
    # responsible for using [dune build *.opam] to update any synced
    # projects opam files.
    # -----------------------------------
    set(fullFlavorOutput ${FULL_NOT_DUNE_FLAVOR_PKGS})
    list(REMOVE_ITEM fullFlavorOutput ${PACKAGES_WITHOUT_META})
    list(TRANSFORM fullFlavorOutput PREPEND "${switchPath}/lib/" OUTPUT_VARIABLE fullFlavorOutput)
    list(TRANSFORM fullFlavorOutput APPEND "/META" OUTPUT_VARIABLE fullFlavorOutput)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${fullFlavorOutput}
        MAIN_DEPENDENCY upsert-dkml-pkgs-flavor-full-not-dune.in.sh
        DEPENDS ${duneFlavorOutput} ${WITH_COMPILER_SH} ${anyrun_OUTPUTS}
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-compiler.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-runtime-apps.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-runtime-common.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-runtime-distribution.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS
        COMMENT "Creating/updating ${DKML_VERSION_CMAKEVER} distribution - Full flavor"
        COMMAND ${upsert_dkml_pkgs_full_not_dune_COMMAND}
        VERBATIM
        USES_TERMINAL
    )

    set(introspectCreated ${opamsw}/introspect.created)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}

        # opam binaries often do not have timestamps updated due to
        # opam seeing no changes. So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch] command.
        OUTPUT ${introspectCreated}
        BYPRODUCTS
        ${switchPath}/bin/dkml-desktop-gen-globals${CMAKE_EXECUTABLE_SUFFIX}
        MAIN_DEPENDENCY upsert-dkml-pkgs-introspect.in.sh
        DEPENDS
        ${fullFlavorOutput}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-component-desktop.shortref # especially src/citime/* compiled by dkml-build-desktop.opam
        COMMENT "Creating/updating ${DKML_VERSION_CMAKEVER} introspect"
        COMMAND ${upsert_dkml_pkgs_introspect_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${introspectCreated}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-Stage04-FullFlavor
        DEPENDS ${introspectCreated} ${DEPENDS_FLAVORS_CI_Full}
        VERBATIM
    )
    add_dependencies(Package-Stage04-FullFlavor
        Package-Stage02-DuneFlavor)
    set(${OUTPUT_LIST_VARIABLE_FULL} ${introspectCreated} PARENT_SCOPE)
endfunction()

function(add_Api_target)
    set(noValues)
    set(singleValues OUTPUT_LIST_VARIABLE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)

    prepare_upsert_variables(
        ID sa
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SWITCH_NAME SWITCH_NAME
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH_PATH switchPath)

    FetchContent_GetProperties(dkml-install-api) # upsert-api
    FetchContent_GetProperties(dkml-workflows) # upsert-api

    foreach(p IN ITEMS
        upsert-api)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-api.sh upsert_api_COMMAND)

    set(apiCreated ${opamsw}/api.created)

    add_custom_command(
        WORKING_DIRECTORY ${opamsw}

        # opam binaries often do not have timestamps updated due to
        # opam seeing no changes. So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch] command.
        OUTPUT ${apiCreated}
        BYPRODUCTS
        ${switchPath}/bin/common-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        ${switchPath}/bin/package-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        MAIN_DEPENDENCY upsert-api.in.sh
        DEPENDS
        ${newSemverFile}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${ARG_DEPENDS}
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-install-api.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-workflows.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-installer-ocaml.shortref # dkml-installer-ocaml-common
        COMMENT "Creating/updating ${DKML_VERSION_CMAKEVER} api"
        COMMAND ${upsert_api_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${apiCreated}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-Stage05-Api
        DEPENDS ${apiCreated}
        VERBATIM
    )
    set(${ARG_OUTPUT_LIST_VARIABLE} ${apiCreated} PARENT_SCOPE)
endfunction()

function(add_Installer_target)
    set(noValues)
    set(singleValues OUTPUT_LIST_VARIABLE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)

    prepare_upsert_variables(
        ID si
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SWITCH_NAME SWITCH_NAME
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH_PATH switchPath)

    FetchContent_GetProperties(dkml-compiler) # upsert-installer
    FetchContent_GetProperties(dkml-component-desktop) # upsert-installer
    FetchContent_GetProperties(dkml-component-ocamlcompiler) # upsert-installer
    FetchContent_GetProperties(dkml-component-ocamlrun) # upsert-installer
    FetchContent_GetProperties(dkml-component-opam) # upsert-installer
    FetchContent_GetProperties(dkml-component-unixutils) # upsert-installer
    FetchContent_GetProperties(dkml-install-api) # upsert-installer
    FetchContent_GetProperties(dkml-installer-ocaml) # upsert-installer
    FetchContent_GetProperties(dkml-installer-ocaml-byte) # upsert-installer

    foreach(p IN ITEMS
        upsert-installer)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-installer.sh upsert_installer_COMMAND)

    set(byproducts)
    set(byproducts_byte ${byproducts}
        bundle-dkml-byte-generic-i.sh   bundle-dkml-byte-generic-u.sh)
    set(byproducts_native ${byproducts}
        bundle-dkml-native-generic-i.sh bundle-dkml-native-generic-u.sh)

    if(DKML_TARGET_ABI STREQUAL windows_x86 OR DKML_TARGET_ABI STREQUAL windows_x86_64)
        list(APPEND byproducts_byte
            unsigned-dkml-byte-${DKML_TARGET_ABI}-i-${DKML_VERSION_SEMVER}.exe
            unsigned-dkml-byte-${DKML_TARGET_ABI}-u-${DKML_VERSION_SEMVER}.exe)
        list(APPEND byproducts_native
            unsigned-dkml-native-${DKML_TARGET_ABI}-i-${DKML_VERSION_SEMVER}.exe
            unsigned-dkml-native-${DKML_TARGET_ABI}-u-${DKML_VERSION_SEMVER}.exe)
    endif()

    list(TRANSFORM byproducts_byte PREPEND ${switchPath}/share/dkml-installer-ocaml-offline/t/)
    list(TRANSFORM byproducts_native PREPEND ${switchPath}/share/dkml-installer-ocaml-network/t/)

    set(installerCreated ${opamsw}/installer.created)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}

        # opam binaries often do not have timestamps updated due to
        # opam seeing no changes. So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch] command.
        OUTPUT ${installerCreated}
        BYPRODUCTS ${byproducts_byte} ${byproducts_native}
        MAIN_DEPENDENCY upsert-installer.in.sh
        DEPENDS
        ${newSemverFile}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${ARG_DEPENDS}
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-component-desktop.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-component-ocamlcompiler.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-component-ocamlrun.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-component-opam.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-component-unixutils.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-installer-ocaml-byte.shortref
        ${CMAKE_CURRENT_BINARY_DIR}/depends/dkml-installer-ocaml.shortref
        COMMENT "Creating/updating ${DKML_VERSION_CMAKEVER} installer"
        COMMAND ${upsert_installer_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${installerCreated}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-Stage07-Installer
        DEPENDS ${installerCreated}
        VERBATIM
    )
    set(${ARG_OUTPUT_LIST_VARIABLE} ${installerCreated} PARENT_SCOPE)
endfunction()

function(add_OpamConsoleUpgrade_target)
    set(noValues)
    set(singleValues)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    prepare_upsert_variables(
        ID so
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SWITCH_NAME SWITCH_NAME
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH_PATH switchPath)

    foreach(p IN ITEMS upsert-opam-console-upgrade)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-opam-console-upgrade.sh upsert_opam_console_upgrade_COMMAND)

    add_custom_target(Package-OpamConsoleUpgrade
        WORKING_DIRECTORY ${opamsw}
        COMMAND ${upsert_opam_console_upgrade_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
endfunction()

function(add_all_stage_targets)
    set(noValues)
    set(singleValues)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)

    set(selfOutput ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/self)
    set(packageUpgradeOutputs)

    set(gitPushRemainingTargetDepends)

    # Stage 1
    if(NOT DKML_GOLDEN_SOURCE_CODE)
        add_VersionBump_target_for_synced_projects(
            TARGET Package-Stage01-VersionBump
            FILTER PRE_DUNE)
    endif()

    # Stage 2 and 4
    add_Flavor_targets(
        OUTPUT_LIST_VARIABLE_DUNE duneFlavorOutputs
        OUTPUT_LIST_VARIABLE_FULL fullFlavorOutputs)
    if(NOT DKML_GOLDEN_SOURCE_CODE)
        add_dependencies(Package-Stage02-DuneFlavor Package-Stage01-VersionBump)
    endif()

    # Stage 3
    if(NOT DKML_GOLDEN_SOURCE_CODE)
        add_VersionBump_target_for_synced_projects(
            TARGET Package-Stage03-VersionBump
            FILTER POST_DUNE
            DEPENDS ${duneFlavorOutputs})
        add_dependencies(Package-Stage03-VersionBump Package-Stage02-DuneFlavor)    
        add_dependencies(Package-Stage04-FullFlavor Package-Stage03-VersionBump)
    endif()

    # Stage 5
    add_Api_target(
        OUTPUT_LIST_VARIABLE apiOutputs
        DEPENDS ${fullFlavorOutputs}
        VERBATIM)
    if(DKML_GOLDEN_SOURCE_CODE)
        add_dependencies(Package-Stage05-Api Package-Stage02-DuneFlavor)
    else()
        add_dependencies(Package-Stage05-Api Package-Stage04-FullFlavor)
    endif()

    # Stage 6
    if(NOT DKML_GOLDEN_SOURCE_CODE)
        get_switch_path(OUTPUT_SWITCH_PATH switchPath)
        add_PackageUpgrade_target(
            DEPENDS
            ${apiOutputs}
            ${switchPath}/bin/common-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
            ${switchPath}/bin/package-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
            OPAMROOT ${anyrun_OPAMROOT}
            OPAMEXE ${anyrun_OPAMEXE})
        add_dependencies(Package-Stage06-PackageUpgrade Package-Stage05-Api)
    endif()

    # Stage 7
    add_Installer_target(
        OUTPUT_LIST_VARIABLE installerOutputs
        DEPENDS ${packageUpgradeOutputs}
        VERBATIM)
    if(DKML_GOLDEN_SOURCE_CODE)
        add_dependencies(Package-Stage07-Installer Package-Stage05-Api)
    else()
        add_dependencies(Package-Stage07-Installer Package-Stage06-PackageUpgrade)
    endif()

    # Every Stage after is modifications to the source code base.
    if(DKML_GOLDEN_SOURCE_CODE)
        return()
    endif()

    # Stage 8
    add_RepositoryUpdate_target(
        DEPENDS ${installerOutputs})
    add_dependencies(Package-Stage08-RepositoryUpdate Package-Stage07-Installer)

    # Stage 9. diskuv-opam-repository
    add_VersionBump_target_for_synced_projects(
        TARGET Package-Stage09-VersionBump
        FILTER FINAL)
    add_dependencies(Package-Stage09-VersionBump Package-Stage08-RepositoryUpdate)

    # Stage 10.
    # - During testing (ex. Windows Sandbox) of the installer the installer
    #   will use a versioned diskuv-opam-repository, so the
    #   [diskuv-opam-repository] project must be tagged if we want to test
    #   before the last step (which tags and pushes the vast majority of
    #   synced projects).
    # - The tag for dkml [self] must be available before a release can be
    #   created in GitLab, so this stage precedes any installer testing.
    # - However, our [self] version.cmake cannot be updated until the last
    #   stage (or else if a subsequent stage is in a different CMake build invocation,
    #   CMake will be auto-reconfigured and a completely new version will start).
    add_GitPush_command(
        SOURCE_DIR ${PROJECT_SOURCE_DIR}
        CONTEXT self
        BRANCH ${self_BRANCH}
        INTENDED_TARGET Package-Stage10-GitPushForTesting
        OUTPUT_FILE ${selfOutput}/pushed-starting)
    add_GitPush_commands_for_synced_projects(
        OUTPUT_LIST_VARIABLE gitPushForTestingTargetDepends
        INCLUDE diskuv-opam-repository
        INTENDED_TARGET Package-Stage10-GitPushForTesting)
    add_custom_target(Package-Stage10-GitPushForTesting
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${gitPushForTestingTargetDepends} ${selfOutput}/pushed-starting
        VERBATIM)
    add_dependencies(Package-Stage10-GitPushForTesting Package-Stage01-VersionBump)
    add_dependencies(Package-Stage10-GitPushForTesting Package-Stage03-VersionBump)
    add_dependencies(Package-Stage10-GitPushForTesting Package-Stage09-VersionBump)
    add_dependencies(Package-Stage10-GitPushForTesting Package-Stage08-RepositoryUpdate)

    # Stage 11
    DkMLPublish_CreateReleaseTarget(
        TARGET Package-Stage11-CreateRelease
    )
    add_dependencies(Package-Stage11-CreateRelease Package-Stage10-GitPushForTesting)

    # Stage 12
    DkMLPublish_PublishAssetsTarget(
        TARGET Package-Stage12-PublishAssets
        ARCHIVE_TARGET Package-Archive
    )
    add_dependencies(Package-Stage12-PublishAssets Package-Stage11-CreateRelease)

    # Last Stage. Do push of all synced projects (except diskuv-opam-repository which is
    # already done), and do final push of [self]
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/self/committed
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/finish .
        COMMAND ${GIT_EXECUTABLE} -c core.safecrlf=false add ${SELF_MODIFICATIONS}
        COMMAND ${GIT_EXECUTABLE} commit -m "Bump version: ${DKML_VERSION_SEMVER} -> ${DKML_VERSION_SEMVER}"
    )
    add_GitPush_command(
        SOURCE_DIR ${PROJECT_SOURCE_DIR}
        CONTEXT self
        TAG_SUFFIX -final
        BRANCH ${self_BRANCH}
        INTENDED_TARGET Package-Stage13-GitPushRemaining
        OUTPUT_FILE ${selfOutput}/pushed-finished
        DEPENDS ${selfOutput}/pushed-starting ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/self/committed)
    add_GitPush_commands_for_synced_projects(
        OUTPUT_LIST_VARIABLE gitPushRemainingTargetDepends
        EXCLUDE diskuv-opam-repository
        INTENDED_TARGET Package-Stage13-GitPushRemaining
        DEPENDS ${selfOutput}/pushed-finished)
    add_custom_target(Package-Stage13-GitPushRemaining
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${gitPushRemainingTargetDepends}
        VERBATIM)
    add_dependencies(Package-Stage13-GitPushRemaining Package-Stage10-GitPushForTesting)
endfunction()

add_GenerateLaunchers_target()
if(NOT DKML_GOLDEN_SOURCE_CODE)
    DkMLPublish_AddArchiveTarget(
        TARGET Package-Archive
        PROJECTS ${DKML_PROJECTS_PREDUNE} ${DKML_PROJECTS_POSTDUNE}
    )
endif()

if(DKML_GOLDEN_SOURCE_CODE)
    add_all_stage_targets()
    add_OpamConsoleUpgrade_target()
else()
    # All the stage targets are conditional on having run a Package-VersionBump-XXXX target.
    # That will have adjusted DKML_VERSION_CMAKEVER in version.cmake, and a subsequent
    # `cmake -G` will have created the versioned [dkmlroot] and [semver] files from the
    # now-updated DKML_VERSION_CMAKEVER.
    if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/semver)
        add_all_stage_targets()
        add_OpamConsoleUpgrade_target()
    else()
        message(NOTICE "GETTING STARTED: You will need to run one of the Package-VersionBump-* targets, and then rerun CMake configure, before you can see the Package-Stage*-* targets.")
    endif()
endif()

# Subdirectories
set(PACKAGING_OPAMROOT ${anyrun_OPAMROOT})

add_subdirectory(WindowsSandbox)