# ----------------------------------------------------------------
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification='The module is a set of variables',
    Target="AvailableOpamVersion")]
Param()

$DV_AvailableOpamVersion = "2.1.0.msys2.9" # needs to be a real Opam tag in https://github.com/diskuv/opam!
Export-ModuleMember -Variable DV_AvailableOpamVersion

# https://hub.docker.com/layers/ocaml/opam/windows-msvc-20H2-ocaml-4.12/images/sha256-e7b6e08cf22f6caed6599f801fbafbc32a93545e864b83ab42aedbd0d5835b55?context=explore
# Q: Why 20H2? Ans:
#    1. because it is a single kernel image so it is much smaller than multikernel `windows-msvc`
#    2. it is the latest as of 2021-08-05 so it will be a long time before that Windows kernel is no longer built;
#       would be nice if we could query https://github.com/avsm/ocaml-dockerfile/blob/ac54d3550159b0450032f0f6a996c2e96d3cafd7/src-opam/dockerfile_distro.ml#L36-L47
# NOTE: Do NOT move this definition out of this file without changing `.gitlab\ci\windows-package-ocaml-opam-repo.gitlab-ci.yml` which uses this
# file as a cache key to get an association with $DV_WindowsMsvcDockerImage
$DV_WindowsMsvcDockerImage = "ocaml/opam:windows-msvc-20H2-ocaml-4.12@sha256:e7b6e08cf22f6caed6599f801fbafbc32a93545e864b83ab42aedbd0d5835b55"
Export-ModuleMember -Variable DV_WindowsMsvcDockerImage
