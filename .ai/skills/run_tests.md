# Run tests (CMake) — Skill

Purpose
-------
Run the repository test suite by invoking the CMake `test` target. This skill prefers the repository-integrated build helper so the run is executed inside the same environment the agent uses for builds.

When to use
-----------
- After a successful build, to execute the project's automated tests.
- In CI-like flows where the `test` target is the canonical way to run tests.

How the skill works
-------------------
- Preferred (programmatic): call the `Build_CMakeTools` tool with `buildTargets = ["test"]` to execute the `test` target via the workspace CMake integration.

- Manual fallback: run the CMake build tool from the build directory, for example:

	```bash
	cmake --build <build-directory> --target test
	```

Notes
-----
- Use the `Build_CMakeTools` variant when possible — it integrates with VS Code's CMake Tools and returns structured diagnostics.
- The CMake `test` target will build necessary targets before running tests.
- The `test` target will build necessary targets before running tests.

Example (agent pseudocode)
--------------------------

1. Call the `Build_CMakeTools` tool with:

```json
{ "buildTargets": ["test"] }
```

2. If manual invocation is needed, run:

```bash
cmake --build <build-directory> --target test -- -j$(nproc)
```
