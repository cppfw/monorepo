---
name: build
description: Build the CMake project using CMake build targets. Use when you need to compile the project.
---

# Build (CMake) — Skill

Use CMake to build the project.

- Preferred: use the VS Code `Build_CMakeTools` tool if running in vscode context.
- Fallback: run `cd build/cmake && cmake --build --preset <preset>` or `cd build/cmake && cmake --build  --preset <preset> --target <target-name>`.
- Prefer CMake targets over ad-hoc make commands.
