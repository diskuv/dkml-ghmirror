# CMake has "major[.minor[.patch[.tweak]]]", where .tweak is just another
# incrementing version component. That is compatible with
# `if(DKML_VERSION VERSION_GREATER_EQUAL 1.0.0)` statements, but is
# not semver!
#
# We also want to have a version number that can be bumped with
# bump2version.
#
# Therefore:
# 1. We will treat .tweak = .999 as if it had no semver prerelease
# version component.
# 2. We start with a full version number that is bumpable, and then
# decompose it so we can pull out a semver compatible version.

# Allow [-D <DKML_VERSION_CMAKEVER_OVERRIDE>] in script mode
if(CMAKE_SCRIPT_MODE_FILE AND DKML_VERSION_CMAKEVER_OVERRIDE)
    set(DKML_VERSION_CMAKEVER "${DKML_VERSION_CMAKEVER_OVERRIDE}")
else()
    # Edited by pkg/bump/CMakeLists.txt. Do not change format.
    set(DKML_VERSION_CMAKEVER "2.0.1")
endif()

# The last released version (never a prerelease)
# Edited by pkg/bump/CMakeLists.txt. Do not change format.
set(DKML_PUBLICVERSION_CMAKEVER "2.0.1")

macro(ExpandDkmlVersion VERSIONTYPE)
    string(REPLACE "." ";" VERSION_LIST ${DKML_${VERSIONTYPE}_CMAKEVER})
    list(LENGTH VERSION_LIST versionListLength)
    list(GET VERSION_LIST 0 DKML_${VERSIONTYPE}_MAJOR)
    list(GET VERSION_LIST 1 DKML_${VERSIONTYPE}_MINOR)
    list(GET VERSION_LIST 2 DKML_${VERSIONTYPE}_PATCH)
    if(versionListLength GREATER_EQUAL 4)
        list(GET VERSION_LIST 3 DKML_${VERSIONTYPE}_TWEAK)
    else()
        set(DKML_${VERSIONTYPE}_TWEAK 999)
    endif()
    if(DKML_${VERSIONTYPE}_TWEAK EQUAL 999)
        set(DKML_${VERSIONTYPE}_PRERELEASE)
    else()
        set(DKML_${VERSIONTYPE}_PRERELEASE ${DKML_${VERSIONTYPE}_TWEAK})
    endif()


    set(DKML_${VERSIONTYPE}_MAJMIN "${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}")
    set(DKML_${VERSIONTYPE}_MAJMINPAT "${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}.${DKML_${VERSIONTYPE}_PATCH}")

    if(DKML_${VERSIONTYPE}_PRERELEASE)
        # The semver version is used for Git tags, so it must not contain spaces
        # and it has to respect the https://semver.org/ version ordering
        set(DKML_${VERSIONTYPE}_SEMVER "${DKML_${VERSIONTYPE}_MAJMINPAT}-${DKML_${VERSIONTYPE}_PRERELEASE}")
        # The opam version is used for Opam releases and is visible to users
        set(DKML_${VERSIONTYPE}_OPAMVER "${DKML_${VERSIONTYPE}_MAJMINPAT}~prerel${DKML_${VERSIONTYPE}_PRERELEASE}")
    else()
        set(DKML_${VERSIONTYPE}_SEMVER "${DKML_${VERSIONTYPE}_MAJMINPAT}")
        set(DKML_${VERSIONTYPE}_OPAMVER "${DKML_${VERSIONTYPE}_MAJMINPAT}")
    endif()
endmacro()
ExpandDkmlVersion(VERSION)
ExpandDkmlVersion(PUBLICVERSION)

# Testing:
#   cmake -D DUMP_DKML_VERSION=1 -P version.cmake
#   cmake -D DUMP_DKML_VERSION=1 -D DKML_VERSION_CMAKEVER_OVERRIDE=1.2.3 -P version.cmake
#   cmake -D DUMP_DKML_VERSION=1 -D DKML_VERSION_CMAKEVER_OVERRIDE=1.2.3.4 -P version.cmake
#   cmake -D DUMP_DKML_VERSION=1 -D DKML_VERSION_CMAKEVER_OVERRIDE=1.2.3.999 -P version.cmake
if(CMAKE_SCRIPT_MODE_FILE AND DUMP_DKML_VERSION)
    message(NOTICE "DKML_VERSION_CMAKEVER=${DKML_VERSION_CMAKEVER}")
    message(NOTICE "DKML_VERSION_MAJOR=${DKML_VERSION_MAJOR}")
    message(NOTICE "DKML_VERSION_MINOR=${DKML_VERSION_MINOR}")
    message(NOTICE "DKML_VERSION_PATCH=${DKML_VERSION_PATCH}")
    message(NOTICE "DKML_VERSION_TWEAK=${DKML_VERSION_TWEAK}")
    message(NOTICE "DKML_VERSION_PRERELEASE=${DKML_VERSION_PRERELEASE}")
    message(NOTICE "DKML_VERSION_MAJMIN=${DKML_VERSION_MAJMIN}")
    message(NOTICE "DKML_VERSION_MAJMINPAT=${DKML_VERSION_MAJMINPAT}")
    message(NOTICE "DKML_VERSION_SEMVER=${DKML_VERSION_SEMVER}")

    message(NOTICE "DKML_PUBLICVERSION_CMAKEVER=${DKML_PUBLICVERSION_CMAKEVER}")
    message(NOTICE "DKML_PUBLICVERSION_MAJOR=${DKML_PUBLICVERSION_MAJOR}")
    message(NOTICE "DKML_PUBLICVERSION_MINOR=${DKML_PUBLICVERSION_MINOR}")
    message(NOTICE "DKML_PUBLICVERSION_PATCH=${DKML_PUBLICVERSION_PATCH}")
    message(NOTICE "DKML_PUBLICVERSION_TWEAK=${DKML_PUBLICVERSION_TWEAK}")
    message(NOTICE "DKML_PUBLICVERSION_PRERELEASE=${DKML_PUBLICVERSION_PRERELEASE}")
    message(NOTICE "DKML_PUBLICVERSION_MAJMIN=${DKML_PUBLICVERSION_MAJMIN}")
    message(NOTICE "DKML_PUBLICVERSION_MAJMINPAT=${DKML_PUBLICVERSION_MAJMINPAT}")
    message(NOTICE "DKML_PUBLICVERSION_SEMVER=${DKML_PUBLICVERSION_SEMVER}")
endif()