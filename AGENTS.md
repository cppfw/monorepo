# description

This is the monorepo for `cppfw` C++ framework.

# contents

- `repos/ruis`: a C++ cross-platform GUI library designed to work with 3d graphics APIs, OS-agnostic.
- `repos/ruisapp`: the OS-adaptation layer for `ruis`.
- `repos/ruis-render-*`: renderers to use with `ruis` for different 3d rendering APIs (e.g. OpenGL and OpenGL ES).
- `repos/*`: other dependencies of `ruis` and other libraries.
- `apps/*`: user applications which use the libraries from `repos`.

# instructions

- After editing code, always rebuild the `all` target and run tests without asking user for confirmation.
- Use build skill to build all applications and all libraries, use `dbg` preset
- Use run_app skill to run applications
- Use run_tests skill to run tests
- Do not mind code formatting like tabs/spaces etc. when writing code. Use `format` skill to apply formatting after the code is written.
