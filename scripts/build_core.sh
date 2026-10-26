#!/usr/bin/env bash
# Builds AppleWin's libretro core as a static library for iOS. Run on macOS.
# STATUS: scaffold. The AppleWin Linux/libretro CMake build has dependencies
# (boost, libyaml, minizip, zlib, optionally libpcap) that must be cross-built
# for iOS or stubbed out. Expect iteration here; this is the hard part of the port.
set -euo pipefail

# --- Preflight: fail early with a clear message ---
for t in cmake ninja git xcrun xcodebuild; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t (brew install cmake ninja; install Xcode for xcrun/xcodebuild)"; exit 1; }
done
case "$(xcode-select -p)" in
  *CommandLineTools*) echo "xcode-select points at Command Line Tools. Run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; exit 1;;
esac
xcrun --sdk iphoneos --show-sdk-path >/dev/null || { echo "iOS SDK not found: open Xcode once and accept the license"; exit 1; }

cd "$(dirname "$0")/../Core"
[ -d AppleWin ] || git clone --recurse-submodules https://github.com/AppleWin/AppleWin.git
cd AppleWin
# TODO: pin to the commit matching RAppleWin 1.30.20.0 (Nov 2024 release tag).
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
