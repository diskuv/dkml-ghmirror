set(DKML_RELEASE_OCAML_VERSION 4.14.0)
include(${PROJECT_SOURCE_DIR}/version.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLPackages.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLPatches.cmake)

if(CMAKE_HOST_WIN32)
    find_program(POWERSHELL_EXECUTABLE NAMES pwsh powershell REQUIRED)
endif()

find_program(GIT_EXECUTABLE NAMES git DOC "Git" REQUIRED)
set(BUMP2VERSION_EXECUTABLE "${CONDA_EXECUTABLE}" run -n "${CONDA_ENVIRONMENT}" --live-stream bump2version)

set(preProjects

    # These are the projects that are required to a) create a switch
    # with b) just an OCaml compiler. See note in [syncedProjects] about
    # [diskuv-opam-repository].
    dkml-compiler
    dkml-runtime-common
    dkml-runtime-distribution # contains create-opam-switch.sh

    # These are projects that aren't needed to build the compiler, but
    # a) need to be bumped and
    # b) are listed in a CI or Full distribution -pkgs.txt
    dkml-runtime-apps

    # These are projects that are not built in a switch. They are
    # utility projects and can be bumped whenever we want.
    dkml-workflows
)
set(syncedProjects
    ${preProjects}

    # Technically [diskuv-opam-repository] belongs in [preProjects],
    # however the repository must be updated after all the other
    # projects are updated (or else it can't get their checksums).
    # AFAIK this should not affect anything ... this VersionBump logic
    # uses pinning for all projects, so it is irrelevant if
    # [diskuv-opam-repository] is stale all the way until the end
    # of VersionBump.
    diskuv-opam-repository

    # All these others will be modified but aren't need to build the compiler
    # dkml-component-desktop
    # dkml-installer-ocaml
)
set(self_BRANCH next-cmake) # self is [dkml]
set(diskuv-opam-repository_BRANCH main)
set(dkml-compiler_BRANCH main)
set(dkml-runtime-common_BRANCH main)
set(dkml-runtime-distribution_BRANCH main)
set(dkml-component-desktop_BRANCH main)
set(dkml-installer-ocaml_BRANCH main)
set(dkml-runtime-apps_BRANCH main)

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

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(tar_ARGS)

    if(ARG_BUMP_LEVEL STREQUAL PRERELEASE)
        # Prereleases can always be overwritten, so force overwrite the git tag if present.
        list(APPEND tar_ARGS --force)
    endif()

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
    set(multiValues)
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

        add_custom_command(
            OUTPUT ${outputDir}/bumped-${ARG_BUMP_LEVEL}
            WORKING_DIRECTORY ${srcDir}
            DEPENDS ${newSemverFile}
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
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${outputDir}/bumped-${ARG_BUMP_LEVEL}
            VERBATIM
            USES_TERMINAL
        )
        list(APPEND retval ${outputDir}/bumped-${ARG_BUMP_LEVEL})
    endforeach()

    # Add to list
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
#   repeatable (ie. not hermetic).
set(fullNoDuneNoWithdkmlPkgVers ${FULL_NOT_DUNE_FLAVOR_PKGVERS})
list(FILTER fullNoDuneNoWithdkmlPkgVers EXCLUDE REGEX "^conf-withdkml[.]")
list(JOIN fullNoDuneNoWithdkmlPkgVers " " FULL_NOT_DUNE_FLAVOR_NO_WITHDKML_SPACED_PKGVERS)

