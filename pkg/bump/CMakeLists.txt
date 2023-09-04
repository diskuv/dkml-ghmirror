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
#
foreach(BUMP_LEVEL IN LISTS BUMP_LEVELS)
    file(CONFIGURE OUTPUT new-${BUMP_LEVEL}-semver CONTENT "@DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}@" @ONLY NEWLINE_STYLE UNIX)
    file(CONFIGURE OUTPUT new-${BUMP_LEVEL}-dkmlroot CONTENT "dkml_root_version=@DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}@" @ONLY NEWLINE_STYLE UNIX)
endforeach()

# ----------------
# Make variables for all synced projects _and_ unsynced projects to have a
# opam-install-friendly relative directory to PROJECT_SOURCE_DIR, and a
# short git reference.

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
endforeach()

# ----------------
#
function(stage_self_VersionReplace)
    set(noValues)
    set(singleValues BUMP_LEVEL STAGE NEW_VERSION_CMAKEVER NEW_PUBLICVERSION_CMAKEVER OUTPUT_LIST_VARIABLE REL_FILENAME)
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

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/replace-${ARG_STAGE}/${ARG_BUMP_LEVEL}/${ARG_REL_FILENAME} "${contents_NEW}")

    # Add to list
    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})
    list(APPEND retval ${PROJECT_SOURCE_DIR}/${ARG_REL_FILENAME})
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(stage_self_DkMLReplace)
    set(noValues)
    set(singleValues BUMP_LEVEL STAGE NEW_VERSION_SEMVER OUTPUT_LIST_VARIABLE REL_FILENAME)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    file(READ ${PROJECT_SOURCE_DIR}/${ARG_REL_FILENAME} contents)
    string(REGEX REPLACE "DkML [0-9.-]+" "DkML ${ARG_NEW_VERSION_SEMVER}" contents_NEW "${contents}")

    if(contents STREQUAL "${contents_NEW}")
        return()
    endif()

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/replace-${ARG_STAGE}/${ARG_BUMP_LEVEL}/${ARG_REL_FILENAME} "${contents_NEW}")

    # Add to list
    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})
    list(APPEND retval ${PROJECT_SOURCE_DIR}/${ARG_REL_FILENAME})
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(stage_self_Changes)
    set(noValues)
    set(singleValues BUMP_LEVEL STAGE NEW_VERSION_SEMVER OUTPUT_LIST_VARIABLE OUTPUT_DEPENDS)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    # Find vX.Y.Z.md. Set DEPENDS
    if(EXISTS ${PROJECT_SOURCE_DIR}/contributors/changes/v${ARG_NEW_VERSION_SEMVER}.md)
        file(READ ${PROJECT_SOURCE_DIR}/contributors/changes/v${ARG_NEW_VERSION_SEMVER}.md versionChanges)
        set(${ARG_OUTPUT_DEPENDS} ${PROJECT_SOURCE_DIR}/contributors/changes/v${ARG_NEW_VERSION_SEMVER}.md PARENT_SCOPE)
    else()
        set(versionChanges "## ${ARG_NEW_VERSION_SEMVER} (@@YYYYMMDD@@)")
        set(${ARG_OUTPUT_DEPENDS} PARENT_SCOPE)
    endif()

    file(READ ${PROJECT_SOURCE_DIR}/CHANGES.md priorChanges)

    # First line in CHANGES.md should be a top-level heading "# CHANGES" to
    # be valid Markdown. So strip it so we can add it back.
    string(REGEX REPLACE "^# CHANGES[^\n]*\n" "" priorChanges "${priorChanges}")

    string(TIMESTAMP now_YYYYMMDD "%Y-%m-%d")
    string(REPLACE "@@YYYYMMDD@@" ${now_YYYYMMDD} versionChanges "${versionChanges}")

    string(STRIP "${versionChanges}" versionChanges)
    string(STRIP "${priorChanges}" priorChanges)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/replace-${ARG_STAGE}/${ARG_BUMP_LEVEL}/CHANGES.md "# CHANGES\n\n${versionChanges}\n\n${priorChanges}")

    # Add to list
    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})
    list(APPEND retval ${PROJECT_SOURCE_DIR}/CHANGES.md)
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_VersionBump_target_for_synced_projects)
    set(noValues)
    set(singleValues TARGET BUMP_LEVEL FILTER)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)

    # For PRERELEASE we want fuzzy matching on any prior PRERELEASE because
    # we expect partial completions during PRERELEASE.
    #
    # For example, a PRERELEASE bump could be successful for half of
    # the packages, but then terminated due to a failure (perhaps this script
    # has a bug!). The failure would get fixed. Then a new PRERELEASE bump
    # occurs. Once it finishes end-to-end without failures ... only then
    # do you do a PATCH (or MINOR or MAJOR) bump.
    if(ARG_BUMP_LEVEL STREQUAL "PRERELEASE")
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
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
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

