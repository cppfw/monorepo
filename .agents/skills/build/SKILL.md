---
name: build
description: Build the CMake project using CMake build targets. Use when you need to compile the project.
---

# Build (CMake) — Skill

Use CMake to build the project.

- Preferred: use the VS Code `Build_CMakeTools` tool if running in vscode context.
- Fallback: run `cmake --build build/cmake` or `cmake --build build/cmake --target <target-name>`.
- Prefer CMake targets over ad-hoc make commands.