# The OpamSwitch target creates the "dkml" switch.
#
# The target is responsible for creating the opam root,
# and the opam switch with FetchContent-synced versions of dkml-base-compiler
# (with its dependencies) and dkml-runtime-distribution-synced versions of
# the _full_ distribution.
# Among other things, the full distribution will have a working [dune] so
# that dkml-component-desktop (in later targets) can do [dune build *.opam] to
# update its own .opam files.
#
# This logic is similar as is performed by dkml-component-desktop, although
# only one switch is needed here. (Perhaps it is time to merge the logic?)
# See its README.md for how it works.
function(add_OpamSwitch_target)
    set(noValues)
    set(singleValues BUMP_LEVEL)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    FetchContent_GetProperties(dkml-workflows)

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(opamsw ${CMAKE_CURRENT_BINARY_DIR}/OpamSwitch/${ARG_BUMP_LEVEL})
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
        ${dkml-runtime-common_PACKAGES}
        dkml-runtime-distribution
        ${dkml-compiler_PACKAGES}
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

    file(MAKE_DIRECTORY ${opamsw})
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT
        ${opamsw}/.ci/sd4/opamrun/cmdrun
        ${opamsw}/.ci/sd4/opamrun/opamrun
        ${setupAdditionalOutput}
        COMMENT "Creating ${ARG_BUMP_LEVEL} [cmdrun] script"
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
    FetchContent_GetProperties(dkml-compiler) # Used by upsert-dkml-pkgs-compiler
    FetchContent_GetProperties(dkml-runtime-common) # Used by upsert-dkml-pkgs-compiler
    FetchContent_GetProperties(dkml-runtime-distribution) # Used in DKML_ROOT_DIR (create-switch.sh and init-opam-root.sh)
    FetchContent_GetProperties(dkml-runtime-apps) # Used by upsert-dkml-pkgs-flavor-full-not-dune
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-dkmlroot ${DKML_ROOT_DIR}/.dkmlroot

        # Needed by create-opam-switch.sh and init-opam-root.sh
        COMMAND "${CMAKE_COMMAND}" -E copy_directory ${dkml-runtime-common_SOURCE_DIR} ${DKML_ROOT_DIR}/vendor/drc

        # Needed by create-opam-switch.sh
        COMMAND "${CMAKE_COMMAND}" -E copy_directory ${dkml-runtime-distribution_SOURCE_DIR} ${DKML_ROOT_DIR}/vendor/drd
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(DISKUV_OPAM_REPOSITORY_NAME_NEW diskuv-${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}})

    foreach(p IN ITEMS anyrun upsert-dkml-switch upsert-dkml-pkgs-compiler upsert-dkml-pkgs-flavor-dune upsert-dkml-pkgs-flavor-full-not-dune)
        configure_file(${p}.in.sh ${opamsw}/${p}.sh
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY NEWLINE_STYLE UNIX)
    endforeach()

    anyrun(${opamsw}/upsert-dkml-switch.sh upsert_dkml_switch_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-compiler.sh upsert_dkml_pkgs_compiler_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-flavor-dune.sh upsert_dkml_pkgs_dune_COMMAND)
    anyrun(${opamsw}/upsert-dkml-pkgs-flavor-full-not-dune.sh upsert_dkml_pkgs_full_not_dune_COMMAND)
    set(switchCreated ${opamsw}/switch.created)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        # There is no file within a switch that gets updated when and only when
        # the switch is created. Some timestamps (like switch-config) are
        # updated frequently for unrelated opam commands, and some timestamps
        # (like environment) are rarely updated.
        # So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch_nocreate] command.
        OUTPUT ${switchCreated}
        BYPRODUCTS
        ${opamsw}/.ci/o/dkml/.opam-switch/switch-config
        ${opamsw}/.ci/o/dkml/.opam-switch/environment
        MAIN_DEPENDENCY upsert-dkml-switch.in.sh
        DEPENDS
        ${opamsw}/.ci/sd4/opamrun/cmdrun
        ${setupAdditionalOutput}
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} [dkml] opam switch"

        # We don't make a separate CMake command for creating the opam root
        # because there is no good way (in CMake) to tell if the opam root
        # has been completed successfully. The best is checking whether the
        # repositories exist, but opam may at its own discretion use a .tar.gz
        # rather than a directory for its copy of the repository.
        COMMAND ${upsert_dkml_switch_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${switchCreated}
        VERBATIM
        USES_TERMINAL
    )
    set(compilerCreated ${opamsw}/compiler.created)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        # Compiler binaries often do not have timestamps updated due to
        # opam seeing no changes. So we use a synthetic OUTPUT, real BYPRODUCTS,
        # and a [touch_nocreate] command.
        OUTPUT ${compilerCreated}
        BYPRODUCTS ${opamsw}/.ci/o/dkml/bin/ocamlopt.opt${CMAKE_EXECUTABLE_SUFFIX}
        MAIN_DEPENDENCY upsert-dkml-pkgs-compiler.in.sh
        DEPENDS
        ${switchCreated}
        ${dkml-runtime-common_SOURCE_DIR}/dkml-runtime-common-native.opam
        ${dkml-compiler_SOURCE_DIR}/dkml-base-compiler.opam
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} [dkml] compiler"
        COMMAND ${upsert_dkml_pkgs_compiler_COMMAND}
        COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${compilerCreated}
        VERBATIM
        USES_TERMINAL
    )
    set(duneFlavorOutput ${DUNE_FLAVOR_PKGS})
    list(TRANSFORM duneFlavorOutput PREPEND "${opamsw}/.ci/o/dkml/lib/" OUTPUT_VARIABLE duneFlavorOutput)
    list(TRANSFORM duneFlavorOutput APPEND "/META" OUTPUT_VARIABLE duneFlavorOutput)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${duneFlavorOutput}
        MAIN_DEPENDENCY upsert-dkml-pkgs-flavor-dune.in.sh
        DEPENDS ${compilerCreated}
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} [dkml] distribution - Dune flavor"
        COMMAND ${upsert_dkml_pkgs_dune_COMMAND}
        VERBATIM
        USES_TERMINAL
    )
    set(fullFlavorOutput ${FULL_NOT_DUNE_FLAVOR_PKGS})
    list(TRANSFORM fullFlavorOutput PREPEND "${opamsw}/.ci/o/dkml/lib/" OUTPUT_VARIABLE fullFlavorOutput)
    list(TRANSFORM fullFlavorOutput APPEND "/META" OUTPUT_VARIABLE fullFlavorOutput)
    add_custom_command(
        WORKING_DIRECTORY ${opamsw}
        OUTPUT ${fullFlavorOutput}
        MAIN_DEPENDENCY upsert-dkml-pkgs-flavor-full-not-dune.in.sh
        DEPENDS ${duneFlavorOutput}
        COMMENT "Creating/updating ${ARG_BUMP_LEVEL} [dkml] distribution - Full flavor"
        COMMAND ${upsert_dkml_pkgs_full_not_dune_COMMAND}
        VERBATIM
        USES_TERMINAL
    )

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage2-OpamSwitch
        DEPENDS ${fullFlavorOutput}
        VERBATIM
    )
