include_guard()
include(${CMAKE_CURRENT_LIST_DIR}/DkMLPackages.cmake)

set(DKML_PATCH_EXCLUDE_PACKAGES

    # Already fixed upstream. Eligible to be removed
    # from diskuv-opam-repository! Only reason to keep it around is for
    # packages that require older versions
    cmdliner # 1.0.4    
    ptime # 0.8.6-msvcsupport
)

# Get the list of the latest package versions compatible with
# [OCAML_VERSION]. Any packages that are part of [SYNCHRONIZED_PACKAGES]
# will be reported as version [DKML_VERSION_OPAMVER_NEW]
# because the expectation is that those will be pinned during
# the CMake bump/ targets.
function(DkMLPatches_GetPackageVersions)
    set(noValues)
    set(singleValues DUNE_VERSION OCAML_VERSION DKML_VERSION_OPAMVER_NEW OUTPUT_VARIABLE)
    set(multiValues SYNCHRONIZED_PACKAGES EXCLUDE_PACKAGES)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${noValues}" "${singleValues}" "${multiValues}")

    FetchContent_GetProperties(diskuv-opam-repository)
    file(GLOB packages
        LIST_DIRECTORIES true
        CONFIGURE_DEPENDS
        ${diskuv-opam-repository_SOURCE_DIR}/packages/*)
    set(pkgvers)

    foreach(pkgdir IN LISTS packages)
        cmake_path(GET pkgdir FILENAME pkgname)

        if(pkgname IN_LIST DKML_PATCH_EXCLUDE_PACKAGES OR pkgname IN_LIST ARG_EXCLUDE_PACKAGES)
            continue()
        elseif(pkgname IN_LIST ARG_SYNCHRONIZED_PACKAGES)
            # Ex. dkml-runtimelib, with-dkml
            list(APPEND pkgvers ${pkgname}.${ARG_DKML_VERSION_OPAMVER_NEW})
        elseif("dkml-compiler" IN_LIST ARG_SYNCHRONIZED_PACKAGES AND pkgname IN_LIST dkml-compiler_PACKAGES)
            list(APPEND pkgvers ${pkgname}.${ARG_DKML_VERSION_OPAMVER_NEW})
        elseif("dkml-runtime-apps" IN_LIST ARG_SYNCHRONIZED_PACKAGES AND pkgname IN_LIST dkml-runtime-apps_PACKAGES)
            list(APPEND pkgvers ${pkgname}.${ARG_DKML_VERSION_OPAMVER_NEW})
        elseif("dkml-runtime-common" IN_LIST ARG_SYNCHRONIZED_PACKAGES AND pkgname IN_LIST dkml-runtime-common_PACKAGES)
            list(APPEND pkgvers ${pkgname}.${ARG_DKML_VERSION_OPAMVER_NEW})
        elseif(pkgname STREQUAL "dkml-base-compiler")
            list(APPEND dkml-base-compiler.${ARG_OCAML_VERSION}~v${ARG_DKML_VERSION_OPAMVER_NEW})
        elseif(pkgname STREQUAL "ocaml" OR pkgname STREQUAL "conf-dkml-cross-toolchain")
            list(APPEND ${pkgname}.${ARG_OCAML_VERSION})
        elseif(pkgname STREQUAL "dune" OR pkgname MATCHES "^dune-.*" OR
            pkgname STREQUAL "dyn" OR pkgname STREQUAL "fiber" OR
            pkgname STREQUAL "ordering" OR pkgname STREQUAL "stdune" OR pkgname STREQUAL "xdg")
            list(APPEND pkgvers ${pkgname}.${ARG_DUNE_VERSION})
        else()
            # "Naturally" sort the package versions so we can find the latest
            # version. Yep, this is not done 100% correctly, but you can always
            # override a mistaken package version in this script.
            file(GLOB current_pkgvers
                LIST_DIRECTORIES true
                RELATIVE ${pkgdir}
                CONFIGURE_DEPENDS
                ${pkgdir}/${pkgname}.*)
            list(SORT current_pkgvers COMPARE NATURAL CASE INSENSITIVE ORDER DESCENDING)
            list(GET current_pkgvers 0 latest_pkgver)
            list(APPEND pkgvers ${latest_pkgver})
        endif()
    endforeach()

    set(${ARG_OUTPUT_VARIABLE} ${pkgvers} PARENT_SCOPE)
endfunction()