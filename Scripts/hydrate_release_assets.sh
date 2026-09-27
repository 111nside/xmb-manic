#!/usr/bin/env bash
set -euo pipefail
TAG="${MANIC_RELEASE_TAG:-v2.0.1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${RUNNER_TEMP:-/tmp}/manic-release-assets"
rm -rf "$TMP" && mkdir -p "$TMP/downloads" "$TMP/extracted"
API="https://api.github.com/repos/Manic-EMU/ManicEMU/releases/tags/$TAG"
echo "Fetching official ManicEMU $TAG release metadata..."
curl -fsSL -H 'Accept: application/vnd.github+json' "$API" > "$TMP/release.json"
python3 - "$TMP/release.json" "$TMP/downloads" <<'PY'
import json,sys,urllib.request,os
meta=json.load(open(sys.argv[1])); out=sys.argv[2]
assets=meta.get('assets',[])
if not assets: raise SystemExit('No release assets were returned by GitHub.')
print('Release assets:')
for a in assets:
    print(' -',a['name'],a.get('size',0),'bytes')
    req=urllib.request.Request(a['browser_download_url'],headers={'User-Agent':'xmb-manic-ci'})
    with urllib.request.urlopen(req) as r, open(os.path.join(out,a['name']),'wb') as f:
        while True:
            b=r.read(1024*1024)
            if not b: break
            f.write(b)
PY
# Extract every ZIP-compatible asset (IPA files are ZIPs too).
for f in "$TMP"/downloads/*; do
  d="$TMP/extracted/$(basename "$f")"; mkdir -p "$d"
  if unzip -tqq "$f" >/dev/null 2>&1; then unzip -q "$f" -d "$d"; fi
done
python3 - "$ROOT" "$TMP/extracted" <<'PY'
import os,sys,shutil
root,ext=sys.argv[1:]
def pointer(p):
    try:
        b=open(p,'rb').read(200)
        return b.startswith(b'version https://git-lfs.github.com/spec/v1')
    except: return False
# Index extracted files by basename, and frameworks by directory name.
files={}; frameworks={}
for dp,dns,fns in os.walk(ext):
    for d in dns:
        if d.endswith('.framework'): frameworks.setdefault(d,[]).append(os.path.join(dp,d))
    for f in fns: files.setdefault(f,[]).append(os.path.join(dp,f))
replaced=[]
# Prefer whole framework replacement when an official release asset contains it.
cores=os.path.join(root,'Cores')
if os.path.isdir(cores):
    for name in os.listdir(cores):
        dst=os.path.join(cores,name)
        if name.endswith('.framework') and len(frameworks.get(name,[]))==1:
            src=frameworks[name][0]
            shutil.rmtree(dst,ignore_errors=True); shutil.copytree(src,dst,symlinks=True)
            replaced.append(dst)
# Fill remaining pointer files when the release has one unambiguous same-named file.
for dp,_,fns in os.walk(root):
    if '/.git/' in dp.replace('\\','/'): continue
    for f in fns:
        dst=os.path.join(dp,f)
        if pointer(dst) and len(files.get(f,[]))==1:
            shutil.copy2(files[f][0],dst); replaced.append(dst)
remaining=[]
for dp,_,fns in os.walk(root):
    for f in fns:
        p=os.path.join(dp,f)
        if pointer(p): remaining.append(os.path.relpath(p,root))
print(f'Hydrated {len(replaced)} files/frameworks from official release assets.')
if remaining:
    print(f'WARNING: {len(remaining)} LFS pointer files remain. First 30:')
    print('\n'.join(' - '+x for x in remaining[:30]))
    open(os.path.join(root,'remaining-lfs-pointers.txt'),'w').write('\n'.join(remaining)+'\n')
else:
    print('All detected LFS pointer files were hydrated.')
PY
