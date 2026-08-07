# Clean (CMake) — Skill

Purpose
-------
Clean the repository build artifacts. This skill prefers the VS Code CMake integration when it is available and falls back to a direct CMake command-line invocation if VS Code is not running.

When to use
-----------
- When the agent needs to remove previous build outputs before rebuilding.
- Before a fresh build to avoid stale artifacts.
- When a clean state is required for debugging or verification.

How the skill works
-------------------
- Preferred (programmatic): invoke the VS Code `Build_CMakeTools` tool to perform the clean action through the CMake Tools integration.
- Fallback (manual): run CMake from the configured build directory, for example:

  ```bash
  cmake --build <build-directory> --target clean
  ```

Notes
-----
- Prefer the VS Code CMake Tools integration when possible because it integrates with the active workspace build environment.
- If VS Code is not available or the build integration is not active, use the manual CMake clean invocation.
- Use CMake-based cleaning rather than ad-hoc shell cleanup when possible.

Example (agent pseudocode)
--------------------------

1. If VS Code CMake integration is available, invoke the VS Code `Build_CMakeTools` tool to perform the clean action.
2. Otherwise, run:

```bash
cmake --build <build-directory> --target clean
```
