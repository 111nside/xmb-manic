#!/usr/bin/env bash
set -euo pipefail

TAG="${MANIC_RELEASE_TAG:-v2.0.1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${RUNNER_TEMP:-/tmp}/manic-release-assets"

rm -rf "$TMP"
mkdir -p "$TMP/downloads" "$TMP/extracted"

API="https://api.github.com/repos/Manic-EMU/ManicEMU/releases/tags/$TAG"

echo "Fetching official ManicEMU $TAG release metadata..."

curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "User-Agent: xmb-manic-actions" \
  "$API" > "$TMP/release.json"

echo "Downloading release assets..."

python3 - "$TMP/release.json" "$TMP/downloads" <<'PY'
import json
import os
import sys
import urllib.request

meta_path = sys.argv[1]
out_dir = sys.argv[2]

with open(meta_path, "r") as f:
    meta = json.load(f)

assets = meta.get("assets", [])

if not assets:
    raise SystemExit("No release assets were returned by GitHub.")

print("Release assets:")

for asset in assets:
    name = asset["name"]
    url = asset["browser_download_url"]

    print(" -", name, asset.get("size", 0), "bytes")

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "xmb-manic-ci"}
    )

    output = os.path.join(out_dir, name)

    with urllib.request.urlopen(req) as r, open(output, "wb") as f:
        while True:
            chunk = r.read(1024 * 1024)

            if not chunk:
                break

            f.write(chunk)
PY

echo "Extracting release assets..."

for f in "$TMP"/downloads/*; do
  d="$TMP/extracted/$(basename "$f")"
  mkdir -p "$d"

  if unzip -tqq "$f" >/dev/null 2>&1; then
    unzip -q "$f" -d "$d"
  fi
done

echo "Hydrating LFS files..."

python3 - "$ROOT" "$TMP/extracted" <<'PY'
import os
import shutil
import sys

root, ext = sys.argv[1:]


def pointer(path):
    try:
        with open(path, "rb") as f:
            data = f.read(200)

        return data.startswith(
            b"version https://git-lfs.github.com/spec/v1"
        )
    except Exception:
        return False


files = {}
frameworks = {}

for dp, dns, fns in os.walk(ext):
    for d in dns:
        if d.endswith(".framework"):
            frameworks.setdefault(d, []).append(
                os.path.join(dp, d)
            )

    for f in fns:
        files.setdefault(f, []).append(
            os.path.join(dp, f)
        )


replaced = []

cores = os.path.join(root, "Cores")

if os.path.isdir(cores):
    for name in os.listdir(cores):

        if not name.endswith(".framework"):
            continue

        dst = os.path.join(cores, name)
        candidates = frameworks.get(name, [])

        if not candidates:
            continue

        src = None

        for candidate in candidates:
            binary_name = name.removesuffix(".framework")
            binary = os.path.join(candidate, binary_name)

            if (
                os.path.isfile(binary)
                and not pointer(binary)
                and os.path.getsize(binary) > 1000
            ):
                src = candidate
                break

        if src:
            shutil.rmtree(dst, ignore_errors=True)

            shutil.copytree(
                src,
                dst,
                symlinks=True
            )

            replaced.append(dst)

            print(
                "Hydrated framework:",
                name
            )


for dp, _, fns in os.walk(root):

    if "/.git/" in dp.replace("\\", "/"):
        continue

    for f in fns:
        dst = os.path.join(dp, f)

        if not pointer(dst):
            continue

        candidates = files.get(f, [])

        real_candidates = [
            candidate
            for candidate in candidates
            if os.path.isfile(candidate)
            and not pointer(candidate)
            and os.path.getsize(candidate) > 100
        ]

        if len(real_candidates) == 1:
            shutil.copy2(
                real_candidates[0],
                dst
            )

            replaced.append(dst)


remaining = []

for dp, _, fns in os.walk(root):

    if "/.git/" in dp.replace("\\", "/"):
        continue

    for f in fns:
        p = os.path.join(dp, f)

        if pointer(p):
            remaining.append(
                os.path.relpath(p, root)
            )


print(
    f"Hydrated {len(replaced)} files/frameworks "
    "from official release assets."
)

remaining_file = os.path.join(
    root,
    "remaining-lfs-pointers.txt"
)

if remaining:
    print(
        f"ERROR: {len(remaining)} "
        "LFS pointer files remain. First 30:"
    )

    print(
        "\n".join(
            " - " + x
            for x in remaining[:30]
        )
    )

    with open(remaining_file, "w") as f:
        f.write(
            "\n".join(remaining) + "\n"
        )

else:
    print("All detected LFS pointer files were hydrated.")

    if os.path.exists(remaining_file):
        os.remove(remaining_file)
PY