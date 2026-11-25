#!/bin/bash
# pull.sh — git pull the current branch in every repository:
# the monorepo itself, each repo under repos/, and each app under apps/.
# Run from anywhere: ./git/pull.sh

cd "$(dirname "$0")/.." || exit 1

usage() {
    cat <<'EOF'
pull.sh — git pull the current branch in every repository:
the monorepo itself, each repository under repos/, and each application
under apps/.

Usage: pull.sh [options]
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

pull_repo() {
    local dir="$1"
    local name branch
    name="$(basename "$dir")"

    printf "=== ${PURPLE}${name}${NC}\n"

    if ! branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" || [[ "$branch" == "HEAD" ]]; then
        printf "  ${YELLOW}skipped (not on a branch)${NC}\n\n"
        return
    fi

    printf "  branch: ${branch}\n"
    if git -C "$dir" pull; then
        printf "  ${GREEN}ok${NC}\n"
    else
        printf "  ${RED}pull failed${NC}\n"
    fi
    echo
}

echo "=========================="
printf "=== ${YELLOW}monorepo git pull${NC} ===\n"
echo ""

pull_repo "."

echo "========================="
printf "=== ${YELLOW}repos git pull${NC} ===\n"
echo ""

for d in repos/*/; do
    [[ -e "$d/.git" ]] || continue
    pull_repo "$d"
done

echo "====================="
printf "=== ${YELLOW}apps git pull${NC} ===\n"
echo ""

for d in apps/*/; do
    [[ -e "$d/.git" ]] || continue
    pull_repo "$d"
done
