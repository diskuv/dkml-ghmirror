message(NOTICE "Uploading Generic Package @UPLOAD_DESTFILE@ @UPLOAD_VERSION@ to GitLab Package Registry at @GITLAB_UPLOAD_BASE_URL@. WARNING: If the release needs to be recreated, the Generic Package must be deleted and then re-published or else the GitLab may (randomly) use the old Generic Package during downloads")

# Get token
execute_process(COMMAND "@GLAB_EXECUTABLE@" auth status --show-token
    ERROR_VARIABLE auth_STATUS
    COMMAND_ERROR_IS_FATAL ANY)
if(auth_STATUS MATCHES [[Token: ([0-9a-f]+)]])
    set(auth_TOKEN ${CMAKE_MATCH_1})
else()
    message(FATAL_ERROR "No 'Token: ...' line found in:\n\n${auth_STATUS}")
endif()

file(UPLOAD @UPLOAD_SRCFILE@
    "@GITLAB_UPLOAD_BASE_URL@/packages/generic/release/@UPLOAD_VERSION@/@UPLOAD_DESTFILE@?select=package_file"
    HTTPHEADER "Authorization: Bearer ${auth_TOKEN}"
    STATUS upload_STATUS
    SHOW_PROGRESS
)
#   upload_STATUS[0] = return value
list(GET upload_STATUS 0 upload_RETVAL)
if(upload_RETVAL EQUAL 0)
    message(STATUS "Uploaded Generic Package @UPLOAD_DESTFILE@ @UPLOAD_VERSION@.")
else()
    message(FATAL_ERROR "The Generic Package @UPLOAD_DESTFILE@ @UPLOAD_VERSION@ upload failed: ${upload_STATUS}")
endif()
