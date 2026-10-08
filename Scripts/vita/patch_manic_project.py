#!/usr/bin/env python3
"""Wire the Vita3K dynamic framework into the ManicEmuSideload Xcode target.

The checked-in Xcode project is large and shared with other targets, so this
is a narrow, idempotent CI patch. It never changes tvOS or the stock iOS app.
"""
from pathlib import Path
import re

PROJECT = Path("ManicEmu/ManicEmu.xcodeproj/project.pbxproj")
SOURCE = Path("ManicEmu/ManicEmu/Sources/Tools/Cores/ManicVitaBridge.swift")
FRAMEWORK = Path("Cores/Vita3KManicRuntime.framework/Vita3KManicRuntime")
FILE_ID = "A3F193C0978A4E8FAD071001"
BUILD_ID = "A3F193C0978A4E8FAD071002"

if not SOURCE.is_file():
    raise SystemExit("Missing ManicVitaBridge.swift")
if not FRAMEWORK.is_file():
    raise SystemExit("Missing linked Vita3KManicRuntime.framework")
project = PROJECT.read_text()
original = project

def insert_once(before: str, addition: str) -> None:
    global project
    if addition in project:
        return
    if project.count(before) != 1:
        raise SystemExit(f"Cannot locate unique Xcode insertion point: {before[:90]}")
    project = project.replace(before, addition + before, 1)

insert_once(
    "/* End PBXBuildFile section */",
    f"\t\t{BUILD_ID} /* ManicVitaBridge.swift in Sources */ = "
    f"{{isa = PBXBuildFile; fileRef = {FILE_ID} /* ManicVitaBridge.swift */; }};\n"
)
insert_once(
    "/* End PBXFileReference section */",
    f"\t\t{FILE_ID} /* ManicVitaBridge.swift */ = "
    '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
    'path = ManicVitaBridge.swift; sourceTree = "<group>"; };\n'
)

# Place the file in the existing Sources/Tools/Cores group next to PSP.swift.
needle = "\t\t\t\t57BFBE8F2DD435C700AABF98 /* PSP.swift */,"
addition = f"\n\t\t\t\t{FILE_ID} /* ManicVitaBridge.swift */,"
if addition.strip() not in project:
    if project.count(needle) != 1:
        raise SystemExit("Could not locate Cores group")
    project = project.replace(needle, needle + addition, 1)

# The Sideload app has its own PBXSourcesBuildPhase.
phase_start = project.find("57909384303C7D9100A53656 /* Sources */ = {")
phase_end = project.find("\n\t\t};", phase_start)
if min(phase_start, phase_end) < 0:
    raise SystemExit("Missing ManicEmuSideload Sources phase")
phase = project[phase_start:phase_end]
line = f"\t\t\t\t{BUILD_ID} /* ManicVitaBridge.swift in Sources */,"
if line not in phase:
    marker = "\t\t\t\t579093DE303C7D9100A53656 /* PSP.swift in Sources */,"
    if marker not in phase:
        raise SystemExit("Could not locate PSP source in Sideload phase")
    project = project[:phase_start] + phase.replace(marker, marker + "\n" + line, 1) + project[phase_end:]

# Apply only to the three build configurations of ManicEmuSideload.
configuration_ids = (
    "57909588303C7D9100A53656",
    "57909589303C7D9100A53656",
    "5790958A303C7D9100A53656",
)
for identifier in configuration_ids:
    start = project.find(f"{identifier} /* ", project.index("/* Begin XCBuildConfiguration section */"))
    end = project.find("\n\t\t};", start)
    if min(start, end) < 0:
        raise SystemExit(f"Missing Sideload configuration {identifier}")
    section = project[start:end]
    # The additional search path is needed both for Swift's framework import
    # and for ld's -framework resolution.
    section, count = re.subn(
        r'FRAMEWORK_SEARCH_PATHS = "\$\(inherited\)";',
        'FRAMEWORK_SEARCH_PATHS = ("$(inherited)", "$(SRCROOT)/../Cores");',
        section,
        count=1,
    )
    if not count and "$(SRCROOT)/../Cores" not in section:
        raise SystemExit(f"No framework search path in {identifier}")
    if "Vita3KManicRuntime" not in section:
        old = 'OTHER_LDFLAGS = "$(inherited)";'
        if old in section:
            section = section.replace(
                old,
                'OTHER_LDFLAGS = ("$(inherited)", "-framework", Vita3KManicRuntime);',
                1,
            )
        else:
            # SideloadRelease already adds ARMSX2Core.
            marker = "\t\t\t\t\tARMSX2Core,"
            if marker not in section:
                raise SystemExit(f"No expected linker flags in {identifier}")
            section = section.replace(
                marker, marker + '\n\t\t\t\t\t"-framework",\n\t\t\t\t\tVita3KManicRuntime,', 1
            )
    section = re.sub(
        r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = 26.0;",
        section,
    )
    project = project[:start] + section + project[end:]

if project != original:
    PROJECT.write_text(project)
    print("Updated ManicEmuSideload: Vita Swift bridge + linked Vita3KManicRuntime")
else:
    print("Manic Vita Xcode project integration already applied")
