# Clean (CMake) — Skill

Use CMake to clean the build tree.

- Preferred: use the VS Code `Build_CMakeTools` tool to invoke clean.
- Fallback: run `cmake --build <build-directory> --target clean`.
- Prefer CMake clean over manual deletion of build artifacts.
