include(${CMAKE_CURRENT_LIST_DIR}/DkMLPackages.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLAnyRun.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLBumpLevels.cmake)

set(PUBLISHDIR ${CMAKE_CURRENT_BINARY_DIR}/Publish)

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
    set(changes_MD_NEW_FILENAME ${PUBLISHDIR}/change-${ARG_DKML_VERSION_SEMVER_NEW}.md)
    DkMLPublish_ChangeLog(
        DKML_VERSION_SEMVER_NEW ${ARG_DKML_VERSION_SEMVER_NEW}
        OUTPUT_VARIABLE changes_MD)
    file(READ ${changes_MD} changes_CONTENT)
    string(TIMESTAMP now_YYYYMMDD "%Y-%m-%d")
    string(REPLACE "@@YYYYMMDD@@" "${now_YYYYMMDD}" changes_CONTENT "${changes_CONTENT}")
    file(WRITE ${changes_MD_NEW_FILENAME} ${changes_CONTENT})

    add_custom_target(${ARG_TARGET}
        DEPENDS ${changes_MD_NEW_FILENAME}
        COMMAND
        ${GLAB_EXECUTABLE} auth status

        # https://gitlab.com/gitlab-org/cli/-/blob/main/docs/source/release/create.md
        COMMAND
        ${GLAB_EXECUTABLE} release create ${ARG_DKML_VERSION_SEMVER_NEW}
        --name "DkML ${ARG_DKML_VERSION_SEMVER_NEW}"
        --ref "${ARG_DKML_VERSION_SEMVER_NEW}"
        --notes-file ${changes_MD_NEW_FILENAME}
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
    set(uploads) # Files at most 100MB
    set(assetlinks) # References to 5GB Generic Packages
    set(depends)

    shorten_bump_level(BUMP_LEVEL ${ARG_BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)
    set(tdir ${anyrun_OPAMROOT}/${SHORT_BUMP_LEVEL}/share/dkml-installer-network-ocaml/t)

    # Procedure
    # ---------
    # 1. Upload to Generic Package Registry because it can support 5GB uploads.
    # https://docs.gitlab.com/ee/user/gitlab_com/index.html#account-and-limit-settings
    # 2. Create a release pointing to Generic Package (rather than a normal release
    # attachment which only supports 100MB)
    # Only do that somewhat convoluted step for big installers ... the source
    # archives can be "normal" release attachments.

    # Get GitLab private token
    execute_process(
        COMMAND ${GLAB_EXECUTABLE} auth status -t
        ERROR_VARIABLE AUTH_LINE
        COMMAND_ERROR_IS_FATAL ANY
    )
    string(REGEX MATCH "Token: [0-9a-h]+" GITLAB_PRIVATE_TOKEN "${AUTH_LINE}")
    string(REPLACE "Token: " "" GITLAB_PRIVATE_TOKEN "${GITLAB_PRIVATE_TOKEN}")

    macro(_handle_upload SRCFILE DESTFILE NAME)
        set(UPLOAD_SRCFILE "${SRCFILE}")
        set(UPLOAD_VERSION "${ARG_DKML_VERSION_SEMVER_NEW}")
        set(UPLOAD_DESTFILE "${DESTFILE}")
        set(UPLOAD_TOKEN "${GITLAB_PRIVATE_TOKEN}")
        configure_file(upload.in.cmake ${PUBLISHDIR}/${ARG_BUMP_LEVEL}/upload-${DESTFILE}.cmake
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY)
        list(APPEND depends ${UPLOAD_SRCFILE})
        list(APPEND assetlinks "{\"name\": \"${NAME}\", \"url\":\"https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/release/${UPLOAD_VERSION}/${UPLOAD_DESTFILE}\", \"link_type\": \"other\", \"filepath\": \"${DESTFILE}\"}")
        list(APPEND precommands
            COMMAND ${CMAKE_COMMAND} -P ${PUBLISHDIR}/${ARG_BUMP_LEVEL}/upload-${DESTFILE}.cmake)
    endmacro()

    if(DKML_TARGET_ABI STREQUAL windows_x86 OR DKML_TARGET_ABI STREQUAL windows_x86_64)
        _handle_upload(
            ${tdir}/unsigned-diskuv-ocaml-${DKML_TARGET_ABI}-i-${ARG_DKML_VERSION_SEMVER_NEW}.exe
            setup64u-exe
            "Windows 64-bit Installer")
        _handle_upload(
            ${tdir}/unsigned-diskuv-ocaml-${DKML_TARGET_ABI}-u-${ARG_DKML_VERSION_SEMVER_NEW}.exe
            uninstall64u-exe
            "Windows 64-bit Uninstaller")
    endif()

    if(assetlinks)
        list(JOIN assetlinks "," assetlinks_csv)
        list(APPEND precommands
            COMMAND
            ${GLAB_EXECUTABLE} release upload ${ARG_DKML_VERSION_SEMVER_NEW}
            --assets-links=[${assetlinks_csv}]
        )
    endif()

    # https://gitlab.com/gitlab-org/cli/-/blob/main/docs/source/release/upload.md
    foreach(PROJECT IN LISTS DKML_PROJECTS_PREDUNE DKML_PROJECTS_POSTDUNE)
        list(APPEND uploads "src.${PROJECT}.tar.gz#${PROJECT} Source Code")
        list(APPEND depends ${ARCHIVEDIR}/src.${PROJECT}.tar.gz)
    endforeach()

    add_custom_target(${ARG_TARGET}
        WORKING_DIRECTORY ${ARCHIVEDIR}
        DEPENDS ${depends}

        ${precommands}

        COMMAND
        ${GLAB_EXECUTABLE} release upload ${ARG_DKML_VERSION_SEMVER_NEW}
        "${uploads}"
        VERBATIM USES_TERMINAL
    )
    add_dependencies(${ARG_TARGET} ${ARG_ARCHIVE_TARGET})
endfunction()
