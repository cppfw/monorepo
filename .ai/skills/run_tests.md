# Run tests (CMake) — Skill

Run the CMake `test` target.

- Preferred: use the VS Code `Build_CMakeTools` tool with `buildTargets = ["test"]` if running in vscode context.
- Fallback: run `cmake --build build/cmake --target test`.
- Prefer CMake targets over ad-hoc make commands or runnig binaries directly.
