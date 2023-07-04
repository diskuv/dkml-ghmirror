message(NOTICE "Uploading Generic Package @UPLOAD_DESTFILE@ to GitLab Package Registry")
file(UPLOAD @UPLOAD_SRCFILE@
    https://gitlab.com/api/v4/projects/diskuv%2Fdiskuv-ocaml/packages/generic/release/@UPLOAD_VERSION@/@UPLOAD_DESTFILE@
    HTTPHEADER "Authorization: Bearer @UPLOAD_TOKEN@"
)