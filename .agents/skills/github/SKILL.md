---
name: github
description: Access GitHub (repos, CI runs, job logs, releases, issues, PRs). Use when you need to interact with GitHub.
---

# GitHub — Skill

Use the `gh` CLI to access GitHub (e.g. CI runs and job logs, releases, issues, PRs, API requests).

# Rules for making changes

- Any changes must be made via Pull Request (PR). Do not push directly to the main repo.
- The PR must be created from a **fork** of the repo.
- Pushing to the fork repo can be done using `git` via ssh.
- After creating a PR, invite `igagis` to review it and assign the PR to `igagis` using `gh`.
- Once the PR CI is green, the PR can be merged using `gh`.
- After the PR is merged, remove the PR branch (the local branch and the fork/remote branch).
