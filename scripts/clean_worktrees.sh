#!/usr/bin/env bash
#
# Remove leftover git worktrees registered under `.claude/worktrees/` (the
# Claude Code session and agent worktrees). Run by hand when stale worktrees
# pile up after their work has been merged/pushed.
#
#   scripts/clean_worktrees.sh             # remove all *clean* leftover worktrees
#   scripts/clean_worktrees.sh --dry-run   # list what would be removed
#   scripts/clean_worktrees.sh --force     # remove even ones with uncommitted changes
#
# The main working tree is never touched — only linked worktrees whose path
# lives under `.claude/worktrees/`. Without --force, a worktree that still has
# uncommitted or untracked changes is skipped and reported, so unsynced work is
# never discarded silently.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

dry_run=false
force=false

usage() {
    cat <<USAGE
Usage: $0 [--dry-run] [--force]

Removes git worktrees registered under .claude/worktrees/ (Claude Code session
and agent worktrees). The main working tree is never removed.

Options:
  -n, --dry-run   List worktrees that would be removed, without removing them.
  -f, --force     Remove worktrees even if they have uncommitted changes
                  (otherwise such worktrees are skipped and reported).
  -h, --help      Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) dry_run=true; shift ;;
        -f|--force)   force=true; shift ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# Collect linked-worktree paths under .claude/worktrees/ from porcelain output.
# (`substr($0, 10)` strips the leading "worktree " so paths with spaces survive.)
worktrees=()
while IFS= read -r path; do
    worktrees+=("$path")
done < <(
    git -C "$REPO_ROOT" worktree list --porcelain \
        | awk '/^worktree /{print substr($0, 10)}' \
        | grep "/.claude/worktrees/" || true
)

if [[ ${#worktrees[@]} -eq 0 ]]; then
    echo "No worktrees under .claude/worktrees/ — nothing to clean."
    exit 0
fi

removed=0
skipped=0
for w in "${worktrees[@]}"; do
    if $dry_run; then
        echo "would remove: $w"
        continue
    fi

    args=(worktree remove)
    if $force; then
        args+=(--force)
    fi

    if git -C "$REPO_ROOT" "${args[@]}" "$w" 2>/dev/null; then
        echo "removed: $w"
        removed=$((removed + 1))
    else
        echo "SKIPPED (uncommitted changes? re-run with --force): $w" >&2
        skipped=$((skipped + 1))
    fi
done

if ! $dry_run; then
    git -C "$REPO_ROOT" worktree prune
    echo "done — removed ${removed}, skipped ${skipped}"
fi
