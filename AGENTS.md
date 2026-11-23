# description

This is the monorepo for `cppfw` C++ framework.

# contents

- `repos` directory contains `cppfw` libraries as git submodules.
- `apps` directory contains user applications. Some are submodules or part of the monorepo, some are user cloned git repositories which are not submodules.
- `repos/ruis`: a C++ cross-platform GUI library designed to work with 3d graphics APIs, OS-agnostic.
- `repos/ruisapp`: the OS-adaptation layer for `ruis`.
- `repos/ruis-render-*`: renderers to use with `ruis` for different 3d rendering APIs (e.g. OpenGL and OpenGL ES).

# instructions

- After editing code, always rebuild everything (no specific target) and run tests without asking user for confirmation.
- All changes must be made via Pull Request.
