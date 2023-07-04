include(${CMAKE_CURRENT_LIST_DIR}/DkMLPackages.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLAnyRun.cmake)

set(PUBLISHDIR ${CMAKE_CURRENT_BINARY_DIR}/publish)

set(glab_HINTS)

if(IS_DIRECTORY Z:/ProgramFiles/glab)
    list(APPEND glab_HINTS Z:/ProgramFiles/glab)
endif()

find_program(GLAB_EXECUTABLE glab
    REQUIRED HINTS ${glab_HINTS})

function(DkMLPublish_ChangeLog)
    set(noValues)
    set(singleValues DKML_VERSION_SEMVER_NEW OUTPUT_VARIABLE)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    string(REPLACE "." ";" VERSION_LIST ${ARG_DKML_VERSION_SEMVER_NEW})
    string(REPLACE "-" ";" VERSION_LIST "${VERSION_LIST}")
    list(GET VERSION_LIST 0 DKML_VERSION_MAJOR_NEW)
    list(GET VERSION_LIST 1 DKML_VERSION_MINOR_NEW)
    list(GET VERSION_LIST 2 DKML_VERSION_PATCH_NEW)
    set(changes_MD ${PROJECT_SOURCE_DIR}/contributors/changes/v${DKML_VERSION_MAJOR_NEW}.${DKML_VERSION_MINOR_NEW}.${DKML_VERSION_PATCH_NEW}.md)

    if(NOT EXISTS ${changes_MD})
        message(FATAL_ERROR "Missing changelog at ${changes_MD}")
    endif()

    set(${ARG_OUTPUT_VARIABLE} ${changes_MD} PARENT_SCOPE)
endfunction()

