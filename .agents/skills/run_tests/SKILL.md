---
name: run-tests
description: Run tests via CMake's test target. Use when you need to execute the test suite.
---

# Run tests (CMake) — Skill

Run the CMake `test` target.

- Preferred: use the VS Code `Build_CMakeTools` tool with `buildTargets = ["test"]` if running in vscode context.
- Fallback: run `cd build/cmake && cmake --build --preset <preset> --target test`.
- Prefer CMake targets over ad-hoc make commands or runnig binaries directly.
