include(${CMAKE_CURRENT_LIST_DIR}/fetch-git-projects.cmake)

FetchContent_MakeAvailable(
    diskuv-opam-repository
    dkml-compiler
    dkml-component-desktop
    dkml-component-ocamlcompiler
    dkml-component-ocamlrun
    dkml-component-opam
    dkml-component-unixutils
    dkml-install-api
    dkml-installer-ocaml
    dkml-runtime-apps
    dkml-runtime-common
    dkml-runtime-distribution
    dkml-workflows
)
