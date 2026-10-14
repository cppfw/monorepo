---
name: suppress-lint
description: Suppress a clang-tidy lint complaint on a specific line of code.
---

# Suppress Lint — Skill

To suppress a lint complaint on a certain line of code, put a `// NOLINTNEXTLINE` comment on a **separate line directly above** the line that triggers the complaint:

`// NOLINTNEXTLINE(<clang-tidy-check-names>, "<justification-for-suppression>")`

- `<clang-tidy-check-name>` is one or more names of the clang-tidy check that produced the complaint (e.g. `readability-magic-numbers`).
- `"<justification-for-suppression>"` is a short reason why the check is being suppressed on that line.

Example:

```cpp
// NOLINTNEXTLINE(readability-magic-numbers, "3 is the max number of retries")
int max_retries = 3;
```

**Important:**
- Use only `NOLINTNEXTLINE`. Never use `NOLINT` unless explicitly asked to.
- Always specify the clang-tidy check name you are suppressing.
- Always write justification for suppression.
- If the justification is long, then give short one in the `NOLINTNEXTLINE()`, and add a longer detailed justification as a comment above it.
