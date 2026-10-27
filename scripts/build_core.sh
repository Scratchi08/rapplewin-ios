#!/usr/bin/env bash
# Builds the AppleWin libretro core (audetto/AppleWin Linux/libretro port) for iOS.
# STATUS: configure stage. Upstream AppleWin/AppleWin is Windows-only; the portable
# core lives in audetto/AppleWin. Dependencies will need iOS cross-builds/stubs.
set -euo pipefail

for t in cmake ninja git xcrun xcodebuild; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t"; exit 1; }
done
xcrun --sdk iphoneos --show-sdk-path >/dev/null || { echo "iOS SDK not found"; exit 1; }
cmake --version | head -1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/Core" && cd "$ROOT/Core"

# rcheevos (RetroAchievements runtime): compiled straight into the app by project.yml
[ -d rcheevos/.git ] || git clone --depth 1 https://github.com/RetroAchievements/rcheevos.git
git -C rcheevos log -1 --format='rcheevos %H %ad %s'
echo "=== rcheevos sources ==="
find rcheevos/src -name '*.c' | sort

# Replace any earlier (wrong) checkout of the Windows-only upstream
if [ -d AppleWin ] && ! git -C AppleWin remote get-url origin 2>/dev/null | grep -q audetto; then
  rm -rf AppleWin
fi
[ -d AppleWin ] || git clone --recursive https://github.com/audetto/AppleWin.git
cd AppleWin

echo "=== checkout ==="
git log -1 --format='%H %ad %s'
git submodule status || true
echo "=== libretro frontend dir ==="
ls source/frontends/libretro | head -40
ls source/frontends/libretro/libretro-common/include/libretro.h
echo "=== dependency hints (find_package / pkg_check) ==="
grep -rn --include=CMakeLists.txt --include=*.cmake -E 'find_package|pkg_check_modules|PkgConfig' . 2>/dev/null \
  | grep -v '^./\(libyaml\|minizip\|zlib\|spng\)/' | head -40 || true

# The core is declared SHARED; iOS needs a static library.
sed -i.bak 's/add_library(applewin_libretro SHARED/add_library(applewin_libretro STATIC/' \
  source/frontends/libretro/CMakeLists.txt
grep -n 'add_library(applewin_libretro' source/frontends/libretro/CMakeLists.txt

SDK=iphoneos
OUT="$(pwd)/../build/$SDK"; mkdir -p "$OUT"
cmake -S . -B "build-$SDK" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=$SDK \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_LIBRETRO=ON -DBUILD_SA2=OFF -DBUILD_QAPPLE=OFF -DBUILD_APPLEN=OFF

cmake --build "build-$SDK" --target applewin_libretro

# libretro core + appleii/common2/windows etc. are separate static libs: merge into one.
LIBS=$(find "build-$SDK" -name '*.a')
echo "$LIBS"
libtool -static -o "$OUT/libapplewin_libretro.a" $LIBS
ls -la "$OUT"
