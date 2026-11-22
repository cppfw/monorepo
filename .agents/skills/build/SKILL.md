---
name: build
description: Build the CMake project using CMake build targets. Use when you need to build a library or an application.
---

# Build (CMake) — Skill

Use CMake to build libraries and applications.

Run:

`cmake --build out/<preset> --target <application-name> --parallel`

- To build everything, omit the target entirely — the default target is `all` (single-config generators) or `ALL_BUILD` (multi-config generators like Visual Studio), which is equivalent in both cases. Note: `--target all` does not work with multi-config generators, and the `all` name is reserved by CMake and cannot be redefined.
- The `CMakeLists.txt` file is usually located in `build/cmake` directory of the project repo.
- Do not use application or library local CMake build files. Use the `monorepo`'s `build/cmake/CMakePresets.json` to build any single app/lib or all.
- Configuration should be done using the presets (see `build/cmake/CMakePresets.json`). Do not run `cmake` with ad-hoc generator or flag arguments; always select one of the defined presets.
