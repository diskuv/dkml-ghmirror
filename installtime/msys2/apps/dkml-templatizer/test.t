Given template
  $ cat >template.in <<EOF
  > The path in Unix is {{DiskuvOCamlHome_Unix}}!
  > EOF

When dkml-templatizer Then template filled in
  $ DiskuvOCamlHome=/opt/testing/dkml-templatizer dkml-templatizer -q template.in
  The path in Unix is /opt/testing/dkml-templatizer!
  
