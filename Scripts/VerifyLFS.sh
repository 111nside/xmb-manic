#!/bin/bash
set -euo pipefail

POINTER_MAGIC='version https://git-lfs.github.com/spec/v1'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

AUTO_FIX=0
if [[ "${1:-}" == "--fix" ]]; then
    AUTO_FIX=1
fi

is_lfs_pointer() {
    local file_path="$1"
    [[ -f "$file_path" ]] || return 1
    head -c "${#POINTER_MAGIC}" "$file_path" | grep -qF "$POINTER_MAGIC"
}

collect_lfs_issues() {
    stale_files=()
    missing_files=()

    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        if [[ ! -e "$file_path" ]]; then
            missing_files+=("$file_path")
        elif is_lfs_pointer "$file_path"; then
            stale_files+=("$file_path")
        fi
    done < <(git lfs ls-files -n 2>/dev/null)
}

report_issues() {
    local total
    total="$(git lfs ls-files 2>/dev/null | wc -l | tr -d ' ')"

    if ((${#stale_files[@]} + ${#missing_files[@]} == 0)); then
        echo "Verify LFS: OK (${total} tracked files)"
        return 0
    fi

    echo "error: Git LFS objects are not fully checked out on disk." >&2
    echo "       Some paths still contain LFS pointer text instead of real file content." >&2
    echo "" >&2

    if ((${#stale_files[@]} > 0)); then
        echo "Pointer files (${#stale_files[@]}):" >&2
        printf '  %s\n' "${stale_files[@]}" >&2
        echo "" >&2
    fi

    if ((${#missing_files[@]} > 0)); then
        echo "Missing files (${#missing_files[@]}):" >&2
        printf '  %s\n' "${missing_files[@]}" >&2
        echo "" >&2
    fi

    echo "Fix manually with:" >&2
    echo "  git lfs install && git lfs pull && git lfs checkout" >&2
    return 1
}

try_auto_fix() {
    if ! command -v git-lfs >/dev/null 2>&1; then
        echo "error: git-lfs is not installed; cannot auto-fix LFS checkout." >&2
        return 1
    fi

    echo "Verify LFS: attempting auto-fix (git lfs pull && git lfs checkout)..."
    git lfs pull
    git lfs checkout
}

collect_lfs_issues

if report_issues; then
    exit 0
fi

if [[ "$AUTO_FIX" -eq 0 ]]; then
    exit 1
fi

try_auto_fix
collect_lfs_issues
report_issues
