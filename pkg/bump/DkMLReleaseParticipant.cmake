if(NOT GIT_EXECUTABLE)
    message(FATAL_ERROR "Missing -D GIT_EXECUTABLE=xx")
endif()

if(DKML_RELEASE_IS_UPGRADING_PACKAGES)
    if(NOT DKML_RELEASE_DUNE_VERSION)
        message(FATAL_ERROR "Missing -D DKML_RELEASE_DUNE_VERSION=xx")
    endif()
else()
    if(NOT DKML_RELEASE_OCAML_VERSION)
        message(FATAL_ERROR "Missing -D DKML_RELEASE_OCAML_VERSION=xx")
    endif()

    if(NOT regex_DKML_VERSION_OPAMVER)
        message(FATAL_ERROR "Missing -D regex_DKML_VERSION_OPAMVER=xx")
    endif()

    if(NOT regex_DKML_VERSION_SEMVER)
        message(FATAL_ERROR "Missing -D regex_DKML_VERSION_SEMVER=xx")
    endif()

    if(NOT DKML_VERSION_OPAMVER_NEW)
        message(FATAL_ERROR "Missing -D DKML_VERSION_OPAMVER_NEW=xx")
    endif()

    if(NOT DKML_VERSION_SEMVER_NEW)
        message(FATAL_ERROR "Missing -D DKML_VERSION_SEMVER_NEW=xx")
    endif()
endif()

macro(_DkMLReleaseParticipant_Finish_Replace VERSION_TYPE)
    if(contents STREQUAL "${contents_NEW}")
        string(FIND "${contents_NEW}" "${DKML_VERSION_${VERSION_TYPE}_NEW}" idempotent)

        if(idempotent LESS 0)
            cmake_path(ABSOLUTE_PATH REL_FILENAME OUTPUT_VARIABLE FILENAME_ABS)
            message(FATAL_ERROR "The old version(s) ${regex_DKML_VERSION_${VERSION_TYPE}} were not found in ${FILENAME_ABS} or the file already had the new version ${DKML_VERSION_${VERSION_TYPE}_NEW} derived from the DKML_VERSION_CMAKEVER value in version.cmake")
        endif()

        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_VERSION_${VERSION_TYPE}_NEW}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endmacro()

# 1.2.1-2 -> 1.2.1-3
function(DkMLReleaseParticipant_PlainReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    string(REGEX REPLACE
        "${regex_DKML_VERSION_SEMVER}"
        "${DKML_VERSION_SEMVER_NEW}"
        contents_NEW "${contents}")

    _DkMLReleaseParticipant_Finish_Replace(SEMVER)
endfunction()

# version: "1.2.1~prerel2" -> version: "1.2.1~prerel3"
function(DkMLReleaseParticipant_OpamReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version: \"${regex_DKML_VERSION_OPAMVER}\""
        "\\1version: \"${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")
    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# (version 1.2.1~prerel2) -> (version 1.2.1~prerel3)
function(DkMLReleaseParticipant_DuneProjectReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)[(]version ${regex_DKML_VERSION_OPAMVER}[)]"
        "\\1(version ${DKML_VERSION_OPAMVER_NEW})"
        contents_NEW "${contents_NEW}")
    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# dkml-apps,1.2.1~prerel2 -> dkml-apps,1.2.1~prerel3
# dkml-exe,1.2.1~prerel2 -> dkml-exe,1.2.1~prerel3
# with-dkml,1.2.1~prerel2 -> with-dkml,1.2.1~prerel3
function(_DkMLReleaseParticipant_HelperApps REL_FILENAME SEPARATOR)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    set(regex_SEPARATOR "${SEPARATOR}")
    string(REPLACE "." "[.]" regex_SEPARATOR "${regex_SEPARATOR}")
    string(REPLACE "~" "[~]" regex_SEPARATOR "${regex_SEPARATOR}")

    foreach(pkg IN ITEMS dkml-apps dkml-exe with-dkml)
        string(REGEX REPLACE # Match at beginning of line: ^|\n
            "(^|\n)([ ]*)${pkg}${regex_SEPARATOR}${regex_DKML_VERSION_OPAMVER}"
            "\\1\\2${pkg}${SEPARATOR}${DKML_VERSION_OPAMVER_NEW}"
            contents_NEW "${contents_NEW}")
    endforeach()

    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# dkml-apps.1.2.1~prerel2 -> dkml-apps.1.2.1~prerel3