FetchContent_GetProperties(dkml-runtime-distribution)
file(GLOB dkml-runtime-distribution_PKGS_FILES
    LIST_DIRECTORIES false
    ${dkml-runtime-distribution_SOURCE_DIR}/src/none/*-pkgs.txt)

function(add_PackageUpgrade_target)
    set(noValues)
    set(singleValues BUMP_LEVEL OPAMROOT OPAMEXE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    shorten_bump_level(BUMP_LEVEL ${ARG_BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)

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
            OPAMSWITCH=${SHORT_BUMP_LEVEL}
            ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D "DKML_BUMP_PACKAGES_PARTICIPANT_MODULE=${participant}"
            -D DKML_RELEASE_DUNE_VERSION=${DKML_RELEASE_DUNE_VERSION}
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
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
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage06-PackageUpgrade
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Running bump-packages.cmake in ${bumpedProjects_SPACES}"
        DEPENDS ${ARG_DEPENDS}
        ${target_COMMANDS}
        SOURCES ${target_SOURCES}
        VERBATIM USES_TERMINAL)
endfunction()

function(add_RepositoryUpdate_target)
    set(noValues)
    set(singleValues BUMP_LEVEL)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    shorten_bump_level(BUMP_LEVEL ${ARG_BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)

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
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
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
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage08-RepositoryUpdate
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Running bump-repository.cmake in ${bumpedProjects_SPACES}"
        DEPENDS ${ARG_DEPENDS}
        ${target_COMMANDS}
        COMMAND ${CMAKE_COMMAND} -E echo "Run [promote.sh] in diskuv-opam-repository to promote the update to the central opam repository"
        SOURCES ${target_SOURCES}
        VERBATIM USES_TERMINAL)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage08-RepositoryUpdate Package-Archive)
endfunction()

function(update_Git)
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
    set(singleValues SOURCE_DIR CONTEXT BUMP_LEVEL OUTPUT_FILE BRANCH INTENDED_TARGET TAG_SUFFIX)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(refspec ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}})

    if(ARG_TAG_SUFFIX)
        string(APPEND refspec "${ARG_TAG_SUFFIX}")
    endif()

    if(ARG_BUMP_LEVEL STREQUAL PRERELEASE)
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
        -D "BUMP_LEVEL=${ARG_BUMP_LEVEL}"
        -D "DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}${ARG_TAG_SUFFIX}"
        -D "DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}"
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
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE INTENDED_TARGET)
    set(multiValues DEPENDS INCLUDE EXCLUDE)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
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

        set(outputDir ${CMAKE_CURRENT_BINARY_DIR}/GitPush/${proj})

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
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            SOURCE_DIR ${srcDir}
            CONTEXT ${proj}
            OUTPUT_FILE ${outputDir}/pushed-${ARG_BUMP_LEVEL}
            BRANCH ${branch}
            INTENDED_TARGET ${ARG_INTENDED_TARGET}
            DEPENDS ${ARG_DEPENDS})
        list(APPEND retval ${outputDir}/pushed-${ARG_BUMP_LEVEL})
    endforeach()

    # Add to list
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(get_flavor_packages)
    set(noValues)
    set(singleValues OUTPUT_PKGS_VARIABLE OUTPUT_PKGVERS_VARIABLE OUTPUT_DEPENDS)
    set(multiValues FLAVORS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    FetchContent_GetProperties(dkml-runtime-distribution)
    set(pkgvers)
    set(depends)

    macro(grok PKGS_TXT)
        # Read non-comment, non-blank lines that have a dot (.) in them
        file(STRINGS ${PKGS_TXT} strings REGEX "^[^#] *[a-z].*[.]")
        list(APPEND pkgvers ${strings})
        list(APPEND depends ${PKGS_TXT})
    endmacro()

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

foreach(proj IN LISTS DKML_PROJECTS_SYNCED)
    FetchContent_GetProperties(${proj})
    set(srcDir ${${proj}_SOURCE_DIR})
    set(branch ${${proj}_BRANCH})
    update_Git(SOURCE_DIR ${srcDir} BRANCH ${branch})
endforeach()

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

# FULL_NOT_DUNE_FLAVOR_PKGVERS without [conf-withdkml]
# * [conf-withdkml] pulls in an external [with-dkml.exe] which is not
# repeatable (ie. not hermetic).
set(fullNoDuneNoWithdkmlPkgVers ${FULL_NOT_DUNE_FLAVOR_PKGVERS})
list(FILTER fullNoDuneNoWithdkmlPkgVers EXCLUDE REGEX "^conf-withdkml[.]")
list(JOIN fullNoDuneNoWithdkmlPkgVers " " FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS)

# -----------------------------------
# GenerateLaunchers
# -----------------------------------
set(WITH_COMPILER_SH ${CMAKE_CURRENT_BINARY_DIR}/with-compiler.sh) # Used by generate-compiler-launcher.sh and upsert-*.sh

function(add_GenerateLaunchers_target)
    FetchContent_GetProperties(dkml-workflows)

    if(CMAKE_HOST_WIN32)
        set(setupScript "${POWERSHELL_EXECUTABLE}" "${dkml-workflows_SOURCE_DIR}/test/pc/setup-dkml-${DKML_TARGET_ABI}.ps1")
    else()
        set(setupScript "${dkml-workflows_SOURCE_DIR}/test/pc/setup-dkml-${DKML_TARGET_ABI}.ps1")
    endif()

    add_custom_command(
        OUTPUT ${anyrun_OUTPUTS}
        COMMENT "Creating [cmdrun] and [opamrun] scripts"
        COMMAND
        ${setupScript}
        -PC_PROJECT_DIR "${CMAKE_CURRENT_BINARY_DIR}"

        # Same as dkml-component-desktop's .gitlab-ci.yml [variables:]
        -SECONDARY_SWITCH true

        # We go further than current (2023-06) dkml-component-desktop by
        # setup-dkml not installing _any_ switches. We do that entirely with
        # CMake so we can set the FetchContent based local pins.
        -SKIP_OPAM_MODIFICATIONS true

        # -DISKUV_OPAM_REPOSITORY main
        VERBATIM
        USES_TERMINAL
    )

    FetchContent_GetProperties(dkml-runtime-common)
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
        DEPENDS ${GEN_COMPILER_DEPENDS}
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
    if(CMAKE_HOST_WIN32)
        set(${OUTVAR} ${MSYS2_BASH_RUN} "${CMAKE_CURRENT_BINARY_DIR}/anyrun.sh" ${SCRIPT} PARENT_SCOPE)
    else()
        set(${OUTVAR} "${CMAKE_CURRENT_BINARY_DIR}/anyrun.sh" ${SCRIPT} PARENT_SCOPE)
    endif()
endfunction()

# -----------------------------------
function(get_bump_switch)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_SWITCH)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    shorten_bump_level(BUMP_LEVEL ${ARG_BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)
    set(${ARG_OUTPUT_SWITCH} ${anyrun_OPAMROOT}/${SHORT_BUMP_LEVEL} PARENT_SCOPE)
endfunction()

function(prepare_upsert_variables)
    set(noValues)
    set(singleValues ID BUMP_LEVEL
        OUTPUT_SHORT_BUMP_LEVEL OUTPUT_WORKING_DIRECTORY OUTPUT_SWITCH OUTPUT_UPSERT_UTILS)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    get_bump_switch(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_SWITCH bumpSwitch
    )

    shorten_bump_level(BUMP_LEVEL ${ARG_BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)
    set(workdir ${CMAKE_CURRENT_BINARY_DIR}/${ARG_ID}/${SHORT_BUMP_LEVEL})
    FetchContent_GetProperties(dkml-runtime-common)
    set(UPSERT_UTILS ${workdir}/upsert-utils.sh)

    configure_file(upsert-utils.in.sh ${workdir}/upsert-utils.sh
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        @ONLY NEWLINE_STYLE UNIX)

    if(ARG_OUTPUT_SHORT_BUMP_LEVEL)
        set(${ARG_OUTPUT_SHORT_BUMP_LEVEL} ${SHORT_BUMP_LEVEL} PARENT_SCOPE)
    endif()

    set(${ARG_OUTPUT_WORKING_DIRECTORY} ${workdir} PARENT_SCOPE)
    set(${ARG_OUTPUT_SWITCH} ${bumpSwitch} PARENT_SCOPE)
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
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE_DUNE OUTPUT_LIST_VARIABLE_FULL)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)

    prepare_upsert_variables(
        ID sw
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SHORT_BUMP_LEVEL SHORT_BUMP_LEVEL # Used by upsert-dkml-switch
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH bumpSwitch
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
        DKML_VERSION_OPAMVER_NEW ${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
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
    file(CONFIGURE OUTPUT ${opamsw}/rerun-on-DISKUV_OPAM_REPOSITORY_GITREF
        CONTENT "@DISKUV_OPAM_REPOSITORY_GITREF@"
        @ONLY NEWLINE_STYLE UNIX
    )

    # Checksum to retrigger introspection
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
    set(DISKUV_OPAM_REPOSITORY_NAME_NEW diskuv-${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}) # Used by upsert-dkml-pkgs-flavor-full-not-dune

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
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-dkmlroot ${DKML_ROOT_DIR}/.dkmlroot

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
        ${bumpSwitch}/.opam-switch/switch-config
        ${bumpSwitch}/.opam-switch/environment
        MAIN_DEPENDENCY upsert-dkml-switch.in.sh
        DEPENDS
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${opamsw}/rerun-on-DISKUV_OPAM_REPOSITORY_GITREF
        ${dkml-runtime-distribution_SOURCE_DIR}/src/unix/create-opam-switch.sh
        ${dkml-runtime-distribution_SOURCE_DIR}/src/unix/private/init-opam-root.sh
        ${dkml-runtime-distribution_SOURCE_DIR}/src/unix/private/platform-opam-exec.sh
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} opam switch"

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
        BYPRODUCTS ${bumpSwitch}/bin/ocamlopt.opt${CMAKE_EXECUTABLE_SUFFIX}
        MAIN_DEPENDENCY upsert-dkml-pkgs-compiler.in.sh
        DEPENDS
        ${switchCreated}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${dkml-runtime-common_SOURCE_DIR}/dkml-runtime-common-native.opam
        ${dkml-compiler_SOURCE_DIR}/dkml-base-compiler.opam
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} compiler"
        COMMAND ${upsert_dkml_pkgs_compiler_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${compilerCreated}
        VERBATIM
        USES_TERMINAL
    )
    set(duneFlavorOutput ${DUNE_FLAVOR_PKGS})
    list(REMOVE_ITEM duneFlavorOutput ${PACKAGES_WITHOUT_META})
    list(TRANSFORM duneFlavorOutput PREPEND "${bumpSwitch}/lib/" OUTPUT_VARIABLE duneFlavorOutput)
    list(TRANSFORM duneFlavorOutput APPEND "/META" OUTPUT_VARIABLE duneFlavorOutput)
    file(CONFIGURE OUTPUT ${opamsw}/rerun-on-DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS
        CONTENT [[@DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS@]]
        @ONLY)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${duneFlavorOutput}
        MAIN_DEPENDENCY upsert-dkml-pkgs-flavor-dune.in.sh
        DEPENDS
        ${compilerCreated}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${opamsw}/rerun-on-DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} distribution - Dune flavor"
        COMMAND ${upsert_dkml_pkgs_dune_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage02-DuneFlavor
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
    list(TRANSFORM fullFlavorOutput PREPEND "${bumpSwitch}/lib/" OUTPUT_VARIABLE fullFlavorOutput)
    list(TRANSFORM fullFlavorOutput APPEND "/META" OUTPUT_VARIABLE fullFlavorOutput)
    file(GLOB_RECURSE flavor_full_DEPENDS
        LIST_DIRECTORIES false

        ${dkml-runtime-apps_SOURCE_DIR}/src/*)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${fullFlavorOutput}
        MAIN_DEPENDENCY upsert-dkml-pkgs-flavor-full-not-dune.in.sh
        DEPENDS ${duneFlavorOutput} ${WITH_COMPILER_SH} ${anyrun_OUTPUTS} ${flavor_full_DEPENDS}
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} distribution - Full flavor"
        COMMAND ${upsert_dkml_pkgs_full_not_dune_COMMAND}
        VERBATIM
        USES_TERMINAL
    )

    set(introspectCreated ${opamsw}/introspect.created)
    file(GLOB dkml_build_desktop_DEPENDS
        LIST_DIRECTORIES false

        # Compiled by dkml-build-desktop.opam
        ${dkml-component-desktop_SOURCE_DIR}/src/citime/*)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}

        # opam binaries often do not have timestamps updated due to
        # opam seeing no changes. So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch] command.
        OUTPUT ${introspectCreated}
        BYPRODUCTS
        ${bumpSwitch}/bin/dkml-desktop-gen-globals${CMAKE_EXECUTABLE_SUFFIX}
        MAIN_DEPENDENCY upsert-dkml-pkgs-introspect.in.sh
        DEPENDS
        ${fullFlavorOutput}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${dkml_build_desktop_DEPENDS}
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} introspect"
        COMMAND ${upsert_dkml_pkgs_introspect_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${introspectCreated}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage04-FullFlavor
        DEPENDS ${introspectCreated} ${DEPENDS_FLAVORS_CI_Full}
        VERBATIM
    )
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage04-FullFlavor
        Package-${ARG_BUMP_LEVEL}-Stage02-DuneFlavor)
    set(${OUTPUT_LIST_VARIABLE_FULL} ${introspectCreated} PARENT_SCOPE)
endfunction()

function(add_Api_target)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)

    prepare_upsert_variables(
        ID sa
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SHORT_BUMP_LEVEL SHORT_BUMP_LEVEL
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH bumpSwitch)

    FetchContent_GetProperties(dkml-install-api) # upsert-api
    FetchContent_GetProperties(dkml-workflows) # upsert-api

    set(apiSources)
    file(GLOB sources LIST_DIRECTORIES false
        ${dkml-install-api_SOURCE_DIR}/*.opam
        ${dkml-install-api_SOURCE_DIR}/*.opam.template
        ${dkml-workflows_SOURCE_DIR}/*.opam
        ${dkml-workflows_SOURCE_DIR}/*.opam.template
        ${dkml-installer-ocaml}/dkml-installer-ocaml-common.opam)
    list(APPEND apiSources ${sources})
    file(GLOB_RECURSE sources LIST_DIRECTORIES false
        ${dkml-install-api_SOURCE_DIR}/api/*.ml
        ${dkml-install-api_SOURCE_DIR}/installer/*.ml
        ${dkml-install-api_SOURCE_DIR}/package/*.ml
        ${dkml-install-api_SOURCE_DIR}/register/*.ml
        ${dkml-install-api_SOURCE_DIR}/runner/*.ml)
    list(APPEND apiSources ${sources})
    
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
        ${bumpSwitch}/bin/common-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        ${bumpSwitch}/bin/package-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        MAIN_DEPENDENCY upsert-api.in.sh
        DEPENDS
        ${newSemverFile}
        ${WITH_COMPILER_SH}
        ${anyrun_OUTPUTS}
        ${ARG_DEPENDS}
        ${apiSources}
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} api"
        COMMAND ${upsert_api_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${apiCreated}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage05-Api
        DEPENDS ${apiCreated}
        VERBATIM
    )
    set(${ARG_OUTPUT_LIST_VARIABLE} ${apiCreated} PARENT_SCOPE)
endfunction()

function(add_Installer_target)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)

    prepare_upsert_variables(
        ID si
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SHORT_BUMP_LEVEL SHORT_BUMP_LEVEL
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH bumpSwitch)

    FetchContent_GetProperties(dkml-compiler) # upsert-installer
    FetchContent_GetProperties(dkml-component-desktop) # upsert-installer
    FetchContent_GetProperties(dkml-component-ocamlcompiler) # upsert-installer
    FetchContent_GetProperties(dkml-component-ocamlrun) # upsert-installer
    FetchContent_GetProperties(dkml-component-opam) # upsert-installer
    FetchContent_GetProperties(dkml-component-unixutils) # upsert-installer
    FetchContent_GetProperties(dkml-install-api) # upsert-installer
    FetchContent_GetProperties(dkml-installer-ocaml) # upsert-installer
    FetchContent_GetProperties(dkml-installer-ocaml-byte) # upsert-installer

    set(installerSources)
    file(GLOB sources LIST_DIRECTORIES false
        ${dkml-installer-ocaml_SOURCE_DIR}/META.*
        ${dkml-installer-ocaml_SOURCE_DIR}/*.opam
        ${dkml-installer-ocaml_SOURCE_DIR}/*.opam.template
        ${dkml-installer-ocaml-byte_SOURCE_DIR}/META.*
        ${dkml-installer-ocaml-byte_SOURCE_DIR}/*.opam
        ${dkml-installer-ocaml-byte_SOURCE_DIR}/*.opam.template
        ${dkml-installer-opam_SOURCE_DIR}/META.*
        ${dkml-installer-opam_SOURCE_DIR}/*.opam
        ${dkml-installer-opam_SOURCE_DIR}/*.opam.template
        ${dkml-component-unixutils_SOURCE_DIR}/META.*
        ${dkml-component-unixutils_SOURCE_DIR}/*.opam
        ${dkml-component-unixutils_SOURCE_DIR}/*.opam.template)
    list(APPEND installerSources ${sources})
    file(GLOB_RECURSE sources LIST_DIRECTORIES false
        ${dkml-installer-ocaml_SOURCE_DIR}/i-common/src/*
        ${dkml-installer-ocaml_SOURCE_DIR}/i-network/bin/*
        ${dkml-installer-ocaml_SOURCE_DIR}/i-network/src/*
        ${dkml-installer-ocaml-byte_SOURCE_DIR}/i-offline/bin/*
        ${dkml-installer-ocaml-byte_SOURCE_DIR}/i-offline/src/*        
        ${dkml-component-desktop_SOURCE_DIR}/src/*
        ${dkml-component-opam_SOURCE_DIR}/src/*
        ${dkml-component-unixutils_SOURCE_DIR}/src/*)
    list(APPEND installerSources ${sources})

    foreach(p IN ITEMS
        upsert-installer)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-installer.sh upsert_installer_COMMAND)

    set(byproducts bundle-diskuv-ocaml-generic-i.sh bundle-diskuv-ocaml-generic-u.sh)
    set(byproducts_byte ${byproducts})
    set(byproducts_native ${byproducts})

    if(DKML_TARGET_ABI STREQUAL windows_x86 OR DKML_TARGET_ABI STREQUAL windows_x86_64)
        list(APPEND byproducts_byte
            unsigned-dkml-lite-${DKML_TARGET_ABI}-i-${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}.exe
            unsigned-dkml-lite-${DKML_TARGET_ABI}-u-${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}.exe)
        list(APPEND byproducts_native
            unsigned-dkml-native-${DKML_TARGET_ABI}-i-${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}.exe
            unsigned-dkml-native-${DKML_TARGET_ABI}-u-${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}.exe)
    endif()

    list(TRANSFORM byproducts_byte PREPEND ${bumpSwitch}/share/dkml-installer-ocaml-offline/t/)
    list(TRANSFORM byproducts_native PREPEND ${bumpSwitch}/share/dkml-installer-ocaml-network/t/)

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
        ${installerSources}
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} installer"
        COMMAND ${upsert_installer_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${installerCreated}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage07-Installer
        DEPENDS ${installerCreated}
        VERBATIM
    )
    set(${ARG_OUTPUT_LIST_VARIABLE} ${installerCreated} PARENT_SCOPE)
endfunction()

function(add_OpamConsoleUpgrade_target)
    set(noValues)
    set(singleValues BUMP_LEVEL)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    prepare_upsert_variables(
        ID so
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_UPSERT_UTILS UPSERT_UTILS # Used by upsert-*
        OUTPUT_SHORT_BUMP_LEVEL SHORT_BUMP_LEVEL
        OUTPUT_WORKING_DIRECTORY opamsw
        OUTPUT_SWITCH bumpSwitch)

    foreach(p IN ITEMS upsert-opam-console-upgrade)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-opam-console-upgrade.sh upsert_opam_console_upgrade_COMMAND)

    add_custom_target(Package-${ARG_BUMP_LEVEL}-OpamConsoleUpgrade
        WORKING_DIRECTORY ${opamsw}
        COMMAND ${upsert_opam_console_upgrade_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
endfunction()

function(add_all_targets)
    set(noValues)
    set(singleValues BUMP_LEVEL)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(selfModifications)

    if(ARG_BUMP_LEVEL STREQUAL "PRERELEASE")
        # PRERELEASE bump
        stage_self_VersionReplace(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            STAGE start
            NEW_VERSION_CMAKEVER ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            NEW_PUBLICVERSION_CMAKEVER ${DKML_PUBLICVERSION_CMAKEVER} # No change to the public version
            OUTPUT_LIST_VARIABLE selfModifications
            REL_FILENAME version.cmake)
        set(selfChanges_DEPENDS)
    else()
        # PATCH, MINOR or MAJOR bump
        stage_self_VersionReplace(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            STAGE start
            NEW_VERSION_CMAKEVER ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            NEW_PUBLICVERSION_CMAKEVER ${DKML_PUBLICVERSION_CMAKEVER} # No change to the public version at first
            OUTPUT_LIST_VARIABLE selfModifications
            REL_FILENAME version.cmake)
        stage_self_VersionReplace(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            STAGE end
            NEW_VERSION_CMAKEVER ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            NEW_PUBLICVERSION_CMAKEVER ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            OUTPUT_LIST_VARIABLE selfModifications
            REL_FILENAME version.cmake)
        stage_self_DkMLReplace(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            STAGE end
            NEW_VERSION_SEMVER ${DKML_PUBLICVERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            OUTPUT_LIST_VARIABLE selfModifications
            REL_FILENAME README.md)
        stage_self_Changes(
            BUMP_LEVEL ${ARG_BUMP_LEVEL}
            STAGE end
            NEW_VERSION_SEMVER ${DKML_PUBLICVERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            OUTPUT_LIST_VARIABLE selfModifications
            OUTPUT_DEPENDS selfChanges_DEPENDS)
    endif()

    list(REMOVE_DUPLICATES selfModifications)

    set(selfOutput ${CMAKE_CURRENT_BINARY_DIR}/self)
    set(versionBumpSelfStartOutput ${selfOutput}/bumped-start-${ARG_BUMP_LEVEL})
    set(packageUpgradeOutputs)
    add_custom_command(
        OUTPUT ${versionBumpSelfStartOutput}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/replace-start/${ARG_BUMP_LEVEL} .
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${versionBumpSelfStartOutput}
        VERBATIM)

    set(gitPushRemainingTargetDepends)

    # Stage 0
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage00-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${versionBumpSelfStartOutput}
        VERBATIM)

    # Stage 1
    add_VersionBump_target_for_synced_projects(
        TARGET Package-${ARG_BUMP_LEVEL}-Stage01-VersionBump
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER PRE_DUNE)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage01-VersionBump Package-${ARG_BUMP_LEVEL}-Stage00-VersionBump)

    # Stage 2 and 4
    add_Flavor_targets(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE_DUNE duneFlavorOutputs
        OUTPUT_LIST_VARIABLE_FULL fullFlavorOutputs)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage02-DuneFlavor Package-${ARG_BUMP_LEVEL}-Stage01-VersionBump)

    # Stage 3
    add_VersionBump_target_for_synced_projects(
        TARGET Package-${ARG_BUMP_LEVEL}-Stage03-VersionBump
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER POST_DUNE
        DEPENDS ${duneFlavorOutputs})
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage03-VersionBump Package-${ARG_BUMP_LEVEL}-Stage02-DuneFlavor)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage04-FullFlavor Package-${ARG_BUMP_LEVEL}-Stage03-VersionBump)

    # Stage 5
    add_Api_target(BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE apiOutputs
        DEPENDS ${fullFlavorOutputs}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage05-Api Package-${ARG_BUMP_LEVEL}-Stage04-FullFlavor)

    # Stage 6
    get_bump_switch(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_SWITCH bumpSwitch
    )
    add_PackageUpgrade_target(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        DEPENDS
        ${apiOutputs}
        ${bumpSwitch}/bin/common-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        ${bumpSwitch}/bin/package-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        OPAMROOT ${anyrun_OPAMROOT}
        OPAMEXE ${anyrun_OPAMEXE})
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage06-PackageUpgrade Package-${ARG_BUMP_LEVEL}-Stage05-Api)

    # Stage 7
    add_Installer_target(BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE installerOutputs
        DEPENDS ${packageUpgradeOutputs}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage07-Installer Package-${ARG_BUMP_LEVEL}-Stage06-PackageUpgrade)

    # Stage 8
    add_RepositoryUpdate_target(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        DEPENDS ${installerOutputs})
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage08-RepositoryUpdate Package-${ARG_BUMP_LEVEL}-Stage07-Installer)

    # Stage 9. diskuv-opam-repository
    add_VersionBump_target_for_synced_projects(
        TARGET Package-${ARG_BUMP_LEVEL}-Stage09-VersionBump
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER FINAL)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage09-VersionBump Package-${ARG_BUMP_LEVEL}-Stage08-RepositoryUpdate)

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
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        SOURCE_DIR ${PROJECT_SOURCE_DIR}
        CONTEXT self
        BRANCH ${self_BRANCH}
        INTENDED_TARGET Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting
        OUTPUT_FILE ${selfOutput}/pushed-starting-${ARG_BUMP_LEVEL}
        DEPENDS ${versionBumpSelfStartOutput})
    add_GitPush_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE gitPushForTestingTargetDepends
        INCLUDE diskuv-opam-repository
        INTENDED_TARGET Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting)
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${gitPushForTestingTargetDepends} ${selfOutput}/pushed-starting-${ARG_BUMP_LEVEL}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting Package-${ARG_BUMP_LEVEL}-Stage01-VersionBump)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting Package-${ARG_BUMP_LEVEL}-Stage03-VersionBump)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting Package-${ARG_BUMP_LEVEL}-Stage09-VersionBump)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting Package-${ARG_BUMP_LEVEL}-Stage08-RepositoryUpdate)

    # Stage 11
    if(ARG_BUMP_LEVEL STREQUAL "PRERELEASE")
        # There is no prerelease change.md, so use patch change.md
        set(DKML_VERSION_SEMVER_CHANGES_CreateRelease ${DKML_VERSION_SEMVER_NEW_PATCH})
    else()
        set(DKML_VERSION_SEMVER_CHANGES_CreateRelease ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}})
    endif()

    DkMLPublish_CreateReleaseTarget(
        TARGET Package-${ARG_BUMP_LEVEL}-Stage11-CreateRelease
        DKML_VERSION_SEMVER_NEW ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
        DKML_VERSION_SEMVER_CHANGES ${DKML_VERSION_SEMVER_CHANGES_CreateRelease}
    )
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage11-CreateRelease Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting)

    # Stage 12
    DkMLPublish_PublishAssetsTarget(
        TARGET Package-${ARG_BUMP_LEVEL}-Stage12-PublishAssets
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        ARCHIVE_TARGET Package-Archive
        DKML_VERSION_SEMVER_NEW ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
    )
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage12-PublishAssets Package-${ARG_BUMP_LEVEL}-Stage11-CreateRelease)

    # Last Stage. Do push of all synced projects (except diskuv-opam-repository which is
    # already done), and do final push of [self]
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/self/committed-${ARG_BUMP_LEVEL}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/replace-end/${ARG_BUMP_LEVEL} .
        COMMAND ${GIT_EXECUTABLE} -c core.safecrlf=false add ${selfModifications}
        COMMAND ${GIT_EXECUTABLE} commit -m "Bump version: ${DKML_VERSION_SEMVER} -> ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}"
    )
    add_GitPush_command(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        SOURCE_DIR ${PROJECT_SOURCE_DIR}
        CONTEXT self
        TAG_SUFFIX -final
        BRANCH ${self_BRANCH}
        INTENDED_TARGET Package-${ARG_BUMP_LEVEL}-Stage13-GitPushRemaining
        OUTPUT_FILE ${selfOutput}/pushed-finished-${ARG_BUMP_LEVEL}
        DEPENDS ${versionBumpSelfStartOutput} ${selfOutput}/pushed-starting-${ARG_BUMP_LEVEL} ${CMAKE_CURRENT_BINARY_DIR}/self/committed-${ARG_BUMP_LEVEL})
    add_GitPush_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE gitPushRemainingTargetDepends
        EXCLUDE diskuv-opam-repository
        INTENDED_TARGET Package-${ARG_BUMP_LEVEL}-Stage13-GitPushRemaining
        DEPENDS ${selfOutput}/pushed-finished-${ARG_BUMP_LEVEL})
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage13-GitPushRemaining
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${gitPushRemainingTargetDepends}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage13-GitPushRemaining Package-${ARG_BUMP_LEVEL}-Stage10-GitPushForTesting)
endfunction()

add_GenerateLaunchers_target()
add_OpamConsoleUpgrade_target(BUMP_LEVEL PRERELEASE)
DkMLPublish_AddArchiveTarget(
    TARGET Package-Archive
    PROJECTS ${DKML_PROJECTS_PREDUNE} ${DKML_PROJECTS_POSTDUNE}
)

foreach(BUMP_LEVEL IN LISTS BUMP_LEVELS)
    add_all_targets(BUMP_LEVEL ${BUMP_LEVEL})
endforeach()

# Subdirectories
set(PACKAGING_OPAMROOT ${anyrun_OPAMROOT})

add_subdirectory(WindowsSandbox)