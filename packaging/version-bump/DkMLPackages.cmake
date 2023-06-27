include_guard()

# Synchronized projects that have multiple opam packages
set(dkml-compiler_PACKAGES
    dkml-base-compiler
    dkml-compiler-env)
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