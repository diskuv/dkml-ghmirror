include(${CMAKE_CURRENT_LIST_DIR}/../DkMLBumpLevels.cmake)

foreach(BUMP_LEVEL IN LISTS BUMP_LEVELS)
    shorten_bump_level(BUMP_LEVEL ${BUMP_LEVEL} OUTPUT_VARIABLE SHORT_BUMP_LEVEL)
    set(DKML_VERSION_SEMVER_NEW ${DKML_VERSION_SEMVER_NEW_${BUMP_LEVEL}})

    set(OPAMSWITCH ${PACKAGING_OPAMROOT}/${SHORT_BUMP_LEVEL})
    set(TOOLSDIR ${CMAKE_CURRENT_BINARY_DIR}/${BUMP_LEVEL})
    cmake_path(NATIVE_PATH OPAMSWITCH OPAMSWITCH_NATIVE)
    cmake_path(NATIVE_PATH TOOLSDIR TOOLSDIR_NATIVE)
    configure_file(config.in.wsb ${BUMP_LEVEL}.wsb @ONLY)
    configure_file(installer.in.cmd ${TOOLSDIR}/installer.cmd @ONLY NEWLINE_STYLE DOS)
    configure_file(test.in.cmd ${TOOLSDIR}/test.cmd @ONLY NEWLINE_STYLE DOS)
    file(COPY proj1 proj2 script1 DESTINATION ${TOOLSDIR})

    if(CMAKE_HOST_WIN32)
        add_custom_target(Package-${BUMP_LEVEL}-WindowsSandbox
            COMMAND start ${BUMP_LEVEL}.wsb
            SOURCES ${CMAKE_CURRENT_BINARY_DIR}/${BUMP_LEVEL}.wsb
        )
    endif()
endforeach()
