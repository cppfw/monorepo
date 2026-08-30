---
name: run-app
description: Run an application via its CMake run target. Use when you need to execute a built application.
---

# Run App (CMake) — Skill

Run an application via its CMake target.

- Preferred: use the VS Code `Build_CMakeTools` tool with `buildTargets = ["run-<app-name>"]` if running in vscode context.
- Fallback: run `cd build/cmake && cmake --build --preset <preset> --target run-<app-name>`.
- Replace `<app-name>` with the app's canonical CMake target.