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

set(syncedProjects
    ${DKML_PROJECTS_PREDUNE}
    ${DKML_PROJECTS_POSTDUNE}
    ${DKML_PROJECTS_FINAL}
)
set(self_BRANCH next-cmake) # self is [dkml]
set(diskuv-opam-repository_BRANCH main)
set(dkml-compiler_BRANCH main)
set(dkml-component-desktop_BRANCH main)
set(dkml-component-ocamlcompiler_BRANCH main)
set(dkml-component-ocamlrun_BRANCH main)
set(dkml-installer-ocaml_BRANCH main)
set(dkml-runtime-apps_BRANCH main)
set(dkml-runtime-common_BRANCH main)
set(dkml-runtime-distribution_BRANCH main)
set(dkml-workflows_BRANCH v1)

# Sanity check
foreach(PROJECT IN LISTS syncedProjects)
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
            message(FATAL_ERROR "The ${BUMP_LEVEL} public version ${DKML_PUBLICVERSION_CMAKEVER} was not found in ${PROJECT_SOURCE_DIR}/${REL_FILENAME}")
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
    if(EXISTS ${PROJECT_SOURCE_DIR}/contributors/changes/v${NEW_VERSION_SEMVER}.md)
        file(READ ${PROJECT_SOURCE_DIR}/contributors/changes/v${NEW_VERSION_SEMVER}.md versionChanges)
    else()
        set(versionChanges "## ${NEW_VERSION_SEMVER} (@@YYYYMMDD@@)")
    endif()

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

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(tar_ARGS)

    if(ARG_BUMP_LEVEL STREQUAL PRERELEASE)
        # Prereleases can always be overwritten, so force overwrite the git tag if present.
        list(APPEND tar_ARGS --force)
    endif()

    # We want the git tagging to be done always. We settle for doing
    # it in each re-configure by deleting the output file during re-configure.
    file(REMOVE ${ARG_OUTPUT_FILE})
    add_custom_command(
        OUTPUT ${ARG_OUTPUT_FILE}
        WORKING_DIRECTORY ${ARG_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${ARG_DEPENDS}

        COMMAND
        ${CMAKE_COMMAND}
        -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
        -D "BUMP_LEVEL=${ARG_BUMP_LEVEL}"
        -D "DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}"
        -D "DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}"
        -P ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/idempotent-tag.cmake
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${ARG_OUTPUT_FILE}
        VERBATIM
        USES_TERMINAL
    )
endfunction()

function(add_VersionBump_commands_for_synced_projects)
    set(noValues)
    set(singleValues BUMP_LEVEL FILTER OUTPUT_LIST_VARIABLE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})
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

        if(ARG_FILTER STREQUAL PRE_DUNE)
            if(NOT(proj IN_LIST DKML_PROJECTS_PREDUNE))
                continue()
            endif()

            string(APPEND outputDir /PRE)
        elseif(ARG_FILTER STREQUAL POST_DUNE)
            if(NOT(proj IN_LIST DKML_PROJECTS_POSTDUNE))
                continue()
            endif()

            string(APPEND outputDir /POST)
        elseif(ARG_FILTER STREQUAL FINAL)
            if(NOT(proj IN_LIST DKML_PROJECTS_FINAL))
                continue()
            endif()

            string(APPEND outputDir /FINAL)
        endif()

        set(OTHER_PKGUP_OUTPUTS ${BUMP_LEVELS})
        list(REMOVE_ITEM OTHER_PKGUP_OUTPUTS ${ARG_BUMP_LEVEL})
        list(TRANSFORM OTHER_PKGUP_OUTPUTS PREPEND ${outputDir}/bumped-)
        add_custom_command(
            OUTPUT ${outputDir}/bumped-${ARG_BUMP_LEVEL}
            WORKING_DIRECTORY ${srcDir}
            DEPENDS
            ${newSemverFile}
            ${srcDir}/bump-version.cmake
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpVersionParticipant.cmake
            ${ARG_DEPENDS}
            COMMAND ${CMAKE_COMMAND}
            --log-context
            -D CMAKE_MESSAGE_CONTEXT=${proj}
            -D "DKML_BUMP_VERSION_PARTICIPANT_MODULE=${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpVersionParticipant.cmake"
            -D DKML_RELEASE_OCAML_VERSION=${DKML_RELEASE_OCAML_VERSION}
            -D regex_DKML_VERSION_OPAMVER=${regex_DKML_VERSION_OPAMVER}
            -D regex_DKML_VERSION_SEMVER=${regex_DKML_VERSION_SEMVER}
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -P bump-version.cmake

            # Since bumping is per BUMP_LEVEL, while the _SOURCE_DIR that will be bumped
            # is global, we have to invalidate all other OUTPUTs from other BUMP_LEVELs
            COMMAND ${CMAKE_COMMAND} -E rm -f ${OTHER_PKGUP_OUTPUTS}
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${outputDir}/bumped-${ARG_BUMP_LEVEL}
            VERBATIM
            USES_TERMINAL
        )
        list(APPEND retval ${outputDir}/bumped-${ARG_BUMP_LEVEL})
    endforeach()

    # Add to list
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

