include(${CMAKE_CURRENT_LIST_DIR}/DkMLReleaseParticipant_core.cmake)

if(NOT DKML_RELEASE_DUNE_VERSION)
    message(FATAL_ERROR "Missing -D DKML_RELEASE_DUNE_VERSION=xx")
endif()
if(NOT OPAM_EXECUTABLE)
    message(FATAL_ERROR "Missing -D OPAM_EXECUTABLE=xx")
endif()

# Sets a printer of a "pinned" opam section of [switch-state]. Similar to:
#
# echo '
# pinned: [
# "0install.2.17"
# "dkml-base-compiler.4.14.0~v1.2.1~prerel10"
# "dkml-compiler-env.1.2.1~prerel10"
# ]
# '
function(DkMLBumpPackagesParticipant_CreateOpamSwitchUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of package versions.
    # Example:
    # variantslib.v0.15.0
    # with-dkml.1.2.1~prerel10
    execute_process(
        COMMAND ${OPAM_EXECUTABLE} list --columns=package --short
        OUTPUT_VARIABLE pkgvers
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )

    # Convert to list
    string(REGEX REPLACE "\n" ";" pkgvers "${pkgvers}")
    _DkMLReleaseParticipant_NormalizePinnedPackages(pkgvers)

    # Remove [dune] and replace with [dune+shim]
    list(FILTER pkgvers EXCLUDE REGEX "^dune[.]")
    list(APPEND pkgvers "dune.${DKML_RELEASE_DUNE_VERSION}+shim")

    # Sort
    list(SORT pkgvers)

    # Convert to list of quoted strings.
    list(TRANSFORM pkgvers PREPEND "  \"")
    list(TRANSFORM pkgvers APPEND "\"")
    list(JOIN pkgvers "\n" pkgvers)

    # Make a shell script printer
    cmake_path(GET CMAKE_CURRENT_LIST_FILE FILENAME managerFile)
    string(REGEX REPLACE
        [[### BEGIN pinned-section.*### END pinned-section[. A-Za-z]*]]
        "### BEGIN pinned-section. DO NOT EDIT THE LINES IN THIS SECTION
# Managed by ${managerFile}
echo 'pinned: [
${pkgvers}
]
'
### END pinned-section. DO NOT EDIT THE LINES ABOVE"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Upgraded [pinned:] opam section in ${REL_FILENAME}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# Sets a series of commands like:
# opamrun pin add --switch "$do_pins_NAME"  --yes --no-action -k version alcotest "${PIN_ALCOTEST}"
function(DkMLBumpPackagesParticipant_SetupDkmlUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of packages.
    # Example:
    # variantslib
    # with-dkml
    execute_process(
        COMMAND ${OPAM_EXECUTABLE} list --short
        OUTPUT_VARIABLE pkgs
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )

    # Convert to list
    string(REGEX REPLACE "\n" ";" pkgs "${pkgs}")
    _DkMLReleaseParticipant_NormalizePinnedPackages(pkgs)

    # Sort
    list(SORT pkgs)

    # ocp-indent -> ocp-indent "${PIN_OCP_INDENT}"
    set(pkgs2)

    foreach(pkg IN LISTS pkgs)
        string(TOUPPER "${pkg}" PKG_UPPER_UNDERSCORE)
        string(REPLACE "-" "_" PKG_UPPER_UNDERSCORE "${PKG_UPPER_UNDERSCORE}")
        list(APPEND pkgs2 "${pkg} \"\${PIN_${PKG_UPPER_UNDERSCORE}}\"")
    endforeach()

    set(pkgs ${pkgs2})

    # Convert to list of commands
    list(TRANSFORM pkgs PREPEND [[    opamrun pin add --switch "$do_pins_NAME"  --yes --no-action -k version ]])
    list(JOIN pkgs "\n" pkgs)

    # Set the command
    cmake_path(GET CMAKE_CURRENT_LIST_FILE FILENAME managerFile)
    string(REGEX REPLACE
        [[### BEGIN pin-adds.*### END pin-adds[. A-Za-z]*]]
        "### BEGIN pin-adds. DO NOT EDIT THE LINES IN THIS SECTION
    # Managed by ${managerFile}
${pkgs}
    ### END pin-adds. DO NOT EDIT THE LINES ABOVE"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Upgraded [pin add] commands in ${REL_FILENAME}")
    set_property(GLOBAL APPEND PROPERTY DkMLBumpPackagesParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# Sets a series of OCaml list elements like:
# ("PIN_ALCOTEST", "1.6.0");
# ("PIN_ALCOTEST_ASYNC", "1.6.0");
function(DkMLBumpPackagesParticipant_ModelUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of packages.
    # Example:
    # variantslib.1.2.3
    # with-dkml.4.5.6
    execute_process(
        COMMAND ${OPAM_EXECUTABLE} list --columns=package --short
        OUTPUT_VARIABLE pkgvers
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )

    # Convert to list
    string(REGEX REPLACE "\n" ";" pkgvers "${pkgvers}")
    _DkMLReleaseParticipant_NormalizePinnedPackages(pkgvers)

    # Sort
    list(SORT pkgvers)

    # ocp-indent.1.2.3 -> ("PIN_OCP_INDENT", "1.2.3");
    set(bindings)

    foreach(pkgver IN LISTS pkgvers)
        string(FIND "${pkgver}" "." dotLoc)
        string(SUBSTRING "${pkgver}" 0 ${dotLoc} pkg)
        math(EXPR dotLocPlus1 "${dotLoc} + 1")
        string(SUBSTRING "${pkgver}" ${dotLocPlus1} -1 ver)
        string(TOUPPER "${pkg}" PKG_UPPER_UNDERSCORE)
        string(REPLACE "-" "_" PKG_UPPER_UNDERSCORE "${PKG_UPPER_UNDERSCORE}")
        string(APPEND bindings "\n    (\"PIN_${PKG_UPPER_UNDERSCORE}\", \"${ver}\");")
    endforeach()

    # Set the command
    cmake_path(GET CMAKE_CURRENT_LIST_FILE FILENAME managerFile)
    string(REGEX REPLACE
        [[\(\* BEGIN pin-env-vars.*END pin-env-vars[^*]* \*\)]]
        "(* BEGIN pin-env-vars. DO NOT EDIT THE LINES IN THIS SECTION *)
    (* Managed by ${managerFile} *)${bindings}
    (* END pin-env-vars. DO NOT EDIT THE LINES ABOVE *)"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Upgraded pin environment bindings in ${REL_FILENAME}")
    set_property(GLOBAL APPEND PROPERTY DkMLBumpPackagesParticipant_REL_FILES ${REL_FILENAME})
endfunction()

function(DkMLBumpPackagesParticipant_DuneProjectFlavorUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    foreach(FLAVOR IN ITEMS ci full)
        # Get list of [global-install] package versions for the flavor
        # Example:
        # with-dkml.1.2.1~prerel10
        execute_process(
            COMMAND ${OPAM_EXECUTABLE} exec -- dkml-desktop-gen-global-install ${FLAVOR} package-versions
            OUTPUT_VARIABLE pkgvers
            OUTPUT_STRIP_TRAILING_WHITESPACE
            COMMAND_ERROR_IS_FATAL ANY
        )

        # Convert to list
        string(REGEX REPLACE "\n" ";" pkgvers "${pkgvers}")
        _DkMLReleaseParticipant_NormalizePinnedPackages(pkgvers)

        # Remove [dune] and replace with [dune+shim]
        list(FILTER pkgvers EXCLUDE REGEX "^dune[.]")
        list(APPEND pkgvers "dune.${DKML_RELEASE_DUNE_VERSION}+shim")

        # Sort
        list(SORT pkgvers)

        # Convert to list of (PKGNAME (= PKGVER)) strings.
        list(TRANSFORM pkgvers REPLACE "([^.]*)[.](.*)" "  (\\1 (= \\2))")
        list(JOIN pkgvers "\n" pkgvers)

        # Make a dune-project section
        cmake_path(GET CMAKE_CURRENT_LIST_FILE FILENAME managerFile)
        string(REGEX REPLACE
            "; BEGIN flavor-${FLAVOR}[.].*; END flavor-${FLAVOR}[. A-Za-z]*"
            "; BEGIN flavor-${FLAVOR}. DO NOT EDIT THE LINES IN THIS SECTION
  ; Managed by ${managerFile}
${pkgvers}
  ; END flavor-${FLAVOR}. DO NOT EDIT THE LINES ABOVE"
            contents_NEW "${contents_NEW}")
    endforeach()

    if(contents STREQUAL "${contents_NEW}")
        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Upgraded [flavor-*] packages in ${REL_FILENAME}")
    set_property(GLOBAL APPEND PROPERTY DkMLBumpPackagesParticipant_REL_FILES ${REL_FILENAME})
endfunction()

function(DkMLBumpPackagesParticipant_DkmlFlavorOpamUpgrade REL_FILENAME FLAVOR)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of [global-install] packages for the flavor
    # Example:
    # with-dkml.1.2.1~prerel10
    execute_process(
        COMMAND ${OPAM_EXECUTABLE} exec -- dkml-desktop-gen-global-install ${FLAVOR} packages
        OUTPUT_VARIABLE pkgs
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )

    # Convert to list
    string(REGEX REPLACE "\n" ";" pkgs "${pkgs}")
    _DkMLReleaseParticipant_NormalizePinnedPackages(pkgs)

    # Sort
    list(SORT pkgs)

    # Make a list of:
    # [ "sh" "-c" "opam show --list-files dkml-apps > opamshow-dkml-apps.txt" ]
    set(buildspec ${pkgs})

    # Want REPLACE ".*", but nasty cmake bug:
    # https://gitlab.kitware.com/cmake/cmake/-/issues/18884 https://gitlab.kitware.com/cmake/cmake/-/issues/16899
    list(TRANSFORM buildspec REPLACE "[A-Za-z0-9_-]+" [==[  [ "sh" "-c" "opam show --list-files \0 > opamshow-\0.txt" ]]==])
    list(JOIN buildspec "\n" buildspec)

    # Make a list of:
    # [ "dkml-desktop-copy-installed" "--file-list" "opamshow-dkml-apps.txt" "--output-dir" "%{_:share}%/staging-files/%{dkml-abi}%" ]
    set(installspec ${pkgs})
    list(TRANSFORM installspec REPLACE "[A-Za-z0-9_-]+" [==[  [ "dkml-desktop-copy-installed" "--file-list" "opamshow-\0.txt" "--output-dir" "%{_:share}%/staging-files/%{dkml-abi}%" ]]==])
    list(JOIN installspec "\n" installspec)

    cmake_path(GET CMAKE_CURRENT_LIST_FILE FILENAME managerFile)

    # Replace build: section
    string(REGEX REPLACE
        "# BEGIN build-flavor-${FLAVOR}[.].*# END build-flavor-${FLAVOR}[. A-Za-z]*"
        "# BEGIN build-flavor-${FLAVOR}. DO NOT EDIT THE LINES IN THIS SECTION
  # Managed by ${managerFile}. TODO: Use [opam] from dkml-component-opam
${buildspec}
  # END build-flavor-${FLAVOR}. DO NOT EDIT THE LINES ABOVE"
        contents_NEW "${contents_NEW}")

    # Replace install: section
    string(REGEX REPLACE
        "# BEGIN install-flavor-${FLAVOR}[.].*# END install-flavor-${FLAVOR}[. A-Za-z]*"
        "# BEGIN install-flavor-${FLAVOR}. DO NOT EDIT THE LINES IN THIS SECTION
  # Managed by ${managerFile}
${installspec}
  # END install-flavor-${FLAVOR}. DO NOT EDIT THE LINES ABOVE"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Upgraded [build:] and [install:] sections in ${REL_FILENAME}")
    set_property(GLOBAL APPEND PROPERTY DkMLBumpPackagesParticipant_REL_FILES ${REL_FILENAME})
endfunction()

function(DkMLBumpPackagesParticipant_GitAddAndCommit)
    if(DRYRUN)
        return()
    endif()

    get_property(relFiles GLOBAL PROPERTY DkMLReleaseParticipant_REL_FILES)

    if(NOT relFiles)
        return()
    endif()

    execute_process(
        COMMAND
        ${GIT_EXECUTABLE} -c core.safecrlf=false add ${relFiles}
        COMMAND_ERROR_IS_FATAL ANY
    )
    execute_process(
        COMMAND
        ${GIT_EXECUTABLE} commit -m "Bump package lists"
        ENCODING UTF-8q
        COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()
