#!/bin/bash
# main.sh — switch every repository to the main branch at its latest commit:
# the monorepo itself, each repo under repos/, and each app under apps/.
# Run from anywhere: ./git/main.sh

cd "$(dirname "$0")/.." || exit 1
# Repos with uncommitted/untracked changes are still attempted; if the
# fast-forward fails (e.g. a change would be overwritten), the repo is skipped.

usage() {
    cat <<'EOF'
main.sh — switch every repository to the main branch at its latest commit:
the monorepo itself, each repository under repos/, and each application
under apps/.

Repos with uncommitted/untracked changes are still attempted; if the
fast-forward fails (e.g. a change would be overwritten), the repo is skipped.

Usage: main.sh [options]
Options:
  -h, --help    show this help and exit
EOF
}

for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $arg" >&2; usage >&2; exit 1 ;;
    esac
done

YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

switch_to_main() {
    local dir="$1"
    local name
    name="$(basename "$dir")"

    printf "=== ${PURPLE}${name}${NC}\n"

    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
        printf "  ${YELLOW}note: uncommitted changes present${NC}\n"
    fi

    if git -C "$dir" show-ref --verify --quiet refs/heads/main; then
        if ! git -C "$dir" switch main; then
            printf "  ${RED}skipped (cannot switch to main)${NC}\n\n"
            return 1
        fi
    elif git -C "$dir" ls-remote --exit-code --quiet origin main >/dev/null 2>&1; then
        if ! git -C "$dir" switch -c main --track origin/main; then
            printf "  ${RED}skipped (cannot create main tracking origin/main)${NC}\n\n"
            return 1
        fi
    else
        printf "  ${YELLOW}skipped (no main branch locally or on origin)${NC}\n\n"
        return 1
    fi

    if git -C "$dir" fetch --quiet origin main && git -C "$dir" merge --ff-only --quiet origin/main; then
        printf "  ${GREEN}ok (main @ $(git -C "$dir" rev-parse --short HEAD))${NC}\n"
    else
        printf "  ${RED}skipped (cannot fast-forward to latest main)${NC}\n"
        return 1
    fi
    echo
    return 0
}

failed=0

echo "=============================="
printf "=== ${YELLOW}monorepo switch to main${NC} ===\n"
echo ""

switch_to_main "." || failed=$((failed + 1))

echo "=============================="
printf "=== ${YELLOW}repos switch to main${NC} ===\n"
echo ""

for d in repos/*/; do
    [[ -e "$d/.git" ]] || continue
    switch_to_main "$d" || failed=$((failed + 1))
done

echo "=============================="
printf "=== ${YELLOW}apps switch to main${NC} ===\n"
echo ""

for d in apps/*/; do
    [[ -e "$d/.git" ]] || continue
    switch_to_main "$d" || failed=$((failed + 1))
done

if [[ "$failed" -eq 0 ]]; then
    printf "${GREEN}all repositories on main${NC}\n"
else
    printf "${YELLOW}%d repository(ies) need attention${NC}\n" "$failed"
fi