FetchContent_GetProperties(dkml-runtime-distribution)
file(GLOB dkml-runtime-distribution_PKGS_FILES
    LIST_DIRECTORIES false
    ${dkml-runtime-distribution_SOURCE_DIR}/src/none/*-pkgs.txt)

function(add_PackageUpgrade_target)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE OPAMROOT OPAMEXE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})
    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    shorten_bump_level(BUMP_LEVEL ${ARG_BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)

    if(CMAKE_HOST_WIN32)
        set(bashExecutable ${MSYS2_BASH_RUN})
        string(REPLACE ";" "$<SEMICOLON>" bashExecutable "${bashExecutable}")
    else()
        set(bashExecutable bash)
    endif()

    cmake_path(NATIVE_PATH ARG_OPAMROOT NORMALIZE OPAMROOT_NATIVE)
    set(target_COMMANDS)
    set(target_DEPENDS ${ARG_DEPENDS})
    set(target_SOURCES)

    foreach(proj IN LISTS syncedProjects)
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

        # nit: We no longer need OTHER_PKGUP_OUTPUTS since we'll be
        # queuing up the COMMANDs rather than using add_custom_command()
        set(OTHER_PKGUP_OUTPUTS ${BUMP_LEVELS})
        list(REMOVE_ITEM OTHER_PKGUP_OUTPUTS ${ARG_BUMP_LEVEL})
        list(TRANSFORM OTHER_PKGUP_OUTPUTS PREPEND ${outputDir}/pkgup-)

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
            -D "DKML_BUMP_PACKAGES_PARTICIPANT_MODULE=${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpPackagesParticipant.cmake"
            -D DKML_RELEASE_DUNE_VERSION=${DKML_RELEASE_DUNE_VERSION}
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -D "OPAM_EXECUTABLE=${ARG_OPAMEXE}"
            -D "BASH_EXECUTABLE=${bashExecutable}"
            -D WITH_COMPILER_SH=${WITH_COMPILER_SH}
            -P bump-packages.cmake

            # Since bumping is per BUMP_LEVEL, while the _SOURCE_DIR that will be bumped
            # is global, we have to invalidate all other OUTPUTs from other BUMP_LEVELs
            COMMAND ${CMAKE_COMMAND} -E rm -f ${OTHER_PKGUP_OUTPUTS}
        )
    endforeach()

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage6-PackageUpgrade
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS
        ${newSemverFile}
        ${target_DEPENDS}
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpPackagesParticipant.cmake
        ${dkml-runtime-distribution_PKGS_FILES}

        ${target_COMMANDS}

        SOURCES ${target_SOURCES}
        VERBATIM USES_TERMINAL)

    # Add to list
    list(APPEND retval ${target_DEPENDS})
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_RepositoryUpdate_target)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})
    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    shorten_bump_level(BUMP_LEVEL ${ARG_BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)

    set(target_COMMANDS)
    set(target_DEPENDS ${ARG_DEPENDS})
    set(target_SOURCES)

    foreach(proj IN LISTS syncedProjects)
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
            -D "DKML_BUMP_REPOSITORY_PARTICIPANT_MODULE=${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpRepositoryParticipant.cmake"
            -D DKML_VERSION_OPAMVER_NEW=${DKML_VERSION_OPAMVER_NEW_${ARG_BUMP_LEVEL}}
            -D DKML_VERSION_SEMVER_NEW=${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            -D "BUMP_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            -D "DKML_SOURCE_ARCHIVE_DIR=${ARCHIVEDIR}"
            -D "GIT_EXECUTABLE=${GIT_EXECUTABLE}"
            -D "OPAM_EXECUTABLE=${ARG_OPAMEXE}"
            -P bump-repository.cmake
        )
    endforeach()

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage8-RepositoryUpdate
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS
        ${newSemverFile}
        ${target_DEPENDS}
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DkMLBumpRepositoryParticipant.cmake
        ${dkml-runtime-distribution_PKGS_FILES}

        ${target_COMMANDS}

        SOURCES ${target_SOURCES}
        VERBATIM USES_TERMINAL)

    # Add to list
    list(APPEND retval ${target_DEPENDS})
    set(${ARG_OUTPUT_LIST_VARIABLE} ${retval} PARENT_SCOPE)
endfunction()

function(add_GitPush_command)
    set(noValues)
    set(singleValues SOURCE_DIR CONTEXT BUMP_LEVEL OUTPUT_FILE BRANCH INTENDED_TARGET)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(refspec ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}})

    if(ARG_BUMP_LEVEL STREQUAL PRERELEASE)
        # Prereleases can always be overwritten, so add a leading +
        # (similar to --force) to force overwrite the git tag if present.
        # We don't use --force since that would apply to the [<currentBranch>]
        # branch as well (which we want to fail if it is not a fast-forward
        # commit).
        string(PREPEND refspec "+")
    endif()

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
        message(FATAL_ERROR "There is no branch (likely a detached HEAD) in ${ARG_SOURCE_DIR}")
    endif()

    add_GitTag_command(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        SOURCE_DIR ${ARG_SOURCE_DIR}
        CONTEXT ${ARG_CONTEXT}
        OUTPUT_FILE ${ARG_OUTPUT_FILE}-tagged
        DEPENDS ${ARG_DEPENDS})

    add_custom_command(
        OUTPUT ${ARG_OUTPUT_FILE}
        WORKING_DIRECTORY ${ARG_SOURCE_DIR}
        DEPENDS ${ARG_OUTPUT_FILE}-tagged

        COMMAND ${GIT_EXECUTABLE} push --atomic origin ${currentBranch} ${refspec}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${ARG_OUTPUT_FILE}
        VERBATIM
        USES_TERMINAL
    )
endfunction()

function(add_GitPush_commands_for_synced_projects)
    set(noValues)
    set(singleValues BUMP_LEVEL OUTPUT_LIST_VARIABLE INTENDED_TARGET)
    set(multiValues DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(retval ${${ARG_OUTPUT_LIST_VARIABLE}})

    foreach(proj IN LISTS syncedProjects)
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

function(get_flavor_packages FLAVORS OUTPUT_PKGS_VARIABLE OUTPUT_PKGVERS_VARIABLE)
    FetchContent_GetProperties(dkml-runtime-distribution)
    set(pkgvers)

    macro(grok PKGS_TXT)
        # Read non-comment, non-blank lines that have a dot (.) in them
        file(STRINGS ${PKGS_TXT} strings REGEX "^[^#] *[a-z].*[.]")
        list(APPEND pkgvers ${strings})
    endmacro()

    foreach(FLAVOR IN LISTS FLAVORS)
        string(TOLOWER "${FLAVOR}" lowerFlavor)
        grok(${dkml-runtime-distribution_SOURCE_DIR}/src/none/${lowerFlavor}-anyver-pkgs.txt)
        grok(${dkml-runtime-distribution_SOURCE_DIR}/src/none/${lowerFlavor}-${DKML_RELEASE_OCAML_VERSION}-pkgs.txt)
    endforeach()

    list(TRANSFORM pkgvers REPLACE "[.].*" "" OUTPUT_VARIABLE pkgs)

    set(${OUTPUT_PKGS_VARIABLE} ${pkgs} PARENT_SCOPE)
    set(${OUTPUT_PKGVERS_VARIABLE} ${pkgvers} PARENT_SCOPE)
endfunction()

get_flavor_packages(Dune DUNE_FLAVOR_PKGS DUNE_FLAVOR_PKGVERS)
get_flavor_packages("CI;Full" FULL_NOT_DUNE_FLAVOR_PKGS FULL_NOT_DUNE_FLAVOR_PKGVERS)

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
        SYNCHRONIZED_PACKAGES ${syncedProjects}
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
    set(dkml-runtime-apps_OPAMFILES ${dkml-runtime-apps_PACKAGES})
    list(TRANSFORM dkml-runtime-apps_OPAMFILES PREPEND "./")
    list(TRANSFORM dkml-runtime-apps_OPAMFILES APPEND ".opam")

    # dkml-runtime-apps: [opam-dkml] is deprecated; we don't install it
    set(dkml-runtime-apps_INSTALLABLE_OPAMFILES ${dkml-runtime-apps_OPAMFILES})
    list(REMOVE_ITEM dkml-runtime-apps_INSTALLABLE_OPAMFILES ./opam-dkml.opam)
    list(JOIN dkml-runtime-apps_INSTALLABLE_OPAMFILES " " dkml-runtime-apps_SPACED_INSTALLABLE_OPAMFILES)

    # Other values used in configure_file()
    set(DKML_ROOT_DIR ${opamsw}/dkmldir) # Used by upsert-*.sh scripts
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
        DEPENDS ${compilerCreated} ${WITH_COMPILER_SH} ${anyrun_OUTPUTS}
        ${opamsw}/rerun-on-DUNE_FLAVOR_NO_SHIM_SPACED_PKGVERS
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} distribution - Dune flavor"
        COMMAND ${upsert_dkml_pkgs_dune_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage2-DuneFlavor
        DEPENDS ${duneFlavorOutput}
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
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${fullFlavorOutput}
        MAIN_DEPENDENCY upsert-dkml-pkgs-flavor-full-not-dune.in.sh
        DEPENDS ${duneFlavorOutput} ${WITH_COMPILER_SH} ${anyrun_OUTPUTS}
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

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage4-FullFlavor
        DEPENDS ${introspectCreated}
        VERBATIM
    )
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage4-FullFlavor
        Package-${ARG_BUMP_LEVEL}-Stage2-DuneFlavor)
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
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} api"
        COMMAND ${upsert_api_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch ${apiCreated}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage5-Api
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

    set(installerSources)
    file(GLOB sources LIST_DIRECTORIES false
        ${dkml-installer-ocaml_SOURCE_DIR}/*.opam
        ${dkml-installer-ocaml_SOURCE_DIR}/*.opam.template)
    list(APPEND installerSources ${sources})
    file(GLOB_RECURSE sources LIST_DIRECTORIES false
        ${dkml-installer-ocaml_SOURCE_DIR}/installer/bin/*
        ${dkml-installer-ocaml_SOURCE_DIR}/installer/src/*)
    list(APPEND installerSources ${sources})

    foreach(p IN ITEMS
        upsert-installer)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-installer.sh upsert_installer_COMMAND)

    set(byproducts bundle-diskuv-ocaml-generic-i.sh bundle-diskuv-ocaml-generic-u.sh)

    if(DKML_TARGET_ABI STREQUAL windows_x86 OR DKML_TARGET_ABI STREQUAL windows_x86_64)
        list(APPEND byproducts
            unsigned-diskuv-ocaml-${DKML_TARGET_ABI}-i-${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}.exe
            unsigned-diskuv-ocaml-${DKML_TARGET_ABI}-u-${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}}.exe)
    endif()

    list(TRANSFORM byproducts PREPEND ${bumpSwitch}/share/dkml-installer-network-ocaml/t/)

    set(installerCreated ${opamsw}/installer.created)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}

        # opam binaries often do not have timestamps updated due to
        # opam seeing no changes. So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch] command.
        OUTPUT ${installerCreated}
        BYPRODUCTS ${byproducts}
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

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage7-Installer
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
    set(STAGE_LAST_GIT_PUSH Package-${ARG_BUMP_LEVEL}-Stage10-GitPush)

    if(ARG_BUMP_LEVEL STREQUAL "PRERELEASE")
        # PRERELEASE bump
        stage_self_VersionReplace(${ARG_BUMP_LEVEL}
            ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            ${DKML_PUBLICVERSION_CMAKEVER} # No change to the public version
            selfModifications version.cmake)
    else()
        # PATCH, MINOR or MAJOR bump
        stage_self_VersionReplace(${ARG_BUMP_LEVEL}
            ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            ${DKML_PUBLICVERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            selfModifications version.cmake)
        stage_self_DkMLReplace(${ARG_BUMP_LEVEL}
            ${DKML_PUBLICVERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            selfModifications README.md)
        stage_self_Changes(${ARG_BUMP_LEVEL}
            ${DKML_PUBLICVERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            selfModifications)
    endif()

    set(selfOutput ${CMAKE_CURRENT_BINARY_DIR}/self)
    set(versionBumpSelfOutput ${selfOutput}/bumped-${ARG_BUMP_LEVEL})
    set(versionBumpPreDuneOutputs)
    set(versionBumpPostDuneOutputs)
    set(versionBumpFinalOutputs)
    set(packageUpgradeOutputs)
    add_custom_command(
        OUTPUT ${versionBumpSelfOutput}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/_replace/${ARG_BUMP_LEVEL} .
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${versionBumpSelfOutput}
        VERBATIM)
    add_GitPush_command(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        SOURCE_DIR ${PROJECT_SOURCE_DIR}
        CONTEXT self
        BRANCH ${self_BRANCH}
        INTENDED_TARGET ${STAGE_LAST_GIT_PUSH}
        OUTPUT_FILE ${selfOutput}/pushed-${ARG_BUMP_LEVEL}
        DEPENDS ${versionBumpSelfOutput})

    set(gitPushTargetDepends ${selfOutput}/pushed-${ARG_BUMP_LEVEL})

    # Stage 0
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage0-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${versionBumpSelfOutput}
        VERBATIM)

    # Stage 1
    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER PRE_DUNE
        OUTPUT_LIST_VARIABLE versionBumpPreDuneOutputs)
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage1-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${versionBumpPreDuneOutputs}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage1-VersionBump Package-${ARG_BUMP_LEVEL}-Stage0-VersionBump)

    # Stage 2 and 4
    add_Flavor_targets(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE_DUNE duneFlavorOutputs
        OUTPUT_LIST_VARIABLE_FULL fullFlavorOutputs)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage2-DuneFlavor Package-${ARG_BUMP_LEVEL}-Stage1-VersionBump)

    # Stage 3
    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER POST_DUNE
        DEPENDS ${duneFlavorOutputs}
        OUTPUT_LIST_VARIABLE versionBumpPostDuneOutputs)
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage3-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${versionBumpPostDuneOutputs}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage3-VersionBump Package-${ARG_BUMP_LEVEL}-Stage2-DuneFlavor)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage4-FullFlavor Package-${ARG_BUMP_LEVEL}-Stage3-VersionBump)

    # Stage 5
    add_Api_target(BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE apiOutputs
        DEPENDS ${fullFlavorOutputs}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage5-Api Package-${ARG_BUMP_LEVEL}-Stage4-FullFlavor)

    # Stage 6
    get_bump_switch(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_SWITCH bumpSwitch
    )
    add_PackageUpgrade_target(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE packageUpgradeOutputs
        DEPENDS
        ${apiOutputs}
        ${bumpSwitch}/bin/common-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        ${bumpSwitch}/bin/package-ml-of-installer-generator${CMAKE_EXECUTABLE_SUFFIX}
        OPAMROOT ${anyrun_OPAMROOT}
        OPAMEXE ${anyrun_OPAMEXE})
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage6-PackageUpgrade Package-${ARG_BUMP_LEVEL}-Stage5-Api)

    # Stage 7
    add_Installer_target(BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE installerOutputs
        DEPENDS ${packageUpgradeOutputs}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage7-Installer Package-${ARG_BUMP_LEVEL}-Stage6-PackageUpgrade)

    # Stage 8
    add_RepositoryUpdate_target(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE repositoryUpdateOutputs
        DEPENDS ${installerOutputs})
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage8-RepositoryUpdate Package-${ARG_BUMP_LEVEL}-Stage7-Installer)

    # Stage 9. Both diskuv-opam-repository and self (dkml).
    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER FINAL
        DEPENDS ${installerOutputs} ${repositoryUpdateOutputs}
        OUTPUT_LIST_VARIABLE versionBumpFinalOutputs)
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage9-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${versionBumpFinalOutputs}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage9-VersionBump Package-${ARG_BUMP_LEVEL}-Stage8-RepositoryUpdate)

    # Last Stage
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/self/committed-${ARG_BUMP_LEVEL}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMAND ${GIT_EXECUTABLE} -c core.safecrlf=false add ${selfModifications}
        COMMAND ${GIT_EXECUTABLE} commit -m "Bump version: ${DKML_VERSION_SEMVER} -> ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}"
    )
    add_GitPush_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE gitPushTargetDepends
        INTENDED_TARGET ${STAGE_LAST_GIT_PUSH}
        DEPENDS
        ${versionBumpPreDuneOutputs} ${versionBumpPostDuneOutputs} ${versionBumpFinalOutputs}
        ${CMAKE_CURRENT_BINARY_DIR}/self/committed-${ARG_BUMP_LEVEL})
    add_custom_target(${STAGE_LAST_GIT_PUSH}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${gitPushTargetDepends}
        VERBATIM)
    add_dependencies(${STAGE_LAST_GIT_PUSH} Package-${ARG_BUMP_LEVEL}-Stage9-VersionBump)

    DkMLPublish_CreateReleaseTarget(
        TARGET Package-${ARG_BUMP_LEVEL}-CreateRelease
        DKML_VERSION_SEMVER_NEW ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
    )

    # add_dependencies(Package-${BUMP_LEVEL}-CreateRelease ${STAGE_LAST_GIT_PUSH})
    DkMLPublish_PublishAssetsTarget(
        TARGET Package-${ARG_BUMP_LEVEL}-PublishAssets
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        ARCHIVE_TARGET Package-Archive
        DKML_VERSION_SEMVER_NEW ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
    )
    add_dependencies(Package-${ARG_BUMP_LEVEL}-PublishAssets Package-${ARG_BUMP_LEVEL}-CreateRelease)
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
