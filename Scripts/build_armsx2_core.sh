#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-ThirdParty/ARMSX2}"
ROOT="$(cd "$ROOT" && pwd)"
CPP="$ROOT/platforms/ios/app/src/main/cpp"
BUILD="${ARMSX2_BUILD_DIR:-$RUNNER_TEMP/armsx2-core-build}"
OUTPUT="${ARMSX2_OUTPUT_DIR:-Cores}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$BUILD" "$OUTPUT"

if command -v rustup >/dev/null 2>&1; then
  rustup target add aarch64-apple-ios
fi

cp "$SCRIPT_DIR/armsx2/ARMSX2Core.h" "$CPP/ARMSX2Core.h"
cp "$SCRIPT_DIR/armsx2/ARMSX2EmbeddedRuntime.h" "$CPP/ARMSX2EmbeddedRuntime.h"
cp "$SCRIPT_DIR/armsx2/ARMSX2EmbeddedRuntime.mm" "$CPP/ARMSX2EmbeddedRuntime.mm"
python3 "$SCRIPT_DIR/patch_armsx2_embedded.py" "$ROOT"

cmake -S "$CPP" -B "$BUILD" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_XCODE_GENERATE_SCHEME=ON \
  -DARMSX2_REAL_DEVICE=ON \
  -DARMSX2_ENABLE_JIT_ENTITLEMENTS=OFF \
  -DARMSX2_IOS_DEPLOYMENT_TARGET=17.4 \
  -DLTO_PCSX2_CORE=OFF

PROJECT=$(find "$BUILD" -maxdepth 1 -name '*.xcodeproj' -print -quit)
if [[ -z "$PROJECT" ]]; then
  echo "error: ARMSX2 generated Xcode project not found" >&2
  exit 1
fi

echo "Generated ARMSX2 project: $PROJECT"
xcodebuild -project "$PROJECT" -list

set -o pipefail
xcodebuild \
  -project "$PROJECT" \
  -scheme ARMSX2Core \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= \
  build | tee "$RUNNER_TEMP/armsx2-xcodebuild.log"

FRAMEWORK=$(find "$BUILD/DerivedData/Build/Products" "$BUILD" -type d -name 'ARMSX2Core.framework' -print -quit)
if [[ -z "$FRAMEWORK" ]]; then
  echo "error: ARMSX2Core.framework was not produced" >&2
  find "$BUILD" -maxdepth 5 -type d -name '*.framework' -print || true
  exit 1
fi

rm -rf "$OUTPUT/ARMSX2Core.framework"
ditto "$FRAMEWORK" "$OUTPUT/ARMSX2Core.framework"

echo "Embedded core framework:"
du -sh "$OUTPUT/ARMSX2Core.framework"
find "$OUTPUT/ARMSX2Core.framework" -maxdepth 2 -type f -print | head -80

echo "ARMSX2Core exported symbols of interest:"
nm -gU "$OUTPUT/ARMSX2Core.framework/ARMSX2Core" 2>/dev/null | grep -E 'ARMSX2Bridge|ARMSX2EmbeddedRuntime|PCSX2SceneDelegate' | head -80 || true
