#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"patch failed: {label}: expected text not found")
    return text.replace(old, new, 1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("armsx2_root", type=Path)
    args = parser.parse_args()

    root = args.armsx2_root.resolve()
    cpp = root / "platforms/ios/app/src/main/cpp"
    cmake = cpp / "CMakeLists.txt"
    scene = cpp / "IOS/SceneDelegate.mm"
    bridge = cpp / "ARMSX2Bridge.mm"
    host = cpp / "IOS/HostImpls.mm"

    for path in (cmake, scene, bridge, host):
        if not path.exists():
            raise SystemExit(f"missing ARMSX2 source file: {path}")

    text = cmake.read_text()
    text = text.replace("ARMSX2iOS", "ARMSX2Core")
    text = replace_once(text, "\t\tIOS/AppDelegate.mm\n", "", "remove UIApplicationMain/AppDelegate from embedded target")
    text = replace_once(text, "\tadd_executable(ARMSX2Core ${IOS_RUNTIME_SOURCES} ARMSX2Bridge.mm ${SWIFT_SOURCES})", "\tadd_library(ARMSX2Core SHARED ${IOS_RUNTIME_SOURCES} ARMSX2Bridge.mm ARMSX2EmbeddedRuntime.mm ARMSX2Bridge.h ARMSX2EmbeddedRuntime.h ARMSX2Core.h)", "create framework library target")
    text = replace_once(text, "\tset_source_files_properties(ARMSX2Bridge.mm PROPERTIES COMPILE_FLAGS \"-fobjc-arc\")", "\tset_source_files_properties(ARMSX2Bridge.mm ARMSX2EmbeddedRuntime.mm PROPERTIES COMPILE_FLAGS \"-fobjc-arc -fvisibility=default\")", "enable ARC and export embedded bridge/runtime")
    text = replace_once(text, "\t\tMACOSX_BUNDLE TRUE\n", "\t\tMACOSX_BUNDLE FALSE\n", "disable application bundle")

    anchor = "\t\t\tXCODE_ATTRIBUTE_MTL_ENABLE_DEBUG_INFO \"$<IF:$<CONFIG:Debug>,INCLUDE_SOURCE,>\"\n\t\t)\n"
    framework_props = anchor + """

	set_target_properties(ARMSX2Core PROPERTIES
		FRAMEWORK TRUE
		FRAMEWORK_VERSION A
		MACOSX_FRAMEWORK_IDENTIFIER "com.armsx2.embedded.core"
		OUTPUT_NAME "ARMSX2Core"
		PUBLIC_HEADER "${CMAKE_SOURCE_DIR}/ARMSX2Core.h;${CMAKE_SOURCE_DIR}/ARMSX2Bridge.h;${CMAKE_SOURCE_DIR}/ARMSX2EmbeddedRuntime.h"
		XCODE_ATTRIBUTE_PRODUCT_MODULE_NAME "ARMSX2Core"
		XCODE_ATTRIBUTE_DEFINES_MODULE "YES"
		XCODE_ATTRIBUTE_SKIP_INSTALL "NO"
		XCODE_ATTRIBUTE_INSTALL_PATH "@rpath"
	)
"""
    text = replace_once(text, anchor, framework_props, "framework target properties")
    text = replace_once(text, "\ttarget_compile_definitions(ARMSX2Core PRIVATE\n\t\tPCSX2_NO_PCAP=1", "\ttarget_compile_definitions(ARMSX2Core PRIVATE\n\t\tARMSX2_EMBEDDED_CORE=1\n\t\tPCSX2_NO_PCAP=1", "embedded compile definition")
    cmake.write_text(text)

    text = scene.read_text()
    text = replace_once(text, "    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);\n    NSString *documentsDirectory = [paths objectAtIndex:0];\n    std::string dataRoot = [documentsDirectory UTF8String];", "    const char *embeddedDataRoot = getenv(\"ARMSX2_EMBEDDED_DATA_ROOT\");\n    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);\n    NSString *documentsDirectory = (embeddedDataRoot && embeddedDataRoot[0])\n        ? [NSString stringWithUTF8String:embeddedDataRoot]\n        : [paths objectAtIndex:0];\n    std::string dataRoot = [documentsDirectory UTF8String];", "embedded SceneDelegate data root")
    text = replace_once(text, "    Host::g_sdl_window = SDL_CreateWindow(\"PCSX2 iOS\", 1280, 720, SDL_WINDOW_METAL | SDL_WINDOW_RESIZABLE);", "#if defined(ARMSX2_EMBEDDED_CORE)\n    Host::g_sdl_window = SDL_CreateWindow(\"PCSX2 iOS\", 1280, 720, SDL_WINDOW_METAL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN);\n#else\n    Host::g_sdl_window = SDL_CreateWindow(\"PCSX2 iOS\", 1280, 720, SDL_WINDOW_METAL | SDL_WINDOW_RESIZABLE);\n#endif", "hide SDL host window in embedded mode")
    text = replace_once(text, "        [self.window makeKeyAndVisible];", "#if defined(ARMSX2_EMBEDDED_CORE)\n        self.window.hidden = YES;\n#else\n        [self.window makeKeyAndVisible];\n#endif", "prevent ARMSX2 window takeover")
    text = replace_once(text, "#else\n    // Fallback: no SwiftUI — auto-boot like before\n    if (!EmuConfig.BaseFilenames.Bios.empty() && FileSystem::FileExists(Path::Combine(EmuFolders::Bios, EmuConfig.BaseFilenames.Bios).c_str())) {\n#if TARGET_OS_SIMULATOR\n        [self startVMThread];\n#else\n        [self checkJITAndStartVM];\n#endif\n    } else {\n        Console.Warning(\"No valid BIOS found. Showing selection UI.\");\n    }\n#endif", "#else\n    // The embedded framework is initialized by ManicEMU; never boot merely because a BIOS exists.\n#if !defined(ARMSX2_EMBEDDED_CORE)\n    if (!EmuConfig.BaseFilenames.Bios.empty() && FileSystem::FileExists(Path::Combine(EmuFolders::Bios, EmuConfig.BaseFilenames.Bios).c_str())) {\n#if TARGET_OS_SIMULATOR\n        [self startVMThread];\n#else\n        [self checkJITAndStartVM];\n#endif\n    } else {\n        Console.Warning(\"No valid BIOS found. Showing selection UI.\");\n    }\n#endif\n#endif", "disable fallback auto boot")
    text = replace_once(text, "        [DeepLinkBridge handle:url];", "#if !defined(ARMSX2_EMBEDDED_CORE)\n        [DeepLinkBridge handle:url];\n#endif", "disable embedded deep-link bridge")
    text = replace_once(text, "    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];", "    const char *embeddedDataRoot = getenv(\"ARMSX2_EMBEDDED_DATA_ROOT\");\n    NSString *docs = (embeddedDataRoot && embeddedDataRoot[0])\n        ? [NSString stringWithUTF8String:embeddedDataRoot]\n        : [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];", "embedded BIOS root")
    text = replace_once(text, "    NSString *bundleBios = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@\"BiosFiles\"];", "    const char *embeddedBundlePath = getenv(\"ARMSX2_EMBEDDED_BUNDLE_PATH\");\n    NSBundle *biosBundle = (embeddedBundlePath && embeddedBundlePath[0])\n        ? [NSBundle bundleWithPath:[NSString stringWithUTF8String:embeddedBundlePath]]\n        : [NSBundle mainBundle];\n    NSString *bundleBios = [biosBundle.resourcePath stringByAppendingPathComponent:@\"BiosFiles\"];", "embedded BIOS bundle")
    scene.write_text(text)

    text = bridge.read_text()
    text = replace_once(text, "+ (nonnull NSString *)documentsDirectory {\n    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];\n}", "+ (nonnull NSString *)documentsDirectory {\n    const char *embeddedDataRoot = getenv(\"ARMSX2_EMBEDDED_DATA_ROOT\");\n    if (embeddedDataRoot && embeddedDataRoot[0])\n        return [NSString stringWithUTF8String:embeddedDataRoot];\n    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];\n}", "embedded bridge documents directory")
    bridge.write_text(text)

    text = host.read_text()
    text = replace_once(text, "    std::optional<std::string> GetBundlePath() { return std::string([[NSBundle mainBundle].bundlePath UTF8String]); }", "    std::optional<std::string> GetBundlePath() {\n        const char* embeddedBundlePath = getenv(\"ARMSX2_EMBEDDED_BUNDLE_PATH\");\n        if (embeddedBundlePath && embeddedBundlePath[0])\n            return std::string(embeddedBundlePath);\n        return std::string([[NSBundle mainBundle].bundlePath UTF8String]);\n    }", "embedded CocoaTools bundle path")
    host.write_text(text)

    print("Patched ARMSX2 for embedded ARMSX2Core.framework")


if __name__ == "__main__":
    main()
