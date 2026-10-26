#!/usr/bin/env bash
# Builds AppleWin's libretro core as a static library for iOS (macOS only).
# STATUS: discovery stage. Prints the repo layout so we can find the right CMake root.
set -euo pipefail

for t in cmake ninja git xcrun xcodebuild; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t"; exit 1; }
done
xcrun --sdk iphoneos --show-sdk-path >/dev/null || { echo "iOS SDK not found"; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/Core" && cd "$ROOT/Core"

# Re-clone if a previous attempt left a broken/partial copy
if [ -d AppleWin ] && [ ! -d AppleWin/.git ]; then rm -rf AppleWin; fi
[ -d AppleWin ] || git clone --recurse-submodules https://github.com/AppleWin/AppleWin.git
cd AppleWin

echo "=== AppleWin checkout ==="
git branch --show-current || true
git log -1 --format='%H %ad %s' || true
git submodule status || true
echo "=== Top-level contents ==="
ls -la
echo "=== CMakeLists.txt files (depth <= 4) ==="
find . -maxdepth 4 -name CMakeLists.txt -not -path './.git/*' | sort
echo "=== libretro-related paths ==="
find . -maxdepth 5 -ipath '*libretro*' -not -path './.git/*' | head -40
echo "=== Linux build docs ==="
find . -maxdepth 4 \( -iname 'README*' -o -iname '*.md' \) -not -path './.git/*' | head -30

if [ ! -f CMakeLists.txt ]; then
  echo
  echo "STOP: no CMakeLists.txt at the repo root. Send me the listing above."
  exit 1
fi

for SDK in iphoneos iphonesimulator; do
  OUT="$(pwd)/../build/$SDK"; mkdir -p "$OUT"
  cmake -S . -B "build-$SDK" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=$SDK \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
    -DBUILD_LIBRETRO=ON -DBUILD_SA2=OFF -DBUILD_QAPPLE=OFF \
    -DBUILD_SHARED_LIBS=OFF
  cmake --build "build-$SDK" --target applewin_libretro
  find "build-$SDK" -name '*applewin_libretro*.a' -exec cp {} "$OUT/libapplewin_libretro.a" \;
done
