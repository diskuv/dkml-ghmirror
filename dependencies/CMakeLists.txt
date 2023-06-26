include(${CMAKE_CURRENT_LIST_DIR}/fetch-git-projects.cmake)

FetchContent_MakeAvailable(
    diskuv-opam-repository
    dkml-compiler
    dkml-component-desktop
    dkml-installer-ocaml
    dkml-runtime-apps
    dkml-runtime-common
    dkml-runtime-distribution
    dkml-workflows
)
