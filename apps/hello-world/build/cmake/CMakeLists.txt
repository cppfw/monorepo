cmake_minimum_required(VERSION 3.30)

project(hello-world)

# !!! find_package must go after project() declaration !!!
# Otherwise VCPKG does not set the CMAKE_PREFIX_PATH to find packages.
find_package(myci CONFIG REQUIRED)

set(srcs)
myci_add_source_files(srcs
    DIRECTORY
        ../../src
    RECURSIVE
)

myci_declare_application(${PROJECT_NAME}-opengles
    SOURCES
        ${srcs}
    INCLUDE_DIRECTORIES
        ../../src
    DEPENDENCIES
        clargs
        ruisapp::ruisapp-opengles
    #RUN_ARGUMENTS
        #--window
)
