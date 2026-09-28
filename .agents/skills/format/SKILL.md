---
name: format
description: Format C/C++ source files using CMake format targets. Use when you need to format code in a library or application.
---

# Format (CMake) — Skill

Format C/C++ source files using the CMake `format-<lib/app-name>` target.
There is also `format` target which formats everything, it makes sense to use it instead of individual lib/app targets because it doesn't take too long.

Run:

`cmake --build out/<preset> --target format-<lib/app-name> --parallel`

Prefer CMake targets over ad-hoc formatter invocations.
