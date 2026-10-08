#!/usr/bin/env bash
# Compile the real Vita3K upstream core as a native iOS dynamic framework.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VITA="$ROOT/Vendor/Tsubomi"
OUT="$ROOT/Cores/Vita3KManicRuntime.framework"
DEPS="${VITA_BUILD_DEPS:-${RUNNER_TEMP:-$ROOT/.build-vita}/vita-deps}"
BUILD="${VITA_BUILD_DIR:-${RUNNER_TEMP:-$ROOT/.build-vita}/vita-build}"
mkdir -p "$DEPS" "$BUILD"
test -f "$VITA/ios/src/ManicRuntime.cpp" || {
  echo "Missing pinned Manic Vita3K runtime source. Run git submodule update --init --recursive." >&2
  exit 1
}

# Identical patch to the verified standalone upstream-core build. Patch is
# necessary to handle executable JIT mappings with iOS' debugger attachment.
PATCH="ios/patches/0001-oaknut-ios-rwx-jit.patch"
if git -C "$VITA" apply --check --directory=external/dynarmic "$PATCH" 2>/dev/null; then
  git -C "$VITA" apply --directory=external/dynarmic "$PATCH"
elif git -C "$VITA" apply --reverse --check --directory=external/dynarmic "$PATCH" 2>/dev/null; then
  echo "Vita3K iOS Dynarmic patch already applied"
else
  echo "Unable to apply or verify required Dynarmic iOS JIT patch" >&2
  exit 1
fi

VCPKG="$DEPS/vcpkg"
if [ ! -d "$VCPKG/.git" ]; then
  git clone --filter=blob:none https://github.com/microsoft/vcpkg.git "$VCPKG"
fi
git -C "$VCPKG" fetch --depth=1 origin 77df67cfff9c12ccfdb52284e07c87c75092f723
git -C "$VCPKG" checkout --detach 77df67cfff9c12ccfdb52284e07c87c75092f723
"$VCPKG/bootstrap-vcpkg.sh" -disableMetrics

MVK="$DEPS/moltenvk/MoltenVK/MoltenVK"
if [ ! -f "$MVK/static/MoltenVK.xcframework/ios-arm64/libMoltenVK.a" ]; then
  mkdir -p "$DEPS/moltenvk"
  curl --fail --location --retry 3 \
    --output "$DEPS/MoltenVK-ios.tar" \
    https://github.com/KhronosGroup/MoltenVK/releases/download/v1.4.1/MoltenVK-ios.tar
  echo "54336b90212c390ed5935c96460aed3bf651ad7d3c0f0e956586ce18e9c0b701  $DEPS/MoltenVK-ios.tar" | shasum -a 256 --check
  tar -xf "$DEPS/MoltenVK-ios.tar" -C "$DEPS/moltenvk"
fi

cmake -S "$VITA" -B "$BUILD" -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG/scripts/buildsystems/vcpkg.cmake" \
  -DVCPKG_TARGET_TRIPLET=arm64-ios \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
  -DVITA3K_BUILD_IOS_UPSTREAM_CORE=ON \
  -DVITA3K_BUILD_IOS=OFF \
  -DVITA3K_BUILD_MANIC_EMBEDDED=ON \
  -DVITA3K_IOS_DEPLOYMENT_TARGET=26.0 \
  -DVITA3K_IOS_LINK_CORE=ON \
  -DVITA3K_IOS_BUNDLE_ID=org.xmbmanic.vita3k.runtime \
  -DVITA3K_IOS_MOLTENVK_LIBRARY="$MVK/static/MoltenVK.xcframework/ios-arm64/libMoltenVK.a" \
  -DVITA3K_IOS_MOLTENVK_INCLUDE_DIR="$MVK/include" \
  -DVITA3K_FORCE_SYSTEM_BOOST=ON \
  -DUSE_DISCORD_RICH_PRESENCE=OFF \
  -DUSE_VITA3K_UPDATE=OFF \
  -DUSE_LTO=NEVER

cmake --build "$BUILD" --config Release --target Vita3KManicRuntime -- \
  -sdk iphoneos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

FRAMEWORK="$(find "$BUILD" -type d -name Vita3KManicRuntime.framework -print -quit)"
test -n "$FRAMEWORK" && test -f "$FRAMEWORK/Vita3KManicRuntime" || {
  echo "Missing linked Vita3KManicRuntime.framework output" >&2
  exit 1
}
mkdir -p "$(dirname "$OUT")"
rm -rf "$OUT"
ditto "$FRAMEWORK" "$OUT"
nm -gU "$OUT/Vita3KManicRuntime" | grep -q '_manic_vita3k_run'
nm -gU "$OUT/Vita3KManicRuntime" | grep -q '_manic_vita3k_request_exit'
test -f "$OUT/Headers/ManicRuntime.h"
otool -L "$OUT/Vita3KManicRuntime"
echo "Built and linked: $OUT"
