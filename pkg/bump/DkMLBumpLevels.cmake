if(CMAKE_SCRIPT_MODE_FILE)
    include(${CMAKE_SOURCE_DIR}/version.cmake)
else()
    include(${PROJECT_SOURCE_DIR}/version.cmake)
endif()

set(BUMP_LEVELS PRERELEASE PATCH MINOR MAJOR)

macro(make_bumped_versions)
    set(options)
    set(oneValueArgs VERSIONTYPE MAJOR MINOR PATCH PRERELEASE)
    set(multiValueArgs)
    cmake_parse_arguments(BUMPARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    # The bump of cmake version depends on the (previous) public version,
    # except if it is a prerelease
    function(set_new_prerelease_version)
        if(BUMPARG_PRERELEASE)
            math(EXPR new_prerelease "${BUMPARG_PRERELEASE} + 1")
            set(new_patch "${DKML_PUBLICVERSION_PATCH}")
        else()
            set(new_prerelease 1)
            math(EXPR new_patch "${BUMPARG_PATCH} + 1")
        endif()

        set(DKML_${BUMPARG_VERSIONTYPE}_CMAKEVER_NEW_PRERELEASE ${BUMPARG_MAJOR}.${BUMPARG_MINOR}.${new_patch}.${new_prerelease} PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_SEMVER_NEW_PRERELEASE ${BUMPARG_MAJOR}.${BUMPARG_MINOR}.${new_patch}-${new_prerelease} PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_OPAMVER_NEW_PRERELEASE ${BUMPARG_MAJOR}.${BUMPARG_MINOR}.${new_patch}~prerel${new_prerelease} PARENT_SCOPE)
    endfunction()

    function(set_new_patch_version)
        if(BUMPARG_PRERELEASE)
            set(new_patch "${DKML_PUBLICVERSION_PATCH}") # Pre-releases are _before_ a non-prerelease
        else()
            math(EXPR new_patch "${BUMPARG_PATCH} + 1") # No pre-release
        endif()

        set(DKML_${BUMPARG_VERSIONTYPE}_CMAKEVER_NEW_PATCH ${BUMPARG_MAJOR}.${BUMPARG_MINOR}.${new_patch} PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_SEMVER_NEW_PATCH ${BUMPARG_MAJOR}.${BUMPARG_MINOR}.${new_patch} PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_OPAMVER_NEW_PATCH ${BUMPARG_MAJOR}.${BUMPARG_MINOR}.${new_patch} PARENT_SCOPE)
    endfunction()

    function(set_new_minor_version)
        if(BUMPARG_PRERELEASE
            AND DKML_PUBLICVERSION_PATCH EQUAL 0)
            set(new_minor "${DKML_PUBLICVERSION_MINOR}") # Pre-releases are _before_ a non-prerelease
        else()
            math(EXPR new_minor "${BUMPARG_MINOR} + 1") # No pre-release
        endif()

        set(DKML_${BUMPARG_VERSIONTYPE}_CMAKEVER_NEW_MINOR ${BUMPARG_MAJOR}.${new_minor}.0 PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_SEMVER_NEW_MINOR ${BUMPARG_MAJOR}.${new_minor}.0 PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_OPAMVER_NEW_MINOR ${BUMPARG_MAJOR}.${new_minor}.0 PARENT_SCOPE)
    endfunction()

    function(set_new_major_version)
        if(BUMPARG_PRERELEASE
            AND DKML_PUBLICVERSION_PATCH EQUAL 0
            AND DKML_PUBLICVERSION_MINOR EQUAL 0)
            set(new_major "${DKML_PUBLICVERSION_MAJOR}") # Pre-releases are _before_ a non-prerelease
        else()
            math(EXPR new_major "${BUMPARG_MAJOR} + 1") # No pre-release
        endif()

        set(DKML_${BUMPARG_VERSIONTYPE}_CMAKEVER_NEW_MAJOR ${new_major}.0.0 PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_SEMVER_NEW_MAJOR ${new_major}.0.0 PARENT_SCOPE)
        set(DKML_${BUMPARG_VERSIONTYPE}_OPAMVER_NEW_MAJOR ${new_major}.0.0 PARENT_SCOPE)
    endfunction()

    set_new_prerelease_version()
    set_new_patch_version()
    set_new_minor_version()
    set_new_major_version()
endmacro()

# Testing:
# cmake -D DUMP_DKML_VERSION=1 -P pkg/bump/DkMLBumpLevels.cmake
# cmake -D DUMP_DKML_VERSION=1 -D DKML_PUBLICVERSION_CMAKEVER_OVERRIDE=1.2.3 -P pkg/bump/DkMLBumpLevels.cmake
# cmake -D DUMP_DKML_VERSION=1 -D DKML_PUBLICVERSION_CMAKEVER_OVERRIDE=1.2.3.4 -P pkg/bump/DkMLBumpLevels.cmake
# cmake -D DUMP_DKML_VERSION=1 -D DKML_PUBLICVERSION_CMAKEVER_OVERRIDE=1.2.3.999 -P pkg/bump/DkMLBumpLevels.cmake
if(CMAKE_SCRIPT_MODE_FILE AND DUMP_DKML_VERSION)
    make_bumped_versions(
        VERSIONTYPE VERSION
        MAJOR ${DKML_VERSION_MAJOR}
        MINOR ${DKML_VERSION_MINOR}
        PATCH ${DKML_VERSION_PATCH}
        PRERELEASE "${DKML_VERSION_PRERELEASE}")

    foreach(BUMP_LEVEL IN LISTS BUMP_LEVELS)
        message(NOTICE "DKML_VERSION_OPAMVER_NEW_${BUMP_LEVEL}=${DKML_VERSION_OPAMVER_NEW_${BUMP_LEVEL}}")
    endforeach()
endif()