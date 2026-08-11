# Clean (CMake) — Skill

Use CMake to clean the build tree.

- Preferred: use the VS Code `Build_CMakeTools` tool to invoke clean if running in vscode context.
- Fallback: run `cmake --build build/cmake --target clean`.
- Prefer CMake clean over manual deletion of build artifacts.
