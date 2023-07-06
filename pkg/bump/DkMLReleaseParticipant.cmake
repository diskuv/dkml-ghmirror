if(NOT GIT_EXECUTABLE)
    message(FATAL_ERROR "Missing -D GIT_EXECUTABLE=xx")
endif()

# Applies a standard exclusion filter to the packages.
#
# Works with packages (base-bytes) or package-versions (base-bytes.4)
macro(_DkMLReleaseParticipant_NormalizePinnedPackages lst)
    foreach(_exclude_pkg IN ITEMS

        # Exclude packages bundled by the compiler like
        # [base-threads].
        base-bigarray
        base-bytes
        base-domains
        base-effects
        base-num
        base-threads
        base-unix
    )
        # Ex. list(FILTER ${lst} EXCLUDE REGEX "^base-bytes([.]|$)")
        # which matches "base-bytes" and "base-bytes.XXXX"
        list(FILTER ${lst} EXCLUDE REGEX "^${_exclude_pkg}([.]|$)")
    endforeach()
endmacro()

function(DkMLReleaseParticipant_DuneBuildOpamFiles)
    # Find *.opam files to rebuild
    file(
        GLOB opamFiles
        LIST_DIRECTORIES false
        RELATIVE ${CMAKE_CURRENT_BINARY_DIR}
        *.opam)

    if(IS_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/opam)
        # opam allows its .opam files to be in a opam/ subfolder
        file(
            GLOB opamFiles2
            LIST_DIRECTORIES false
            RELATIVE ${CMAKE_CURRENT_BINARY_DIR}
            opam/*.opam)
        list(APPEND opamFiles ${opamFiles2})
    endif()

    # Sort them
    list(SORT opamFiles)

    # Read them for a "before" snapshot
    foreach(opamFile IN LISTS opamFiles)
        file(READ ${opamFile} contents)
        string(REPLACE "\r" "" contents "${contents}") # Normalize CRLF
        string(MAKE_C_IDENTIFIER ${opamFile} opamFileId)
        set(contents_${opamFileId} "${contents}")
    endforeach()

    # Do a dune build to regenerate
    file(REMOVE _build/.lock)
    execute_process(
        COMMAND opam exec -- dune build ${opamFiles}
        COMMAND_ERROR_IS_FATAL ANY
    )

    # Which content changed, if any?
    set(changedOpamFiles)

    foreach(opamFile IN LISTS opamFiles)
        file(READ ${opamFile} contents)
        string(REPLACE "\r" "" contents "${contents}") # Normalize CRLF
        string(MAKE_C_IDENTIFIER ${opamFile} opamFileId)

        if(NOT(contents_${opamFileId} STREQUAL "${contents}"))
            list(APPEND changedOpamFiles ${opamFile})
        endif()
    endforeach()

    # Check idempotent
    if(NOT changedOpamFiles)
        # idempotent
        return()
    endif()

    list(JOIN changedOpamFiles " " changedOpamFiles_SPACES)
    message(NOTICE "Upgraded ${changedOpamFiles_SPACES}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${changedOpamFiles})
endfunction()
