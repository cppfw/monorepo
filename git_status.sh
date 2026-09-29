#!/bin/bash

echo "==========================="
echo "=== monorepo git status ==="
echo ""

git status

echo "======================="
echo "=== apps git status ==="
echo ""

for d in "apps"/*/; do
    [[ -e "$d/.git" ]] || continue

    if [[ -n "$(git -C "$d" status --porcelain)" ]]; then
        echo "=== $d:"
        echo ""

        git -C "$d" status

        echo
    fi
done
