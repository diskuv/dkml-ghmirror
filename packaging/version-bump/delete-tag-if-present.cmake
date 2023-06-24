# Deletes a tag if it is present.

if(NOT GIT_EXECUTABLE)
    message(FATAL_ERROR "Missing -D GIT_EXECUTABLE=xx")
endif()
if(NOT GIT_TAG_TO_DELETE)
    message(FATAL_ERROR "Missing -D GIT_TAG_TO_DELETE=xx")
endif()

execute_process(
    COMMAND ${GIT_EXECUTABLE} tag -d ${GIT_TAG_TO_DELETE}
    ERROR_QUIET
    OUTPUT_QUIET
    RESULT_VARIABLE failed
)

if(failed)
    # Not present
    return()
endif()

execute_process(
    COMMAND
    ${GIT_EXECUTABLE} push --delete origin ${GIT_TAG_TO_DELETE}
    COMMAND_ERROR_IS_FATAL ANY
)