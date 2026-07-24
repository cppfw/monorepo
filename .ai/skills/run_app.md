# Run App (CMake) — Skill

Purpose
-------
This skill runs an application declared by the monorepo `myci` CMake framework. `myci` creates a `run-<app-name>` CMake target for apps. The skill executes that target using CMake.

When to use
-----------
- After a successful build, to launch an app for runtime verification.
- When an agent needs to reproduce or debug runtime issues.

How the skill works
-------------------
- Preferred method (programmatic): invoke the repository build helper with the `run-<app-name>` target. Example for agent tooling:

- Call the `Build_CMakeTools` tool with `buildTargets = ["run-<app-name>"]`.

- Fallback (manual): run the CMake build tool from the build directory, e.g.:

  ```bash
  cmake --build <build-directory> --target run-<app-name>
  ```

Notes
-----
- Replace `<app-name>` with the canonical app target name (for example `calslog-opengles` or `hello-world-opengles`).
- The agent should prefer `Build_CMakeTools` so the environment integrates with VS Code/CMake Tools and provides diagnostics.

Example (agent pseudocode)
--------------------------

1. Determine run target name: `run-<app-target>` or directly `<app-target>` if the monorepo exposes it.
2. Call Build_CMakeTools with `buildTargets = ["run-<app-target>"]`.
