---
name: run-app
description: Run a built application. Use when you need to execute an application.
---

# Run App — Skill

## Via CMake run target

`cmake --build out/<preset> --target run-<app-name> --parallel`

- To find the run target name, list all targets: `cmake --build out/<preset> --target help` (look for `run-...`).
- The app's CMake target name is declared via `myci_declare_application` in the app's `build/cmake/CMakeLists.txt`.
- Running blocks while the app is alive (e.g. GUI event loop).

## Running directly

`out/<preset>/exe/<app-name>/<app-name> [args...]`

- **CWD matters:** resources are copied to `out/<preset>/exe/<app-name>/`. `cd` there before launching:

  ```bash
  cd out/<preset>/exe/<app-name>
  ./<app-name> [args...]
  ```

- With MSBuild/MSVC the app is under a `Debug/` or `Release/` subdirectory of that CWD, run it from there: `./Debug/<app-name>.exe`.

- Some apps accept a flag to specify the resources path explicitly (e.g. `--resources <path>`). Check the app's `main.cpp` or `--help` for the exact flag.
