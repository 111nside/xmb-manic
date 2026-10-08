# PS Vita native integration — initial implementation plan

Source: [Tsubomi / Vita3K iOS fork](https://github.com/111nside/vitaproj/tree/ios-upstream-core)
Target: XMB Manic (this branch, based on `armsx2-native-integration`).

## Integration constraints
- Integrate Vita3K in-process; do not treat an external app URL as a native core.
- Audit Tsubomi's iOS build outputs, dependency linkage, licenses, entitlements, and its Swift/Obj-C++ to C++ boundary before importing code.
- Reuse the Tsubomi native runtime and Metal/Vulkan translation stack only after checking framework compatibility with Manic's app target.
- Keep Vita's data isolated in an app-owned directory. Provide explicit firmware/game imports from user-owned dumps; never bundle firmware, keys, or games.
- JIT is required for game execution. Report unavailable JIT without crashing.
- Respect app lifecycle, orientation, audio sessions, controller input, touch overlay, and save-data persistence.
- Vita packages and installed-title directories must be treated differently from disc-based games; avoid exposing partial imports as playable games.
- Preserve existing PS2 and other console routing.

## Milestones
1. Inventory Manic's console registry, game model, launch routing, app target, and existing PS2 native bridge.
2. Inventory Tsubomi's iOS entrypoint, core build, dependencies, runtime paths, and license requirements.
3. Build an isolated Vita runtime adapter and link the necessary native components into Manic.
4. Add Vita console registration, title scanning, install/import UI, firmware management, and game details.
5. Connect launch/exit, controller/touch mapping, logs, and lifecycle handling.
6. Run iOS CI build, fix compile/link failures, and validate a homebrew Vita title on device.

## Current status
Branch and integration plan created. **No Vita runtime has been imported or linked yet; no build has been run.**

## Source audit (2026-10-07)
The authoritative `vitaproj/ios/README.md` explicitly says the iOS implementation is a **bootstrap**, not a working general-purpose Vita emulator. It contains a narrow interpreter, installed-title inventory, ZIP/VPK transaction installer, SFO parser, SELF preparation, core-owned Metal diagnostic frame, and host input capture. It does not provide general game execution, guest GXM rendering, Vita input HLE, production CPU scheduling, or full Vita HLE. The desktop Vita3K runtime cannot be directly linked to iOS without porting its platform-specific dependencies.

Therefore:
- Do not advertise Vita games as playable or mark a Vita core as ready merely because a library or framework links.
- First integrate the reusable metadata/import and UI-facing facilities, preserving the experimental status.
- Define an adapter boundary with explicit capabilities: `scanInstalledTitles`, `importPackage`, `prepareExecutable`, `runDiagnostic`, `isGameExecutionSupported` (currently false), `shutdown`.
- A future game launch route must fail safely with an informative unsupported message until guest execution and rendering are actually implemented and tested.
- Any native integration must be tested by a macOS Xcode build and on-device diagnostics before a claim of successful runtime integration.

### Evidence
- https://github.com/111nside/vitaproj/blob/ios-upstream-core/ios/README.md
- https://github.com/111nside/vitaproj/blob/ios-upstream-core/CMakeLists.txt

### Audit status
Source capability audit completed; native source copying, project linking, compilation, and on-device validation remain pending.
