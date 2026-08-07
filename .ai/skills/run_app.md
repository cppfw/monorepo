# Run App (CMake) — Skill

Run an application via its CMake target.

- Preferred: use the VS Code `Build_CMakeTools` tool with `buildTargets = ["run-<app-name>"]`.
- Fallback: run `cmake --build <build-directory> --target run-<app-name>`.
- Replace `<app-name>` with the app's canonical CMake target.