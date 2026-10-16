---
name: lint
description: Lint C/C++ sources using clang-tidy. Use when you need to lint or check the code for lint issues.
---

# Lint — Skill

Run lint by building the `lint` preset. It is a debug build with clang-tidy enabled, so the sources are linted as part of the build.

Run:

`cmake --build out/lint --target all --parallel`
