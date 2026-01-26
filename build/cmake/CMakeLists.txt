cmake_minimum_required(VERSION 3.20)

# This is umbrella CMakeLists.txt for all subrepos of the monorepo.

# We take VCPKG_ROOT from the environment, but we have to store it in CMake cache, so that if IDE later
# needs to rerun configuration phase, it will still work even if the environment variable is not set anymore.
if(NOT VCPKG_ROOT)
    if(NOT DEFINED ENV{VCPKG_ROOT})
        message(FATAL_ERROR "VCPKG_ROOT is not set")
    endif()
    set(VCPKG_ROOT "$ENV{VCPKG_ROOT}" CACHE INTERNAL "" FORCE)
else()
    # Set environment variable VCPKG_ROOT from our cache variable, because this is a standard VCPKG variable
    # and it is required to be set by VCPKG. Also its value may affect some scripts running in the VCPKG context.
    set(ENV{VCPKG_ROOT} "${VCPKG_ROOT}")
endif()

set(CMAKE_TOOLCHAIN_FILE ${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake)

# In case of ios we always build for simulator for now.
# Need to do this check before project() declaration, so use CMAKE_SYSTEM_NAME instead of IOS variable,
# because the IOS variable is set only after the first project() declaration.
if(CMAKE_SYSTEM_NAME STREQUAL iOS)
    # In order to install ios _simulator_ vcpkg packages we need to set the vcpkg target triplet.
    set(VCPKG_TARGET_TRIPLET arm64-ios-simulator)

    # TODO: not needed? Remove.
    # set(CMAKE_OSX_SYSROOT iphonesimulator)

endif()

# Set myci config directory for find_package(myci). The path has to be absolute.
set(myci_DIR ../../repos/myci/src/cmake)
cmake_path(ABSOLUTE_PATH myci_DIR NORMALIZE)

project(cppfw)

find_package(myci CONFIG REQUIRED)

set_property(GLOBAL PROPERTY USE_FOLDERS TRUE)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "CMake")
set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" PROPERTY VS_STARTUP_PROJECT "ruisapp-opengl-test")

set(CPPFW_MONOREPO True)

function(add_subdir name)
    myci_add_subdirectory(../../repos/${name}/build/cmake
        BINARY_DIR
            ${name}
    )
endfunction()

add_subdir(utki)
add_subdir(fsif)
add_subdir(cssom)
add_subdir(mikroxml)
add_subdir(opros)
add_subdir(nitki)
add_subdir(clargs)
add_subdir(tst)
add_subdir(jsondom)
add_subdir(r4)
add_subdir(svgdom)
add_subdir(agg)
add_subdir(rasterimage)
add_subdir(veg)
add_subdir(svgren)
add_subdir(tml)
add_subdir(ruis)
add_subdir(ruis-render-null)
add_subdir(ruis-render-opengl)
add_subdir(ruis-render-opengles)
add_subdir(ruisapp)
add_subdir(audout)
add_subdir(aumiks)
add_subdir(setka)

set(apps_dir "${CMAKE_CURRENT_SOURCE_DIR}/../../apps")
file(
    GLOB
        apps
    LIST_DIRECTORIES
        TRUE
    RELATIVE
        "${apps_dir}"
    CONFIGURE_DEPENDS
        "${apps_dir}/*"
)

foreach(app ${apps})
    set(dir "${apps_dir}/${app}/build/cmake")
    if (IS_DIRECTORY "${dir}")
        add_subdirectory("${dir}" "apps/${app}")
    endif()
endforeach()
