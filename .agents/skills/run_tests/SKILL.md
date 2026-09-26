---
name: run-tests
description: Run tests via CMake's test target. Use when you need to execute the test suite.
---

# Run tests (CMake) — Skill

Run the CMake `test` target.

Run:

`cmake --build out/<preset> --target test --parallel`

Also check formatting by running the `check-format-<lib/app-name>` target for the affected library or application:

`cmake --build out/<preset> --target check-format-<lib/app-name> --parallel`

Prefer CMake targets over ad-hoc make commands or runnig binaries directly.
