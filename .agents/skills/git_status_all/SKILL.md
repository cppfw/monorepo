---
name: git-status-all
description: Get the git status of all the subrepos of the monorepo (the monorepo itself and each app in the apps dir). Use when you need an overview of the git status across all subrepos.
---

# Git Status All — Skill

Get the git status of all the subrepos of the monorepo (the monorepo itself and each app in the `apps/` directory).

Run the `git_status.sh` script from the root of the monorepo:

`./git_status.sh`

It prints:
- `git status` for the monorepo (mentioning submodules if there is modified content)
- `git status` for each app in `apps/` directory that has changes.
