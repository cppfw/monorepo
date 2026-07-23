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

function(declare_hello_world_app renderer)
    myci_declare_application(${PROJECT_NAME}-${renderer}
        SOURCES
            ${srcs}
        DEPENDENCIES
            ruisapp::ruisapp-${renderer}
    )
endfunction()

if(IOS)
    declare_hello_world_app(opengles)
else()
    declare_hello_world_app(opengl)
    declare_hello_world_app(opengles)
endif()
