---
name: vcpkg_baseline
description: Update the VCPKG baseline. Use when you need to update the VCPKG baseline to the latest cppfw vcpkg-repo commit.
---

# VCPKG baseline — Skill

Update the VCPKG baseline so the project builds against the latest cppfw vcpkg ports.

The baseline is the commit hash of `cppfw/vcpkg-repo` stored in the project's
`build/vcpkg/test/vcpkg-configuration.json`, under the registry whose
`repository` is `https://github.com/cppfw/vcpkg-repo/`.

## Steps

1. Pull the latest commit hash of the cppfw vcpkg repo:

   Repo: https://github.com/cppfw/vcpkg-repo

   `gh api repos/cppfw/vcpkg-repo/commits/main --jq .sha`

2. In `build/vcpkg/test/vcpkg-configuration.json`, replace the `baseline`
   value of the cppfw registry with the new commit hash.
   Do not touch the `default-registry` (microsoft/vcpkg) baseline.
