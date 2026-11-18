#!/usr/bin/env bash
# Generate PlainSign.xcodeproj (macOS, needs XcodeGen: brew install xcodegen).
#
# Usage: scripts/xcode-prepare.sh [build-suffix]
#   build-suffix: appended to the build number (CI passes the run number), so
#   every App Store upload gets a new, increasing build number: 3 -> 3.57.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .xcode

# Info.plist: xtool's file plus the keys xtool adds itself, for Xcode.
read -r PS_VERSION PS_BUILD < <(python3 -I - Info.plist .xcode/Info.plist "${1:-}" <<'PY'
import plistlib, sys
src, dst, suffix = sys.argv[1:4]
with open(src, "rb") as f:
    info = plistlib.load(f)
build = info["CFBundleVersion"] + (f".{suffix}" if suffix else "")
info.update({
    "CFBundleVersion": build,
    "CFBundleExecutable": "$(EXECUTABLE_NAME)",
    "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
    "CFBundleName": "$(PRODUCT_NAME)",
    "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleDevelopmentRegion": "en",
    "LSRequiresIPhoneOS": True,
    "UILaunchScreen": {},
    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
    "UISupportedInterfaceOrientations~ipad": [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationPortraitUpsideDown",
        "UIInterfaceOrientationLandscapeLeft",
        "UIInterfaceOrientationLandscapeRight",
    ],
})
with open(dst, "wb") as f:
    plistlib.dump(info, f)
print(info["CFBundleShortVersionString"], build)
PY
)
export PS_VERSION PS_BUILD

# App icon asset catalog, from the same PNG xtool uses.
icon=.xcode/Assets.xcassets/AppIcon.appiconset
mkdir -p "$icon"
cp Resources/AppIcon.png "$icon/AppIcon.png"
echo '{ "info" : { "author" : "xcode", "version" : 1 } }' > .xcode/Assets.xcassets/Contents.json
cat > "$icon/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

xcodegen generate --quiet
echo "Generated PlainSign.xcodeproj: version $PS_VERSION, build $PS_BUILD"
