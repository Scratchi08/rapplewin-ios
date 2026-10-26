#!/usr/bin/env bash
# Produces an UNSIGNED .ipa for sideloading (AltStore / Sideloadly re-sign it).
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project RAppleWin.xcodeproj -scheme RAppleWin -configuration Release \
  -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
rm -rf Payload && mkdir Payload
cp -R build/Build/Products/Release-iphoneos/RAppleWin.app Payload/
zip -qr RAppleWin.ipa Payload && rm -rf Payload
echo "Wrote RAppleWin.ipa"
