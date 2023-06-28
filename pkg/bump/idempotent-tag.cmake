if(NOT GIT_EXECUTABLE OR NOT BUMP_LEVEL OR
    NOT DKML_VERSION_SEMVER_NEW OR NOT DKML_VERSION_OPAMVER_NEW)
    message(FATAL_ERROR "Invalid idempotent-tag.cmake arguments")
endif()

set(tar_ARGS)

if(BUMP_LEVEL STREQUAL PRERELEASE)
    # Prereleases can always be overwritten, so force overwrite the git tag if present.
    list(APPEND tar_ARGS --force)
endif()

# Does not re-tag in PRERELEASE when the tag is already on HEAD.
# Relies on prior annotated tag ([git tag -a]) so that [git describe] works.
execute_process(
    COMMAND ${GIT_EXECUTABLE} describe
    OUTPUT_STRIP_TRAILING_WHITESPACE
    OUTPUT_VARIABLE possibleTag
    COMMAND_ERROR_IS_FATAL ANY
)

if(possibleTag STREQUAL ${DKML_VERSION_SEMVER_NEW})
    # Nothing to do. HEAD is already the desired tag
    return()
endif()

execute_process(
    COMMAND
    ${GIT_EXECUTABLE} tag ${tar_ARGS} -a ${DKML_VERSION_SEMVER_NEW} -m ${DKML_VERSION_OPAMVER_NEW}
    COMMAND_ERROR_IS_FATAL ANY
)