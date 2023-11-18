include(${CMAKE_CURRENT_LIST_DIR}/DkMLPackages.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLAnyRun.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/DkMLBumpLevels.cmake)

# Aka. https://gitlab.com/dkml/distributions/dkml
set(GITLAB_UPLOAD_BASE_URL https://gitlab.com/api/v4/projects/dkml%2Fdistributions%2Fdkml)
set(PUBLISHDIR ${CMAKE_CURRENT_BINARY_DIR}/${DKML_VERSION_CMAKEVER}/publish)

set(glab_HINTS)

if(IS_DIRECTORY Z:/ProgramFiles/glab)
    list(APPEND glab_HINTS Z:/ProgramFiles/glab)
endif()

find_program(GLAB_EXECUTABLE glab
    REQUIRED HINTS ${glab_HINTS})

function(DkMLPublish_ChangeLog)
    set(noValues)
    set(singleValues OUTPUT_VARIABLE)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    # There is no prerelease change.md, so use patch change.md
    set(changes_MD ${PROJECT_SOURCE_DIR}/contributors/changes/v${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${DKML_VERSION_PATCH}.md)

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

    # We use a stable timestamp so the tarball is somewhat reproducible
    # (at least on the same machine). We want to minimize SHA checksums
    # changing.
    #
    # configure_file() does not change the mtime if the expanded
    # contents (ARG_PROJECTS) don't change
    set(SORTED_PROJECTS ${ARG_PROJECTS})
    list(SORT SORTED_PROJECTS)
    configure_file(archive.in.mtime ${ARCHIVEDIR}/archive-${ARG_TARGET}.mtime @ONLY)
    file(TIMESTAMP ${ARCHIVEDIR}/archive-${ARG_TARGET}.mtime mtime_YYYYMMDD "%Y-%m-%d" UTC)

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

            # --mtime format is not documented. Use https://gitlab.kitware.com/cmake/cmake/-/blob/master/Tests/RunCMake/CommandLineTar/mtime-tests.cmake
            --mtime=${mtime_YYYYMMDD}UTC
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
    set(singleValues TARGET)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    # Get ChangeLog entry
    set(changes_MD_NEW_FILENAME ${PUBLISHDIR}/change.md)
    DkMLPublish_ChangeLog(OUTPUT_VARIABLE changes_MD)
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
        ${GLAB_EXECUTABLE} release create ${DKML_VERSION_SEMVER}
        --name "DkML ${DKML_VERSION_SEMVER}"
        --ref "${DKML_VERSION_SEMVER}"
        --notes-file ${changes_MD_NEW_FILENAME}

        # There seems to be an eventual consistency issue with GitLab as of 2023-09. If
        # we create the release above, and then the next second upload the Generic Package
        # for that version, no Generic Package will be uploaded.
        COMMAND
        ${CMAKE_COMMAND} -E sleep 30

        VERBATIM USES_TERMINAL
    )
endfunction()

function(DkMLPublish_PublishAssetsTarget)
    set(noValues)
    set(singleValues TARGET ARCHIVE_TARGET)
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
    set(postcommands)
    set(uploads) # Files at most 100MB
    set(assetlinks) # References to 5GB Generic Packages
    set(depends)

    set(tnetwork ${anyrun_OPAMROOT}/${DKML_VERSION_CMAKEVER}/share/dkml-installer-ocaml-network/t)
    set(toffline ${anyrun_OPAMROOT}/${DKML_VERSION_CMAKEVER}/share/dkml-installer-ocaml-offline/t)

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

    macro(_handle_upload LINKTYPE SRCFILE DESTFILE NAME)
        # LINKTYPE: https://docs.gitlab.com/ee/user/project/releases/release_fields.html#link-types
        set(UPLOAD_SRCFILE "${SRCFILE}")
        set(UPLOAD_VERSION "${DKML_VERSION_SEMVER}")
        set(UPLOAD_DESTFILE "${DESTFILE}")
        set(UPLOAD_TOKEN "${GITLAB_PRIVATE_TOKEN}")
        configure_file(upload.in.cmake ${PUBLISHDIR}/upload-${DESTFILE}.cmake
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
            @ONLY)
        list(APPEND depends ${UPLOAD_SRCFILE})
        list(APPEND assetlinks "{\"name\": \"${NAME}\", \"url\":\"${GITLAB_UPLOAD_BASE_URL}/packages/generic/release/${UPLOAD_VERSION}/${UPLOAD_DESTFILE}\", \"filepath\": \"/${DESTFILE}\", \"linktype\": \"${LINKTYPE}\"}")
        list(APPEND precommands
            COMMAND ${CMAKE_COMMAND} -P ${PUBLISHDIR}/upload-${DESTFILE}.cmake)
    endmacro()

    if(DKML_TARGET_ABI STREQUAL windows_x86 OR DKML_TARGET_ABI STREQUAL windows_x86_64)
        # The reverse order of insertion shows up on GitLab UI. Want installer to display
        # first, so _handle_upload(<installer>) last.
        _handle_upload(package
            ${tnetwork}/unsigned-dkml-native-${DKML_TARGET_ABI}-u-${DKML_VERSION_SEMVER}.exe
            uninstall64nu.exe
            "Windows 64-bit Native Uninstaller (unsigned)")
        _handle_upload(package
            ${tnetwork}/unsigned-dkml-native-${DKML_TARGET_ABI}-i-${DKML_VERSION_SEMVER}.exe
            setup64nu.exe
            "Windows 64-bit Native Installer (unsigned)")
        _handle_upload(package
            ${toffline}/unsigned-dkml-byte-${DKML_TARGET_ABI}-u-${DKML_VERSION_SEMVER}.exe
            uninstall64bu.exe
            "Windows 64-bit Lite Bytecode Uninstaller (unsigned)")
        _handle_upload(package
            ${toffline}/unsigned-dkml-byte-${DKML_TARGET_ABI}-i-${DKML_VERSION_SEMVER}.exe
            setup64bu.exe
            "Windows 64-bit Lite Bytecode Installer (unsigned)")
    endif()

    if(assetlinks)
        list(JOIN assetlinks "," assetlinks_csv)

        list(APPEND postcommands
            COMMAND
            ${GLAB_EXECUTABLE} release upload ${DKML_VERSION_SEMVER}
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
        ${GLAB_EXECUTABLE} release upload ${DKML_VERSION_SEMVER}
        ${uploads}

        ${postcommands}

        VERBATIM USES_TERMINAL
    )
    add_dependencies(${ARG_TARGET} ${ARG_ARCHIVE_TARGET})
endfunction()
