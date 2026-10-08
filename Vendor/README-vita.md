# Tsubomi source dependency

The `Vendor/Tsubomi` git submodule pins `111nside/vitaproj` to commit `41e393f72860f8bbe526f4fd235166dcf787598b`, the upstream-core iOS build from Actions run 37538651779.

Fetch the source (including its nested dependencies) with:

```sh
git submodule update --init --recursive Vendor/Tsubomi
```

**Source import only:** the Vita runtime is not yet linked to the Manic iOS app. `Vendor/Tsubomi` has its own CMake build and SDL3-driven UIApplication lifecycle. Do not add its `main`/`UpstreamMain.cpp` to Manic's target as-is, since this would create duplicate app entrypoints. First extract the upstream core into a framework/static library with a callable session lifecycle, and connect it to Manic through an Objective-C++ bridge. Preserve Vita3K's existing native dependencies and license obligations. Then validate compilation on macOS/Xcode and test on device. The existing Tsubomi IPA's successful build does not prove Manic integration builds.
