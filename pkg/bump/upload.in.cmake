message(NOTICE "Uploading Generic Package @UPLOAD_DESTFILE@ @UPLOAD_VERSION@ to GitLab Package Registry at @GITLAB_UPLOAD_BASE_URL@. WARNING: If the release needs to be recreated, the Generic Package must be deleted and then re-published or else the GitLab may (randomly) use the old Generic Package during downloads")
file(UPLOAD @UPLOAD_SRCFILE@
    @GITLAB_UPLOAD_BASE_URL@/packages/generic/release/@UPLOAD_VERSION@/@UPLOAD_DESTFILE@
    HTTPHEADER "Authorization: Bearer @UPLOAD_TOKEN@"
)