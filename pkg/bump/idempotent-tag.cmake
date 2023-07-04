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

    # Failure examples?
    # > fatal: No annotated tags can describe '87d34d61e35085a84c34b5bc1e38ceba4245e7e9'
    # > However, there were unannotated tags: try --tags.
    # That is, no annotated tags are in project. And that is okay ...
    # we'll just continue and make our own.
    # So do not use: COMMAND_ERROR_IS_FATAL ANY
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