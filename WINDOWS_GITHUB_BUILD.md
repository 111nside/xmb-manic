# Building ManicEMU-XMB from Windows with GitHub Actions

This repository includes `.github/workflows/build-ios.yml`. GitHub runs the Xcode build on a hosted Mac, so Xcode does not need to run on your Windows PC.

## First-time setup

1. Create a GitHub repository for your fork.
2. Upload/push **the contents of this folder** to the repository. Keep `.github/workflows/build-ios.yml` in the same path.
3. Make sure Git LFS files are uploaded. If you use Git from Windows, install Git LFS and run `git lfs install` before pushing.
4. On GitHub, open **Actions** → **Build XMB Manic iOS** → **Run workflow**.
5. Open the finished workflow run. Under **Artifacts**, download **ManicEMU-XMB-unsigned-IPA**.

## Important: unsigned means not ready to install directly

The workflow deliberately disables Apple code signing so no Apple certificate/password has to be stored in GitHub. The resulting IPA is useful for sideloading workflows that sign the app for you, or as proof that the source compiles.

If the build fails, download the **Xcode-build-log** artifact. The last compiler errors in that file are the useful part to share when troubleshooting.

## Why the Sideload scheme?

The upstream project already includes the shared `ManicEmuSideload` Xcode scheme and `SideloadRelease` configuration, so the workflow builds that target rather than the App Store target.
