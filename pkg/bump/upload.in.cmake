message(NOTICE "Uploading Generic Package @UPLOAD_DESTFILE@ to GitLab Package Registry")
file(UPLOAD @UPLOAD_SRCFILE@
    @GITLAB_UPLOAD_BASE_URL@/packages/generic/release/@UPLOAD_VERSION@/@UPLOAD_DESTFILE@
    HTTPHEADER "Authorization: Bearer @UPLOAD_TOKEN@"
)