#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

dry_run=false
keep_dirs=false

usage() {
    cat <<USAGE
Usage: $0 [--dry-run] [--keep-dirs]

Deletes all snapshot reference PNG files under __Snapshots__ directories.

Options:
  -n, --dry-run   Print files that would be deleted without deleting them.
      --keep-dirs Keep empty __Snapshots__ directories after deleting PNG files.
  -h, --help      Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            dry_run=true
            ;;
        --keep-dirs)
            keep_dirs=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac

    shift
done

snapshot_files="$(mktemp)"
trap 'rm -f "$snapshot_files"' EXIT

find "$REPO_ROOT" \
    \( \
        -path "$REPO_ROOT/.git" \
        -o -path "$REPO_ROOT/Derived" \
        -o -path "$REPO_ROOT/Tuist/.build" \
        -o -path "$REPO_ROOT/Keybo.xcodeproj" \
        -o -path "$REPO_ROOT/Keybo.xcworkspace" \
    \) -prune \
    -o -type f -path "*/__Snapshots__/*.png" -print \
    | sort > "$snapshot_files"

snapshot_count="$(wc -l < "$snapshot_files" | tr -d '[:space:]')"

if [[ "$snapshot_count" == "0" ]]; then
    echo "No snapshot PNG references found."
    exit 0
fi

if [[ "$dry_run" == true ]]; then
    echo "Would delete ${snapshot_count} snapshot PNG reference(s):"
    while IFS= read -r snapshot_file; do
        echo "- ${snapshot_file#"${REPO_ROOT}/"}"
    done < "$snapshot_files"
    exit 0
fi

while IFS= read -r snapshot_file; do
    rm -f "$snapshot_file"
done < "$snapshot_files"

if [[ "$keep_dirs" == false ]]; then
    while IFS= read -r snapshot_dir; do
        rmdir "$snapshot_dir" 2>/dev/null || true
    done < <(
        find "$REPO_ROOT" \
            \( \
                -path "$REPO_ROOT/.git" \
                -o -path "$REPO_ROOT/Derived" \
                -o -path "$REPO_ROOT/Tuist/.build" \
                -o -path "$REPO_ROOT/Keybo.xcodeproj" \
                -o -path "$REPO_ROOT/Keybo.xcworkspace" \
            \) -prune \
            -o -type d \( -name "__Snapshots__" -o -path "*/__Snapshots__/*" \) -print \
            | sort -r
    )
fi

echo "Deleted ${snapshot_count} snapshot PNG reference(s)."
