include(${PROJECT_SOURCE_DIR}/version.cmake)

set(BUMP_LEVELS PRERELEASE PATCH MINOR MAJOR)

macro(make_bumped_versions VERSIONTYPE)
    function(set_new_prerelease_version)
        if(DKML_${VERSIONTYPE}_PRERELEASE)
            math(EXPR new_prerelease "${DKML_${VERSIONTYPE}_PRERELEASE} + 1")
            set(new_patch "${DKML_${VERSIONTYPE}_PATCH}")
        else()
            set(new_prerelease 1)
            math(EXPR new_patch "${DKML_${VERSIONTYPE}_PATCH} + 1")
        endif()

        set(DKML_${VERSIONTYPE}_CMAKEVER_NEW_PRERELEASE ${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}.${new_patch}.${new_prerelease} PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_SEMVER_NEW_PRERELEASE ${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}.${new_patch}-${new_prerelease} PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_OPAMVER_NEW_PRERELEASE ${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}.${new_patch}~prerel${new_prerelease} PARENT_SCOPE)
    endfunction()

    function(set_new_patch_version)
        if(DKML_${VERSIONTYPE}_PRERELEASE)
            set(new_patch "${DKML_${VERSIONTYPE}_PATCH}") # Pre-releases are _before_ a non-prerelease
        else()
            math(EXPR new_patch "${DKML_${VERSIONTYPE}_PATCH} + 1") # No pre-release
        endif()

        set(DKML_${VERSIONTYPE}_CMAKEVER_NEW_PATCH ${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}.${new_patch} PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_SEMVER_NEW_PATCH ${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}.${new_patch} PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_OPAMVER_NEW_PATCH ${DKML_${VERSIONTYPE}_MAJOR}.${DKML_${VERSIONTYPE}_MINOR}.${new_patch} PARENT_SCOPE)
    endfunction()

    function(set_new_minor_version)
        if(DKML_${VERSIONTYPE}_PRERELEASE)
            set(new_minor "${DKML_${VERSIONTYPE}_MINOR}") # Pre-releases are _before_ a non-prerelease
        else()
            math(EXPR new_minor "${DKML_${VERSIONTYPE}_MINOR} + 1") # No pre-release
        endif()

        set(DKML_${VERSIONTYPE}_CMAKEVER_NEW_MINOR ${DKML_${VERSIONTYPE}_MAJOR}.${new_minor}.0 PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_SEMVER_NEW_MINOR ${DKML_${VERSIONTYPE}_MAJOR}.${new_minor}.0 PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_OPAMVER_NEW_MINOR ${DKML_${VERSIONTYPE}_MAJOR}.${new_minor}.0 PARENT_SCOPE)
    endfunction()

    function(set_new_major_version)
        if(DKML_${VERSIONTYPE}_PRERELEASE)
            set(new_major "${DKML_${VERSIONTYPE}_MAJOR}") # Pre-releases are _before_ a non-prerelease
        else()
            math(EXPR new_major "${DKML_${VERSIONTYPE}_MAJOR} + 1") # No pre-release
        endif()

        set(DKML_${VERSIONTYPE}_CMAKEVER_NEW_MAJOR ${new_major}.0.0 PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_SEMVER_NEW_MAJOR ${new_major}.0.0 PARENT_SCOPE)
        set(DKML_${VERSIONTYPE}_OPAMVER_NEW_MAJOR ${new_major}.0.0 PARENT_SCOPE)
    endfunction()

    set_new_prerelease_version()
    set_new_patch_version()
    set_new_minor_version()
    set_new_major_version()
endmacro()

make_bumped_versions(VERSION)
make_bumped_versions(PUBLICVERSION)
