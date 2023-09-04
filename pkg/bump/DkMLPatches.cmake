include_guard()

cmake_policy(SET CMP0057 NEW) # Support new ``if()`` IN_LIST operator.

include(${CMAKE_CURRENT_LIST_DIR}/DkMLPackages.cmake)

set(DKML_PATCH_EXCLUDE_PACKAGES

    # Note: +android patches aren't useful in DkML

    # Renamed and/or deprecated packages
    dkml-installer-network-ocaml # 2.0.1

    # Already fixed upstream. Eligible to be removed
    # from diskuv-opam-repository! Only reason to keep it around is for
    # packages that require older versions
    alcotest # 1.6.0
    bigstringaf # 0.9.0+msvc
    checkseum # 0.3.4+android
    cmdliner # 1.0.4
    crunch # 3.3.1
    curly # 0.2.1-windows-env_r2
    digestif # 1.1.2+msvc
    ptime # 0.8.6-msvcsupport
    utop # 2.13.0+win32

    # -- Jane Street --
    base # v0.15.1
    base_bigstring # v0.15.0
    core # v0.15.1
    core_kernel # v0.15.0
    ppx_expect # v0.15.1
    spawn # 0.15.1+android
    time_now # v0.15.0
)

# Do GLOBs once
FetchContent_GetProperties(diskuv-opam-repository)
file(GLOB_RECURSE diskuv-opam-repository-PACKAGEGLOB
    LIST_DIRECTORIES true
    RELATIVE ${diskuv-opam-repository_SOURCE_DIR}

    CONFIGURE_DEPENDS
    ${diskuv-opam-repository_SOURCE_DIR}/packages/*/*/opam)

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

    set(pkgdirs)
    foreach(pkgopam IN LISTS diskuv-opam-repository-PACKAGEGLOB)
        cmake_path(GET pkgopam PARENT_PATH pkgverdir)
        cmake_path(GET pkgverdir PARENT_PATH pkgdir)
        list(APPEND pkgdirs "${pkgdir}")
    endforeach()

    set(pkgvers)
    foreach(pkgdir IN LISTS pkgdirs)
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
        elseif(pkgname IN_LIST DKML_COMPILER_DKML_VERSIONED_PACKAGES)
            list(APPEND ${pkgname}.${ARG_OCAML_VERSION}~v${ARG_DKML_VERSION_OPAMVER_NEW})
        elseif(pkgname STREQUAL "ocaml" OR pkgname IN_LIST DKML_COMPILER_VERSIONED_PACKAGES)
            list(APPEND ${pkgname}.${ARG_OCAML_VERSION})
        elseif(pkgname STREQUAL "dune")
            # Always select the given dune X.Y.Z version, so we can flip back
            # and forth from dune.X.Y.Z+shim and dune.X.Y.Z in diskuv-opam-repository
            # depending on the presence of [conf-withdkml] in our [dkml] switch.
            list(APPEND pkgvers dune.${ARG_DUNE_VERSION})
        elseif(pkgname MATCHES "^dune-.*" OR
            pkgname STREQUAL "dyn" OR pkgname STREQUAL "fiber" OR
            pkgname STREQUAL "ordering" OR pkgname STREQUAL "stdune" OR pkgname STREQUAL "xdg")
            # diskuv-opam-repository patches for Dune-related packages are only
            # needed when the core Dune package is 3.6.2
            if(ARG_DUNE_VERSION VERSION_EQUAL 3.6.2)
                list(APPEND pkgvers ${pkgname}.${ARG_DUNE_VERSION})
            endif()
        else()
            # "Naturally" sort the package versions so we can find the latest
            # version. Yep, this is not done 100% correctly, but you can always
            # override a mistaken package version in this script.
            set(current_pkgvers)
            foreach(pkgopam IN LISTS diskuv-opam-repository-PACKAGEGLOB)
                cmake_path(IS_PREFIX pkgdir "${pkgopam}" in_subdir)
                if(in_subdir)
                    cmake_path(GET pkgopam PARENT_PATH pkgverdir)
                    cmake_path(GET pkgverdir FILENAME pkgver)
                    list(APPEND current_pkgvers "${pkgver}")
                endif()
            endforeach()
            list(SORT current_pkgvers COMPARE NATURAL CASE INSENSITIVE ORDER DESCENDING)
            list(GET current_pkgvers 0 latest_pkgver)
            list(APPEND pkgvers ${latest_pkgver})
        endif()
    endforeach()

    set(${ARG_OUTPUT_VARIABLE} ${pkgvers} PARENT_SCOPE)
endfunction()