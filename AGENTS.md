# description

This is the monorepo for `cppfw` C++ framework.

# contents

- `repos/ruis`: a C++ cross-platform GUI library designed to work with 3d graphics APIs, OS-agnostic.
- `repos/ruisapp`: the OS-adaptation layer for `ruis`.
- `repos/ruis-render-*`: renderers to use with `ruis` for different 3d rendering APIs (e.g. OpenGL and OpenGL ES).
- `repos/*`: other dependencies of `ruis` and other libraries.
- `apps/*`: user applications which use the libraries from `repos`.

# instructions

- After editing code, always rebuild the project automatically and run tests.
