---
name: run-app
description: Run an application via its CMake run target. Use when you need to execute a built application.
---

# Run App (CMake) — Skill

Run an application via its CMake run target.

Run:

`cmake --build out/<preset> --target run-<app-name> --parallel`

- Replace the `<app-name>` with the app's canonical CMake target.
- The app's canonical CMake target is usually declared in the `build/cmake` directory of the project repo (look for `myci_declare_application` or similar).
- Do not use application or library local CMake build files. Use the `monorepo`'s `build/cmake/CMakePresets.json` to run any single app.
- Note that running an application blocks while it is alive (e.g. GUI event loop).
