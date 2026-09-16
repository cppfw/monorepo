---
name: build
description: Build the CMake project using CMake build targets. Use when you need to build a library or an application.
---

# Build (CMake) — Skill

Use CMake to build libraries and applications.

Run:

`cmake --build out/<preset> --target <application-name> --parallel`

The target can also be `all`.
The `CMakeLists.txt` file is usually located in `build/cmake` directory of the project repo.
Do not use application or library local CMake build files, use the `monorepo`'s `build/cmake/CMakePresets.json` to build everything.
