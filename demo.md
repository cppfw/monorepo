# Instructions

All the instructions are supposed to be done on MacOS.

## What to demo

There is an Emscripten online demo of SpO2 monitor application:

https://gagistech.com/apps/bedsidemon-opengles-sdl.html

Otherwise, it looks like at the moment we can only demo test applications for the `ruis` GUI framework which I develop. The framework is long time Work In Progress.

Easiest way to build everything would be to use monorepo and CMake with VCPKG.

monorepo: https://github.com/cppfw/monorepo

The monorepo has some instructions in it's README, but more detailed step by step instructions follow below.

## Prerequisites

### Install Cmake

`brew install cmake`

### Install VCPKG

```
git clone https://github.com/microsoft/vcpkg.git vcpkg-installation
pushd vcpkg-installation
./bootstrap-vcpkg.sh
popd
```

### Set VCPKG_ROOT and add it to the PATH

```
export VCPKG_ROOT="<path to vcpkg-installation dir>"
export PATH=$PATH:$VCPKG_ROOT
```

### Fetch the monorepo and its submodules

Only first level of submodules needed for the monorepo.

```
git clone git@github.com:cppfw/monorepo 
cd monorepo
git submodule update --init
```

## Build

```
cd build/cmake
cmake . --preset rel
cmake --build --preset rel
```

## Run test app

Let's run the `ruis-app2` test app as it shows some amount of text on the screen. The mini windows can be resized by dragging their edges (mouse cursor doesn't change on Mac, as it is not yet implemented).

```
cd build/cmake
cmake --build --preset rel --target run-ruis-app2-app-opengl
```

### Run other test apps

List all available targets:
```
cmake --build --preset rel --target help
```

Look for targets starting with `run-` prefix. Those are to run different apps.

```
cmake --build --preset rel --target run-<app-name>-opengl
```

Only `opengl` and `opengles` renderers are implemented at the moment, no `metal` available. I think `opengles` should work on Mac, but I'm not sure, haven't tried. `opengl` still works, even though it is obsolete on Mac.