endfunction()

function(add_all_targets)
    set(noValues)
    set(singleValues BUMP_LEVEL)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(newSemverFile ${CMAKE_CURRENT_BINARY_DIR}/new-${ARG_BUMP_LEVEL}-semver)
    set(selfModifications)
    set(INTENDED_TARGET_GIT_PUSH Package-${ARG_BUMP_LEVEL}-Stage4-GitPush)

    if(ARG_BUMP_LEVEL STREQUAL "PRERELEASE")
        # PRERELEASE bump
        stage_self_VersionReplace(${ARG_BUMP_LEVEL}
            ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}

            # No change to the public version
            ${DKML_PUBLICVERSION_CMAKEVER}
            selfModifications version.cmake)
    else()
        # PATCH, MINOR or MAJOR bump
        stage_self_VersionReplace(${ARG_BUMP_LEVEL}
            ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            ${DKML_VERSION_CMAKEVER_NEW_${ARG_BUMP_LEVEL}}
            selfModifications version.cmake)
        stage_self_DkMLReplace(${ARG_BUMP_LEVEL}
            ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            selfModifications README.md)
        stage_self_Changes(${ARG_BUMP_LEVEL}
            ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}
            selfModifications)
    endif()

    set(selfOutput ${CMAKE_CURRENT_BINARY_DIR}/self)
    add_custom_command(
        OUTPUT ${selfOutput}/bumped-${ARG_BUMP_LEVEL}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_BINARY_DIR}/_replace/${ARG_BUMP_LEVEL} .
        COMMAND ${GIT_EXECUTABLE} -c core.safecrlf=false add ${selfModifications}
        COMMAND ${GIT_EXECUTABLE} commit -m "Bump version: ${DKML_VERSION_SEMVER} -> ${DKML_VERSION_SEMVER_NEW_${ARG_BUMP_LEVEL}}"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${newSemverFile} ${selfOutput}/bumped-${ARG_BUMP_LEVEL}
        VERBATIM)
    add_GitPush_command(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        SOURCE_DIR ${PROJECT_SOURCE_DIR}
        CONTEXT self
        BRANCH ${self_BRANCH}
        INTENDED_TARGET ${INTENDED_TARGET_GIT_PUSH}
        OUTPUT_FILE ${selfOutput}/pushed-${ARG_BUMP_LEVEL}
        DEPENDS ${selfOutput}/bumped-${ARG_BUMP_LEVEL})

    set(versionBumpPreTargetDepends)
    set(versionBumpPostTargetDepends ${selfOutput}/tagged-${ARG_BUMP_LEVEL})
    set(gitPushTargetDepends ${selfOutput}/pushed-${ARG_BUMP_LEVEL})

    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER PRE
        OUTPUT_LIST_VARIABLE versionBumpPreTargetDepends)
    add_VersionBump_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        FILTER POST
        OUTPUT_LIST_VARIABLE versionBumpPostTargetDepends)
    add_GitPush_commands_for_synced_projects(
        BUMP_LEVEL ${ARG_BUMP_LEVEL}
        OUTPUT_LIST_VARIABLE gitPushTargetDepends
        INTENDED_TARGET ${INTENDED_TARGET_GIT_PUSH}
        DEPENDS ${versionBumpPreTargetDepends} ${versionBumpPostTargetDepends})

    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage1-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${versionBumpPreTargetDepends}
        VERBATIM)
    add_OpamSwitch_target(BUMP_LEVEL ${ARG_BUMP_LEVEL})
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage2-OpamSwitch Package-${ARG_BUMP_LEVEL}-Stage1-VersionBump)
    add_custom_target(Package-${ARG_BUMP_LEVEL}-Stage3-VersionBump
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${versionBumpPostTargetDepends}
        VERBATIM)
    add_dependencies(Package-${ARG_BUMP_LEVEL}-Stage3-VersionBump Package-${ARG_BUMP_LEVEL}-Stage2-OpamSwitch)
    add_custom_target(${INTENDED_TARGET_GIT_PUSH}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${newSemverFile} ${gitPushTargetDepends}
        VERBATIM)
    add_dependencies(${INTENDED_TARGET_GIT_PUSH} Package-${ARG_BUMP_LEVEL}-Stage3-VersionBump)
endfunction()

add_all_targets(BUMP_LEVEL PRERELEASE)
add_all_targets(BUMP_LEVEL PATCH)

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