# dkml-exe.1.2.1~prerel2 -> dkml-exe.1.2.1~prerel3
# with-dkml.1.2.1~prerel2 -> with-dkml.1.2.1~prerel3
function(DkMLReleaseParticipant_PkgsReplace REL_FILENAME)
    _DkMLReleaseParticipant_HelperApps(${REL_FILENAME} ".")
endfunction()

# OCAML_DEFAULT_VERSION=4.14.0 -> OCAML_DEFAULT_VERSION=4.14.2
function(DkMLReleaseParticipant_CreateOpamSwitchReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)OCAML_DEFAULT_VERSION=[0-9.]+"
        "\\1OCAML_DEFAULT_VERSION=${DKML_RELEASE_OCAML_VERSION}"
        contents_NEW "${contents_NEW}")

    if(contents STREQUAL "${contents_NEW}")
        # idempotent
        return()
    endif()

    file(WRITE ${REL_FILENAME} "${contents_NEW}")

    message(NOTICE "Bumped ${REL_FILENAME} to ${DKML_RELEASE_OCAML_VERSION}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# version = "1.2.1~prerel2" -> version = "1.2.1~prerel3"
function(DkMLReleaseParticipant_MetaReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version *= *\"${regex_DKML_VERSION_OPAMVER}\""
        "\\1version = \"${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# version: "4.14.0~v1.2.1~prerel2" -> version: "4.14.0~v1.2.1~prerel3"
# "dkml-runtime-common-native" {= "1.0.1"} -> "dkml-runtime-common-native" {= "1.0.2"}
# "dkml-runtime-common-native" {>= "1.0.1"} -> "dkml-runtime-common-native" {= "1.0.2"}
function(DkMLReleaseParticipant_DkmlBaseCompilerReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "(^|\n)version: \"([0-9.]*)[~]v${regex_DKML_VERSION_OPAMVER}\""
        "\\1version: \"${DKML_RELEASE_OCAML_VERSION}~v${DKML_VERSION_OPAMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    string(REGEX REPLACE
        "(^|\n[ ]*)\"dkml-runtime-common-native\" {>?= \"${regex_DKML_VERSION_OPAMVER}\"}"
        "\\1\"dkml-runtime-common-native\" {= \"${DKML_VERSION_OPAMVER_NEW}\"}"
        contents_NEW "${contents_NEW}")

    _DkMLReleaseParticipant_Finish_Replace(OPAMVER)
endfunction()

# ("DEFAULT_DKML_COMPILER", "4.14.0-v1.1.0-prerel15"); -> ("DEFAULT_DKML_COMPILER", "4.14.0-v1.2.1-3");
function(DkMLReleaseParticipant_ModelReplace REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    string(REGEX REPLACE # Match at beginning of line: ^|\n
        "\"DEFAULT_DKML_COMPILER\", \"([0-9.]*)-v${regex_DKML_VERSION_SEMVER}\""
        "\"DEFAULT_DKML_COMPILER\", \"${DKML_RELEASE_OCAML_VERSION}-v${DKML_VERSION_SEMVER_NEW}\""
        contents_NEW "${contents_NEW}")

    _DkMLReleaseParticipant_Finish_Replace(SEMVER)
endfunction()

# Applies a standard exclusion filter to the packages.
#
# Works with packages (base-bytes) or package-versions (base-bytes.4)
macro(_DkMLReleaseParticipant_NormalizePinnedPackages lst)
    foreach(_exclude_pkg IN ITEMS

        # Exclude packages bundled by the compiler like
        # [base-threads].
        base-bigarray
        base-bytes
        base-domains
        base-effects
        base-num
        base-threads
        base-unix
    )
        # Ex. list(FILTER ${lst} EXCLUDE REGEX "^base-bytes([.]|$)")
        # which matches "base-bytes" and "base-bytes.XXXX"
        list(FILTER ${lst} EXCLUDE REGEX "^${_exclude_pkg}([.]|$)")
    endforeach()
endmacro()

# Sets a series of OCaml list elements like:
# ("PIN_ALCOTEST", "1.6.0");
# ("PIN_ALCOTEST_ASYNC", "1.6.0");
function(DkMLReleaseParticipant_ModelUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of packages.
    # Example:
    # variantslib.1.2.3
    # with-dkml.4.5.6
    execute_process(
        COMMAND opam list --columns=package --short
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
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# Sets a series of commands like:
# opamrun pin add --switch "$do_pins_NAME"  --yes --no-action -k version alcotest "${PIN_ALCOTEST}"
function(DkMLReleaseParticipant_SetupDkmlUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of packages.
    # Example:
    # variantslib
    # with-dkml
    execute_process(
        COMMAND opam list --short
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
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

# Sets a printer of a "pinned" opam section of [switch-state]. Similar to:
#
# echo '
# pinned: [
# "0install.2.17"
# "dkml-base-compiler.4.14.0~v1.2.1~prerel10"
# "dkml-compiler-env.1.2.1~prerel10"
# ]
# '
function(DkMLReleaseParticipant_CreateOpamSwitchUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of package versions.
    # Example:
    # variantslib.v0.15.0
    # with-dkml.1.2.1~prerel10
    execute_process(
        COMMAND opam list --columns=package --short
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

function(DkMLReleaseParticipant_DuneProjectFlavorUpgrade REL_FILENAME)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    foreach(FLAVOR IN ITEMS ci full)
        # Get list of [global-install] package versions for the flavor
        # Example:
        # with-dkml.1.2.1~prerel10
        execute_process(
            COMMAND opam exec -- dkml-desktop-gen-global-install ${FLAVOR} package-versions
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
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

function(DkMLReleaseParticipant_DkmlFlavorOpamUpgrade REL_FILENAME FLAVOR)
    file(READ ${REL_FILENAME} contents)
    set(contents_NEW "${contents}")

    # Get list of [global-install] packages for the flavor
    # Example:
    # with-dkml.1.2.1~prerel10
    execute_process(
        COMMAND opam exec -- dkml-desktop-gen-global-install ${FLAVOR} packages
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
    #   Want REPLACE ".*", but nasty cmake bug:
    #   https://gitlab.kitware.com/cmake/cmake/-/issues/18884 https://gitlab.kitware.com/cmake/cmake/-/issues/16899
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
  # Managed by ${managerFile}
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
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${REL_FILENAME})
endfunction()

function(DkMLReleaseParticipant_DuneBuildOpamFiles)
    # Find *.opam files to rebuild
    file(
        GLOB opamFiles
        LIST_DIRECTORIES false
        RELATIVE ${CMAKE_CURRENT_BINARY_DIR}
        *.opam)

    if(IS_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/opam)
        # opam allows its .opam files to be in a opam/ subfolder
        file(
            GLOB opamFiles2
            LIST_DIRECTORIES false
            RELATIVE ${CMAKE_CURRENT_BINARY_DIR}
            opam/*.opam)
        list(APPEND opamFiles ${opamFiles2})
    endif()

    # Sort them
    list(SORT opamFiles)

    # Read them for a "before" snapshot
    foreach(opamFile IN LISTS opamFiles)
        file(READ ${opamFile} contents)
        string(REPLACE "\r" "" contents "${contents}") # Normalize CRLF
        string(MAKE_C_IDENTIFIER ${opamFile} opamFileId)
        set(contents_${opamFileId} "${contents}")
    endforeach()

    # Do a dune build to regenerate
    execute_process(
        COMMAND opam exec -- dune build ${opamFiles}
        COMMAND_ERROR_IS_FATAL ANY
    )

    # Which content changed, if any?
    set(changedOpamFiles)

    foreach(opamFile IN LISTS opamFiles)
        file(READ ${opamFile} contents)
        string(REPLACE "\r" "" contents "${contents}") # Normalize CRLF
        string(MAKE_C_IDENTIFIER ${opamFile} opamFileId)

        if(NOT(contents_${opamFileId} STREQUAL "${contents}"))
            list(APPEND changedOpamFiles ${opamFile})
        endif()
    endforeach()

    # Check idempotent
    if(NOT changedOpamFiles)
        # idempotent
        return()
    endif()

    list(JOIN changedOpamFiles " " changedOpamFiles_SPACES)
    message(NOTICE "Upgraded ${changedOpamFiles_SPACES}")
    set_property(GLOBAL APPEND PROPERTY DkMLReleaseParticipant_REL_FILES ${changedOpamFiles})
endfunction()

function(DkMLReleaseParticipant_GitAddAndCommit)
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
        ${GIT_EXECUTABLE} commit -m "Version: ${DKML_VERSION_SEMVER_NEW}"
        ENCODING UTF-8
        COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()
