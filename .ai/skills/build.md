# Build (CMake) — Skill

Purpose
-------
Build the repository.

When to use
-----------
- When the task requires compiling the project or a specific target.
- Before running tests or launching apps so the latest binaries are available.
- When an agent needs a build step that is consistent with the repository CMake setup.

How the skill works
-------------------
- Preferred (programmatic): use the VS Code `Build_CMakeTools` tool with the desired build targets.
- Fallback (manual): run CMake from the configured build directory, for example:

  ```bash
  cmake --build <build-directory>
  ```

  or, for a specific target:

  ```bash
  cmake --build <build-directory> --target <target-name>
  ```

Notes
-----
- Prefer the VS Code CMake Tools integration when possible because it provides better diagnostics and workspace integration.
- If a build directory is not already configured, use the repository's CMake presets or the workspace's existing build configuration.
- Use the repository's CMake targets rather than ad-hoc make invocations when building this project.

Example (agent pseudocode)
--------------------------

1. Call the VS Code `Build_CMakeTools` tool with the relevant target list.
2. If manual invocation is needed, run:

```bash
cmake --build <build-directory> --target <target-name> --parallel
```
