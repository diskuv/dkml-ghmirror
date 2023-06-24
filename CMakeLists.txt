cmake_minimum_required(VERSION 3.22)

include(FetchContent)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/DkMLExternalContent.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/version.cmake)
project(DkML VERSION ${DKML_VERSION_CMAKEVER} LANGUAGES NONE)

# Project wide setup
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)
#   Optional but recommended; which C standards should be targeted
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED YES)
set(CMAKE_C_EXTENSIONS NO)

add_subdirectory(dependencies)
add_subdirectory(packaging)