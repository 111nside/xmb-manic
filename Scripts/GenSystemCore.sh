#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/System.core"
OUT_FILE="$PROJECT_ROOT/ManicEmu/ManicEmu/Resources/System.core"
VER_FILE="$SCRIPT_DIR/System.core.ver"

is_debug_build() {
    [[ "${CONFIGURATION:-}" == "Debug" || "${TARGET_NAME:-}" == "ManicEmuDebug" ]]
}

is_release_target() {
    [[ "${TARGET_NAME:-}" == "ManicEmuRelease" ]]
}

compute_metadata_fingerprint() {
    find "$SRC_DIR" -type f ! -name '.DS_Store' -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 stat -f '%m %z %N' \
        | LC_ALL=C sort \
        | while IFS= read -r line; do
            mtime="${line%% *}"
            rest="${line#* }"
            size="${rest%% *}"
            file_path="${rest#* }"
            rel_path="${file_path#"$SRC_DIR"/}"
            printf '%s:%s:%s\n' "$rel_path" "$mtime" "$size"
        done | md5 -q
}

compute_content_fingerprint() {
    find "$SRC_DIR" -type f ! -name '.DS_Store' | LC_ALL=C sort | while IFS= read -r file_path; do
        rel_path="${file_path#"$SRC_DIR"/}"
        printf '%s:' "$rel_path"
        md5 -q "$file_path"
    done | md5 -q
}

read_ver_file() {
    stored_mtime=""
    stored_content=""
    if [[ ! -f "$VER_FILE" ]]; then
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(tr -d '[:space:]' <<< "$line")"
        [[ -z "$line" ]] && continue
        case "$line" in
            mtime:*) stored_mtime="${line#mtime:}" ;;
            content:*) stored_content="${line#content:}" ;;
            *)
                if [[ -z "$stored_content" ]]; then
                    stored_content="$line"
                fi
                ;;
        esac
    done < "$VER_FILE"
}

write_ver_file() {
    {
        printf 'mtime:%s\n' "$1"
        printf 'content:%s\n' "$2"
    } > "$VER_FILE"
}

if [[ ! -d "$SRC_DIR" ]]; then
    echo "error: System.core source directory not found at $SRC_DIR" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"
read_ver_file

if is_debug_build; then
    current_mtime="$(compute_metadata_fingerprint)"
    if [[ -n "$stored_mtime" && "$current_mtime" == "$stored_mtime" && -f "$OUT_FILE" ]]; then
        echo "Gen System.core: up to date (metadata)"
        exit 0
    fi
    if [[ -z "$stored_mtime" ]]; then
        echo "Gen System.core: metadata check skipped (no cached metadata)"
    else
        echo "Gen System.core: metadata changed, verifying content..."
    fi
fi

current_content="$(compute_content_fingerprint)"

# Release always recompresses: the zip omits fbneo, but fingerprints still cover the full tree,
# so a Debug-built System.core would otherwise be reused as "up to date".
if is_release_target; then
    echo "Gen System.core: ManicEmuRelease always recompresses"
elif [[ -n "$stored_content" && "$current_content" == "$stored_content" && -f "$OUT_FILE" ]]; then
    write_ver_file "${current_mtime:-$(compute_metadata_fingerprint)}" "$current_content"
    echo "Gen System.core: up to date (content)"
    exit 0
fi

echo "Gen System.core: compressing source files..."
tmp_zip="$(mktemp -u "${TMPDIR:-/tmp}/System.core.XXXXXX")"
cleanup() { rm -f "$tmp_zip"; }
trap cleanup EXIT

zip_args=(-9 -q -r "$tmp_zip" . -x "*.DS_Store" -x "*/.DS_Store")
if is_release_target; then
    echo "Gen System.core: excluding Libretro/system/fbneo"
    zip_args+=(-x "Libretro/system/fbneo/*")
fi

(
    cd "$SRC_DIR"
    zip "${zip_args[@]}"
)

mv -f "$tmp_zip" "$OUT_FILE"
trap - EXIT

if is_release_target; then
    # Drop the fingerprint cache so the next Debug/Sideload build recompresses with fbneo.
    rm -f "$VER_FILE"
    echo "Gen System.core: wrote $OUT_FILE (cache invalidated)"
else
    write_ver_file "$(compute_metadata_fingerprint)" "$current_content"
    echo "Gen System.core: wrote $OUT_FILE"
fi
