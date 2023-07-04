include_guard()

set(ARCHIVEDIR ${CMAKE_CURRENT_BINARY_DIR}/archives)

# These packages do not have a META file, or not consistently for all package versions
set(PACKAGES_WITHOUT_META
    conf-withdkml
    ocaml
    ocamlfind
)

set(DKML_PROJECTS_PREDUNE

    # These are the projects that are required to a) create a switch
    # with b) just an OCaml compiler. See note in [syncedProjects] about
    # [diskuv-opam-repository].
    dkml-compiler
    dkml-runtime-common
    dkml-runtime-distribution # contains create-opam-switch.sh
)
set(DKML_PROJECTS_POSTDUNE

    # These are projects that need [dune build *.opam] to bump their
    # versions.

    # Part of a CI or Full distribution -pkgs.txt
    dkml-runtime-apps

    # Install utility projects.
    # They are bumped therefore they should be built (they are built as part
    # of the Api target). Regardless, they are transitive dependencies
    # of many DkML projects.
    dkml-workflows

    # Install API Components
    dkml-component-desktop
    dkml-component-ocamlcompiler
    dkml-component-ocamlrun
    dkml-installer-ocaml
)
set(DKML_PROJECTS_FINAL

    # Technically [diskuv-opam-repository] belongs in [DKML_PROJECTS_PREDUNE],
    # however the repository must be updated after all the other
    # projects are updated (or else it can't get their checksums).
    # AFAIK this should not affect anything ... this pkg/bump/CMakeLists.txt
    # script uses pinning for all projects, so it is irrelevant if
    # [diskuv-opam-repository] is stale all the way until the end
    # of VersionBump.
    diskuv-opam-repository
)

# Synchronized projects with their one or more opam packages
set(dkml-compiler_PACKAGES
    dkml-base-compiler
    dkml-compiler-env

    # dkml-compiler-maintain
    dkml-compiler-src)
set(dkml-runtime-apps_PACKAGES
    dkml-apps
    dkml-exe
    dkml-exe-lib
    dkml-runtimelib
    dkml-runtimescripts
    opam-dkml
    with-dkml)
set(dkml-runtime-common_PACKAGES
    dkml-runtime-common
    dkml-runtime-common-native)
set(dkml-runtime-distribution_PACKAGES dkml-runtime-distribution)
set(dkml-workflows_PACKAGES dkml-workflows)
set(dkml-component-desktop_PACKAGES
    dkml-build-desktop
    dkml-component-common-desktop

    # dkml-component-desktop-maintain
    dkml-component-offline-desktop-ci
    dkml-component-offline-desktop-full
    dkml-component-staging-desktop-ci
    dkml-component-staging-desktop-full
    dkml-component-staging-dkmlconfdir
    dkml-component-staging-withdkml)
set(dkml-component-ocamlcompiler_PACKAGES
    dkml-component-network-ocamlcompiler)
set(dkml-component-ocamlrun_PACKAGES
    dkml-component-offline-ocamlrun
    dkml-component-staging-ocamlrun)
set(dkml-installer-ocaml_PACKAGES
    dkml-installer-network-ocaml)

# Sanity check
foreach(PROJECT IN LISTS DKML_PROJECTS_PREDUNE DKML_PROJECTS_POSTDUNE)
    if(NOT ${PROJECT}_PACKAGES)
        message(FATAL_ERROR "Missing set(${PROJECT}_PACKAGES ...) statement in ${CMAKE_CURRENT_LIST_FILE}")
    endif()
endforeach()

# Dune has multiple packages that varies depending on the Dune version
function(get_dune_PACKAGES)
    set(noValues)
    set(singleValues DUNE_VERSION OUTPUT_VARIABLE)
    set(multiValues)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    set(${ARG_OUTPUT_VARIABLE}
        chrome-trace
        dune
        dune-action-plugin
        dune-build-info
        dune-configurator
        dune-glob
        dune-private-libs
        dune-rpc
        dune-rpc-lwt
        dune-site
        dyn
        ocamlc-loc
        ordering
        stdune
        xdg
        PARENT_SCOPE)
endfunction()