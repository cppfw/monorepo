#!/bin/bash
# status.sh — git status of the monorepo and each app under apps/.
# Run from anywhere: ./git/status.sh

cd "$(dirname "$0")/.." || exit 1

YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo "==========================="
printf "=== ${YELLOW}monorepo git status${NC} ===\n"
echo ""

git status
echo ""

echo "======================="
printf "=== ${YELLOW}apps git status${NC} ===\n"
echo ""

for d in "apps"/*/; do
    [[ -e "$d/.git" ]] || continue

    if [[ -n "$(git -C "$d" status --porcelain)" ]]; then
        printf "=== ${PURPLE}$(basename "$d")${NC}:\n"
        echo ""

        git -C "$d" status

        echo
    fi
done
