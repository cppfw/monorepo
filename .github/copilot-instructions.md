This is a monorepo repository that contains:
- /repos/ruis: a C++ cross-platform GUI library containing the core GUI framework and ui comoponents
- /repos/ruisapp: the platform-specific adapters that allow ruis core to stay platform agnostic and provide a unified API for different platforms
- /repos/ruis-render-*: renderers for corresponding 3d rendering API (e.g. OpenGL and OpenGL ES)
- /repos/*: other dependencies of ruis

`ruis` allows to create cross-platform GUI applications purely in C++.