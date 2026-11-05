---
name: add-new-source-file
description: Add a new source file to the project. Use when creating new .cpp/.c/.h source files.
---

# Add New Source File — Skill

- New source files do **not** need to be listed in any build scripts.
- They are picked up automatically by the wildcard in the build files.
- Just create the file in the appropriate `src/` directory and it will be included in the build.
- When adding a header file which doesn't need a corresponding source file,
  create the same named `.cpp` file anyway which includes the header file for the lint to be run
  on the header during the lint preset build. Add a comment in the `.cpp` file to explain why
  it is empty, e.g. `// this is a dummy file to test the header file compilation and linting`.
