# XMB Manic v0.3 — Windows / GitHub Actions

This package does not ask Git LFS to download upstream core files. The workflow downloads the official ManicEMU v2.0.1 release assets on the macOS runner and uses them to hydrate the source tree before compiling.

## IMPORTANT for an existing local repo
Your earlier commit already contains Git LFS pointers, so disable the local LFS pre-push hook before pushing this replacement tree:

    git lfs uninstall

Copy/replace the v0.3 files into the repo, then:

    git add -A
    git commit -m "Use release assets for CI build"
    git push -u origin main

If Git still attempts an LFS upload, create a fresh local Git history from this v0.3 folder instead of reusing the old .git directory.

## Build
GitHub > Actions > Build XMB Manic iOS > Run workflow.

If hydration cannot reconstruct every build-time file, the job stops before Xcode and uploads `Remaining-LFS-pointers`. Send that artifact back; it identifies exactly which upstream files are still unavailable from the official release.
