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
    set(DKML_VERSION_CMAKEVER "1.2.1.6")
endif()

string(REPLACE "." ";" VERSION_LIST ${DKML_VERSION_CMAKEVER})
list(LENGTH VERSION_LIST versionListLength)
list(GET VERSION_LIST 0 DKML_VERSION_MAJOR)
list(GET VERSION_LIST 1 DKML_VERSION_MINOR)
list(GET VERSION_LIST 2 DKML_VERSION_PATCH)
if(versionListLength GREATER_EQUAL 4)
    list(GET VERSION_LIST 3 DKML_VERSION_TWEAK)
else()
    set(DKML_VERSION_TWEAK 999)
endif()
if(DKML_VERSION_TWEAK EQUAL 999)
    set(DKML_VERSION_PRERELEASE)
else()
    set(DKML_VERSION_PRERELEASE ${DKML_VERSION_TWEAK})
endif()


set(DKML_VERSION_MAJMIN "${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}")
set(DKML_VERSION_MAJMINPAT "${DKML_VERSION_MAJOR}.${DKML_VERSION_MINOR}.${DKML_VERSION_PATCH}")

if(DKML_VERSION_PRERELEASE)
    # The semver version is used for Git tags, so it must not contain spaces
    # and it has to respect the https://semver.org/ version ordering
    set(DKML_VERSION_SEMVER "${DKML_VERSION_MAJMINPAT}-${DKML_VERSION_PRERELEASE}")
    # The opam version is used for Opam releases and is visible to users
    set(DKML_VERSION_OPAMVER "${DKML_VERSION_MAJMINPAT}~prerel${DKML_VERSION_PRERELEASE}")
else()
    set(DKML_VERSION_SEMVER "${DKML_VERSION_MAJMINPAT}")
    set(DKML_VERSION_OPAMVER "${DKML_VERSION_MAJMINPAT}")
endif()

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
endif()