function(DkMLPublish_AddArchiveTarget)
    set(noValues)
    set(singleValues TARGET)
    set(multiValues PROJECTS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    file(MAKE_DIRECTORY ${ARCHIVEDIR})

    set(outputs)

    foreach(pkg IN ITEMS ${ARG_PROJECTS})
        FetchContent_GetProperties(${pkg})
        execute_process(
            WORKING_DIRECTORY ${${pkg}_SOURCE_DIR}
            COMMAND ${GIT_EXECUTABLE} ls-tree -r HEAD --name-only
            OUTPUT_VARIABLE files
            OUTPUT_STRIP_TRAILING_WHITESPACE
            COMMAND_ERROR_IS_FATAL ANY
        )
        set(git_ls_tree ${CMAKE_CURRENT_BINARY_DIR}/git-ls-tree/${pkg}.txt)
        file(WRITE ${git_ls_tree} "${files}")
        string(REPLACE "\n" ";" absfiles "${files}")
        list(TRANSFORM absfiles PREPEND ${${pkg}_SOURCE_DIR}/)
        set(output ${ARCHIVEDIR}/src.${pkg}.tar.gz)
        add_custom_command(
            WORKING_DIRECTORY ${${pkg}_SOURCE_DIR}
            OUTPUT ${output}
            DEPENDS ${absfiles}

            # Verify no dirty tracked files in working tree. The
            # source archive must correspond exactly to a clean git checkout.
            # https://unix.stackexchange.com/a/394674
            COMMAND
            ${GIT_EXECUTABLE} update-index --really-refresh
            COMMAND
            ${GIT_EXECUTABLE} diff-index --quiet HEAD

            # Create tarball
            COMMAND
            ${CMAKE_COMMAND} -E tar cfz
            ${output}
            --format=gnutar
            --files-from=${git_ls_tree}
        )
        list(APPEND outputs ${output})
    endforeach()

    add_custom_target(${ARG_TARGET}
        DEPENDS ${outputs}
    )
endfunction()

function(DkMLPublish_CreateReleaseTarget)
    set(noValues)
    set(singleValues DKML_VERSION_SEMVER_NEW TARGET)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    # Get ChangeLog entry
    DkMLPublish_ChangeLog(
        DKML_VERSION_SEMVER_NEW ${ARG_DKML_VERSION_SEMVER_NEW}
        OUTPUT_VARIABLE changes_MD)
    file(READ ${changes_MD} changes_CONTENT)
    string(TIMESTAMP now_YYYYMMDD "%Y-%m-%d")
    string(REPLACE "@@YYYYMMDD@@" "${now_YYYYMMDD}" changes_CONTENT "${changes_CONTENT}")
    file(WRITE ${PUBLISHDIR}/change-${ARG_DKML_VERSION_SEMVER_NEW}.md)

    add_custom_target(${ARG_TARGET}
        DEPENDS ${PUBLISHDIR}/change-${ARG_DKML_VERSION_SEMVER_NEW}.md
        COMMAND
        ${GLAB_EXECUTABLE} auth status

        # https://gitlab.com/gitlab-org/cli/-/blob/main/docs/source/release/create.md
        COMMAND
        ${GLAB_EXECUTABLE} release create ${ARG_DKML_VERSION_SEMVER_NEW}
        --name "DkML ${ARG_DKML_VERSION_SEMVER_NEW}"
        --ref "${ARG_DKML_VERSION_SEMVER_NEW}"
        --notes-file ${PUBLISHDIR}/change.md
        VERBATIM USES_TERMINAL
    )
endfunction()

function(DkMLPublish_PublishAssetsTarget)
    set(noValues)
    set(singleValues BUMP_LEVEL DKML_VERSION_SEMVER_NEW TARGET ARCHIVE_TARGET)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    # NOTICE
    # ------
    #
    # By using a stable "file path" in the [uploads] list, we can make
    # a stable permalink. So do NOT change the file paths unless it is
    # absolutely necessary (perhaps only for security invalidation).
    # Confer:
    # https://docs.gitlab.com/ee/user/project/releases/release_fields.html#permanent-links-to-latest-release-assets
    set(precommands)
    set(uploads)
    set(depends)

    if(CMAKE_HOST_WIN32)
        list(APPEND precommands
            COMMAND
            ${CMAKE_COMMAND} -E copy_if_different
            ${tdir}/unsigned-diskuv-ocaml-windows_x86_64-i-${ARG_DKML_VERSION_SEMVER_NEW}.exe
            ${ARCHIVEDIR}/setup64.exe

            COMMAND
            ${CMAKE_COMMAND} -E copy_if_different
            ${tdir}/unsigned-diskuv-ocaml-windows_x86_64-u-${ARG_DKML_VERSION_SEMVER_NEW}.exe
            ${ARCHIVEDIR}/uninstall64.exe
        )
        list(APPEND uploads
            "setup64.exe#Windows 64-bit Installer"
            "uninstall64.exe#Windows 64-bit Uninstaller"
        )
        list(APPEND depends
            ${tdir}/unsigned-diskuv-ocaml-windows_x86_64-i-${ARG_DKML_VERSION_SEMVER_NEW}.exe
            ${tdir}/unsigned-diskuv-ocaml-windows_x86_64-u-${ARG_DKML_VERSION_SEMVER_NEW}.exe)
    endif()

    # https://gitlab.com/gitlab-org/cli/-/blob/main/docs/source/release/upload.md
    foreach(PROJECT IN LISTS DKML_PROJECTS_PREDUNE DKML_PROJECTS_POSTDUNE)
        list(APPEND uploads "src.${PROJECT}.tar.gz#${PROJECT} Source Code")
        list(APPEND depends ${ARCHIVEDIR}/src.${PROJECT}.tar.gz)
    endforeach()

    set(tdir ${anyrun_OPAMROOT}/${ARG_BUMP_LEVEL}/share/dkml-installer-network-ocaml/t)
    add_custom_target(${ARG_TARGET}
        WORKING_DIRECTORY ${ARCHIVEDIR}
        DEPENDS ${depends}
        COMMAND
        ${GLAB_EXECUTABLE} auth status

        ${precommands}

        COMMAND
        ${GLAB_EXECUTABLE} release upload ${ARG_DKML_VERSION_SEMVER_NEW}
        "${uploads}"
        VERBATIM USES_TERMINAL
    )
    add_dependencies(${ARG_TARGET} ${ARG_ARCHIVE_TARGET})
endfunction()
