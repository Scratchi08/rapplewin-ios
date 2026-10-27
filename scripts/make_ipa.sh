#!/usr/bin/env bash
# Produces an UNSIGNED .ipa for sideloading (AltStore / Sideloadly re-sign it).
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate

# XcodeGen writes project format 77 (Xcode 16+). Older Xcode can't open it,
# so downgrade the format number when needed (the project uses plain groups only).
XC_MAJOR=$(xcodebuild -version | sed -n -E '1s/Xcode ([0-9]+).*/\1/p')
if [ "$XC_MAJOR" -lt 16 ]; then
  echo "Xcode $XC_MAJOR detected: downgrading project format 77 -> 56"
  sed -i '' -E 's/objectVersion = 77;/objectVersion = 56;/' RAppleWin.xcodeproj/project.pbxproj
  sed -i '' -E 's/compatibilityVersion = "Xcode [0-9.]+";/compatibilityVersion = "Xcode 14.0";/' RAppleWin.xcodeproj/project.pbxproj
fi

xcodebuild -project RAppleWin.xcodeproj -scheme RAppleWin -configuration Release \
  -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
rm -rf Payload && mkdir Payload
cp -R build/Build/Products/Release-iphoneos/RAppleWin.app Payload/
zip -qr RAppleWin.ipa Payload && rm -rf Payload
echo "Wrote RAppleWin.ipa"
