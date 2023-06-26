set(DKML_RELEASE_OCAML_VERSION 4.14.0)
include(${PROJECT_SOURCE_DIR}/version.cmake)

if(CMAKE_HOST_WIN32)
    find_program(POWERSHELL_EXECUTABLE NAMES pwsh powershell REQUIRED)
endif()

find_program(GIT_EXECUTABLE NAMES git DOC "Git" REQUIRED)
set(BUMP2VERSION_EXECUTABLE "${CONDA_EXECUTABLE}" run -n "${CONDA_ENVIRONMENT}" --live-stream bump2version)

set(preProjects

    # These are the projects that are required to build an OCaml
    # compiler in a new switch
    diskuv-opam-repository
    dkml-compiler
    dkml-runtime-common
    dkml-runtime-distribution
)
set(syncedProjects
    ${preProjects}

    # dkml-component-desktop
    # dkml-installer-ocaml
    # dkml-runtime-apps
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
file(CONFIGURE OUTPUT new-PRERELEASE-dkmlroot CONTENT "dkml_root_version=@DKML_VERSION_SEMVER_NEW_PRERELEASE@" @ONLY NEWLINE_STYLE UNIX)
file(CONFIGURE OUTPUT new-PATCH-dkmlroot CONTENT "dkml_root_version=@DKML_VERSION_SEMVER_NEW_PATCH@" @ONLY NEWLINE_STYLE UNIX)

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
    set(singleValues BUMP_LEVEL FILTER OUTPUT_LIST_VARIABLE)
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

        if(ARG_FILTER STREQUAL PRE)
            if(NOT(proj IN_LIST preProjects))
                continue()
            endif()
            string(APPEND outputDir /PRE)
        elseif(ARG_FILTER STREQUAL POST)
            if(proj IN_LIST preProjects)
                continue()
            endif()
            string(APPEND outputDir /POST)
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

# The OpamSwitch target create two switches:
#
# 1. The "dkml" switch which has their own compiler and DKML repository; we
# don't try to sync its compilers + repository with the ones we FetchContent
# from in CMake. Those non-synced compilers and repositories are only used for
# initial build of OpamSwitch target; subsequent CMake targets will
# add pins (ex. dkml-base-compiler) and repository
# (ex. our FetchContent diskuv-opam-repository) and rebuild the
# switch as necessary. *Yes, that is wasteful, but presently setup-dkml does
# not support local pinning. More importantly, we won't have a chicken-and-egg
# problem ... dkml-component-desktop needs a working [dune build *.opam] to
# update its own .opam files. Using a stable, unsynced dkml switch lets us do
# that*.
# 2. The "two" switch has the tools like [dkml-runtime-distribution] that
# can introspect and figure out which packages need to be installed in "dkml".
# The "two" switch will have local pins to [dkml-runtime-common] and
# [dkml-runtime-distribution].
#
# This logic is the same performed by dkml-component-desktop. See its README.md
# for how it works.
function(add_OpamSwitch_target BUMP_LEVEL)
    FetchContent_GetProperties(dkml-workflows)

    set(opamsw ${CMAKE_CURRENT_BINARY_DIR}/OpamSwitch/${BUMP_LEVEL})
    set(setupAdditionalOutput)

    function(anyrun SCRIPT OUTVAR)
        set(${OUTVAR} "${opamsw}/anyrun.sh" ${SCRIPT} PARENT_SCOPE)
    endfunction()

    if(CMAKE_HOST_WIN32)
        set(DKML_HOST_ABI windows_x86_64)
        set(setupScript "${POWERSHELL_EXECUTABLE}" "${dkml-workflows_SOURCE_DIR}/test/pc/setup-dkml-windows_x86_64.ps1")
        list(APPEND setupAdditionalOutput ${opamsw}/msys64/usr/bin/bash.exe)

        function(anyrun SCRIPT OUTVAR)
            # [build] Finished setup.
            # [build]
            # [build] To continue your testing, run in PowerShell:
            # [build]   $env:CHERE_INVOKING = "yes"
            # [build]   $env:MSYSTEM = "CLANG64"
            # [build]   $env:dkml_host_abi = "windows_x86_64"
            # [build]   $env:abi_pattern = "win32-windows_x86_64"
            # [build]   $env:opam_root = "Z:/source/dkml/build/packaging/version-bump/opamsw/.ci/o"
            # [build]   $env:exe_ext = ".exe"
            set(${OUTVAR}
                ${CMAKE_COMMAND} -E env CHERE_INVOKING=yes MSYSTEM=CLANG64 MSYS2_ARG_CONV_EXCL=*
                "${opamsw}/msys64/usr/bin/bash.exe" -l "${opamsw}/anyrun.sh" "${SCRIPT}"
                PARENT_SCOPE)
        endfunction()
    elseif(CMAKE_HOST_APPLE)
        set(DKML_HOST_ABI darwin_x86_64)
        set(setupScript "${dkml-workflows_SOURCE_DIR}/test/pc/setup-dkml-darwin_x86_64.ps1")
    else()
        set(DKML_HOST_ABI linux_x86_64)
        set(setupScript "${dkml-workflows_SOURCE_DIR}/test/pc/setup-dkml-linux_x86_64.ps1")
    endif()

    file(MAKE_DIRECTORY ${opamsw})
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT
        ${opamsw}/.ci/sd4/opamrun/cmdrun
        ${opamsw}/.ci/sd4/opamrun/opamrun
        ${setupAdditionalOutput}
        COMMENT "Creating ${BUMP_LEVEL} [cmdrun] script"
        COMMAND
        ${setupScript}
        -PC_PROJECT_DIR "${opamsw}"

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

    set(DKML_ROOT_DIR ${opamsw}/dkmldir)
    cmake_path(GET GIT_EXECUTABLE PARENT_PATH GIT_EXECUTABLE_DIR)
    FetchContent_GetProperties(diskuv-opam-repository) # Used by upsert-dkml-switch
    FetchContent_GetProperties(dkml-compiler) # Used by upsert-dkml-pkgs-core
    FetchContent_GetProperties(dkml-runtime-common)
    FetchContent_GetProperties(dkml-runtime-distribution)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-dkmlroot ${DKML_ROOT_DIR}/.dkmlroot

        # Needed by create-opam-switch.sh and init-opam-root.sh
        COMMAND "${CMAKE_COMMAND}" -E copy_directory ${dkml-runtime-common_SOURCE_DIR} ${DKML_ROOT_DIR}/vendor/drc

        # Needed by create-opam-switch.sh
        COMMAND "${CMAKE_COMMAND}" -E copy_directory ${dkml-runtime-distribution_SOURCE_DIR} ${DKML_ROOT_DIR}/vendor/drd
        COMMAND_ERROR_IS_FATAL ANY
    )

    foreach(p IN ITEMS anyrun upsert-dkml-switch upsert-dkml-pkgs-core)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-dkml-switch.sh upsert_dkml_switch_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-core.sh upsert_dkml_pkgs_core_COMMAND)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${opamsw}/.ci/o/dkml/.opam-switch/switch-config
        DEPENDS
        ${opamsw}/.ci/sd4/opamrun/cmdrun
        ${setupAdditionalOutput}
        COMMENT "Creating/updating ${BUMP_LEVEL} [dkml] opam switch"

        # We don't make a separate CMake command for creating the opam root
        # because there is no good way (in CMake) to tell if the opam root
        # has been completed successfully. The best is checking whether the
        # repositories exist, but opam may at its own discretion use a .tar.gz
        # rather than a directory for its copy of the repository.
        COMMAND ${upsert_dkml_switch_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${opamsw}/.ci/o/dkml/bin/ocamlc${CMAKE_EXECUTABLE_SUFFIX}
        DEPENDS ${opamsw}/.ci/o/dkml/.opam-switch/switch-config
        COMMENT "Creating/updating ${BUMP_LEVEL} [dkml] compiler"
        COMMAND ${upsert_dkml_pkgs_core_COMMAND}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-${BUMP_LEVEL}-Stage2-OpamSwitch
        DEPENDS ${opamsw}/.ci/o/dkml/bin/ocamlc${CMAKE_EXECUTABLE_SUFFIX}
        VERBATIM
    )
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

    set(versionBumpPreTargetDepends)
    set(versionBumpPostTargetDepends ${CMAKE_CURRENT_BINARY_DIR}/self/tagged-${BUMP_LEVEL})
    set(gitPushTargetDepends ${CMAKE_CURRENT_BINARY_DIR}/self/pushed-${BUMP_LEVEL})

    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${BUMP_LEVEL}
        FILTER PRE
        OUTPUT_LIST_VARIABLE versionBumpPreTargetDepends)
    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${BUMP_LEVEL}
        FILTER POST
        OUTPUT_LIST_VARIABLE versionBumpPostTargetDepends)
    add_GitPush_commands_for_synced_projects(
        BUMP_LEVEL ${BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE gitPushTargetDepends
        DEPENDS ${versionBumpPreTargetDepends} ${versionBumpPostTargetDepends})

    add_custom_target(Package-${BUMP_LEVEL}-Stage1-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver ${versionBumpPreTargetDepends}
        VERBATIM)
    add_OpamSwitch_target(${BUMP_LEVEL})
    add_dependencies(Package-${BUMP_LEVEL}-Stage2-OpamSwitch Package-${BUMP_LEVEL}-Stage1-VersionBump)
    add_custom_target(Package-${BUMP_LEVEL}-Stage3-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver ${versionBumpPostTargetDepends}
        VERBATIM)
    add_dependencies(Package-${BUMP_LEVEL}-Stage3-VersionBump Package-${BUMP_LEVEL}-Stage2-OpamSwitch)
    add_custom_target(Package-${BUMP_LEVEL}-Stage4-GitPush
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/new-${BUMP_LEVEL}-semver ${gitPushTargetDepends}
        VERBATIM)
    add_dependencies(Package-${BUMP_LEVEL}-Stage4-GitPush Package-${BUMP_LEVEL}-Stage3-VersionBump)
endfunction()

add_all_targets(PRERELEASE)
add_all_targets(PATCH)

# TODO:

# 0. {DONE} Save the [git push] of all the synced projects until step [2] and [3] are done.

# 1. [diskuv-opam-repository] should get updates. Needs to push and then wait for a SHA256.

# 2. [release.sh] starting from line ~450 changes [dkml-component-desktop] and
# waits for it to build. The release.sh changes are all to get the code we already checked
# out, and are complicated because release.sh does not let [dune] autogenerate
# all the .opam files. So we run [dune] and add the changed .opam files!
# * However, we'll need to download a version of dune (easy).
# * We'll need to create an opam switch to build [dkml-component-desktop] ... just
# use [setup-dkml] desktop scripts to do that. Actually, can just use
# [dkml-component-desktop] .gitlab-ci.yml (just run the ci/ scripts manually).
#
# In fact, have [dkml-component-desktop]'s new [bump-version.cmake] script
# run immediately parts of [gather.sh] and [build-test.sh] so that a
# new dkml-component-staging-desktop-full.opam can be generated with all
# the required .opam (essentially from dkml-runtime-distribution). You can use
# dkml-component-opam dependency so you can run [opam] inside a [build:]
# command. You'll need that to do [opam show --list-files] to feed into
# [dkml-desktop-copy-installed] as part of your new [install:] commands.
#
# The new [bump-version.cmake] script will need to be supplied with
# the locations of dkml-runtime-common and dkml-runtime-distribution (or better
# yet, do a FetchContent which can be overridden on the command line or within
# this version-bump/CMakeLists.txt script).
#
# Net effect is no -prep needed (although the lack of a binary asset may
# lengthen the time for dkml-installer-ocaml). Perhaps use OCaml-CI, but at
# first just create the -prep tag and build it.

# 3. Build [dkml-installer-ocaml]

# 4. Do [git push] of all synced projects _and_ [self]