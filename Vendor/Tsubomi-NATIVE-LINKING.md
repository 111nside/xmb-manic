# Native Vita3K linking boundary

The pinned `Vendor/Tsubomi` revision **does build a complete standalone iOS IPA**. It is not yet a reusable library. Its `ios/CMakeLists.txt` defines `Vita3KiOS` as `add_executable(... MACOSX_BUNDLE ...)`, and includes `src/UpstreamMain.cpp`, `src/NativeFrontend.mm`, `src/TsubomiBridge.mm` and its own SDL3-driven UIKit lifecycle.

**Do not link that executable or copy its app entrypoint into Manic.** A successful source checkout or an Xcode linker flag is not a functional integration.

## Required native refactor

1. In the vendored upstream source (on a new integration branch), split `UpstreamMain.cpp` into a callable session runner and a thin standalone `main`. Move game initialization, the frontend action pump, and shutdown into a library function. Keep the standalone IPA working.
2. Export a stable Objective-C facade or C ABI for initialization, installed title enumeration, title launch, shutdown, and frame presentation. Make ownership and threading explicit; `TsubomiBridge` currently relies on the standalone frontend's globals and startup.
3. Make a `vita3k_ios_runtime` static library target containing the session runner, `NativeFrontend.mm`, `TsubomiBridge.mm`, `VirtualController.mm`, and necessary Swift/ObjC host components, **excluding** `main` and `UpstreamMain.cpp`'s SDL entrypoint.
4. Link the runtime's transitive `vita3k`, `audio`, `io`, `miniz`, `np`, `packages`, SDL3, MoltenVK/Vulkan, and platform frameworks in Manic's iOS target. Bundle `shaders-builtin` and other runtime resources.
5. Resolve SDL3 window/renderer ownership against Manic's existing UIKit/Metal hierarchy, and integrate app foreground/background lifecycle. UIKit has only one application entrypoint.
6. Replace the reflection-based `ManicVitaBridge.swift` adapter with direct, compile-checked access to the exported facade; connect Manic's game type, game launch, controller mapping and firmware UI.
7. Build in macOS/Xcode CI and run a device smoke test for boot, graphics, audio, JIT, touch, external controller, exit/re-enter, and save persistence.

## Source pin

GitHub Actions run: https://github.com/111nside/vitaproj/actions/runs/37538651779

Commit: `41e393f72860f8bbe526f4fd235166dcf787598b`

`git submodule update --init --recursive` fetches this source but **does not** link the runtime.

## Current status

Source is vendored; a Manic-side Swift facade exists. Native Vita3K runtime is **not** linked and Vita gameplay inside Manic is **not** verified. This document is an implementation checklist, not a claim that linking is finished.
