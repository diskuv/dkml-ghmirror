find_program(CONDA_EXECUTABLE
        NAMES conda
        DOC "Python package manager")
set(CONDA_ENVIRONMENT "DkMLPackaging" CACHE STRING "Conda environment that contains bump2version")

add_subdirectory(version-bump)