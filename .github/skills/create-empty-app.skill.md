---
name: Create Empty App
summary: Scaffold a new empty C++ GUI application under apps/<name> using the monorepo CMake-only conventions.
usage:
  - Use this skill when asked to create a new app or app scaffold in the repository.
  - Use CMake-only app creation under `apps/<app>/build/cmake/CMakeLists.txt`.
  - Do not add legacy Makefile-based build files.
  - Add minimal source files in `apps/<app>/src/`.

instructions:
  - Create a new app folder only when the user explicitly asks for a new app or scaffold.
  - Use `myci_add_source_files` and `myci_declare_application(${PROJECT_NAME}-opengles ...)` for app targets.
  - Include `ruisapp::ruisapp-opengles` as the primary platform dependency for GUI apps.
  - Ensure the app does not require a `res` directory unless one is actually needed.
  - Prefer a simple centered Exit button UI for the initial app implementation.
---
