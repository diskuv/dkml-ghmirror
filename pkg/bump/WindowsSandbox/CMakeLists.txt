include(${CMAKE_CURRENT_LIST_DIR}/../DkMLBumpLevels.cmake)

set(OPAMSWITCH ${PACKAGING_OPAMROOT}/${DKML_VERSION_CMAKEVER})
set(TOOLSDIR ${CMAKE_CURRENT_BINARY_DIR}/tools)
cmake_path(NATIVE_PATH OPAMSWITCH OPAMSWITCH_NATIVE)
cmake_path(NATIVE_PATH TOOLSDIR TOOLSDIR_NATIVE)
configure_file(config.in.wsb config.wsb @ONLY)
configure_file(installer-native.in.cmd ${TOOLSDIR}/installer-native.cmd @ONLY NEWLINE_STYLE DOS)
configure_file(installer-byte.in.cmd ${TOOLSDIR}/installer-byte.cmd @ONLY NEWLINE_STYLE DOS)
file(COPY_FILE install-winget.ps1 ${TOOLSDIR}/install-winget.ps1 ONLY_IF_DIFFERENT)
configure_file(test.in.cmd ${TOOLSDIR}/test.cmd @ONLY NEWLINE_STYLE DOS)
file(COPY proj1 proj2 script1 DESTINATION ${TOOLSDIR})

if(CMAKE_HOST_WIN32)
    add_custom_target(Package-WindowsSandbox
        COMMAND start config.wsb
        SOURCES ${CMAKE_CURRENT_BINARY_DIR}/config.wsb
    )

    add_custom_target(Package-WindowsDocker
        COMMAND
        start docker run -it
        -v "${OPAMSWITCH_NATIVE}:C:\\Switch"
        -v "${TOOLSDIR_NATIVE}:C:\\Tools"
        mcr.microsoft.com/windows/servercore:ltsc2022
        VERBATIM USES_TERMINAL)
endif()
