This is a monorepo repository that contains:
- /repos/ruis: a C++ cross-platform GUI library containing the core GUI framework and UI components
- /repos/ruisapp: the platform-specific adapters that allow ruis core to stay platform agnostic and provide a unified API for different platforms
- /repos/ruis-render-*: renderers for corresponding 3D rendering APIs (e.g. OpenGL and OpenGL ES)
- /repos/*: other dependencies of ruis

`ruis` allows creating cross-platform GUI applications purely in C++.

Important repository-specific guidance:
- New apps should use CMake only and belong under `apps/<app>/build/cmake/CMakeLists.txt`.
- Avoid legacy `Makefile`-based build files for new app targets.
- App sources belong under `apps/<app>/src/<app>/` and should be added with `myci_add_source_files`.
- Declare the executable with `myci_declare_application(${PROJECT_NAME}-opengles ...)` and link the matching `ruisapp` target, e.g. `ruisapp::ruisapp-opengles`.
- Only set `RESOURCE_DIRECTORY` in CMake when a real `res` directory exists for that app.
- Common useful includes:
  - `ruisapp/application.hpp`
  - `ruis/widget/container.hpp`
  - `ruis/util/length.hpp`
- `ruis/util/length.hpp` exposes `ruis::length_literals` and the `_px`, `_pp`, `_mm` operators.
- Prefer app skeletons with a minimal `main.cpp`, `application.cpp`, `application.hpp`, `gui.cpp`, and `gui.hpp`.
