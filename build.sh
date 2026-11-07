#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/arm64 build/x86_64 build/module-cache dist
app='build/Smart Chinese.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
  xcrun swiftc -O -target "$arch-apple-macosx13.0" -module-cache-path "$PWD/build/module-cache" Sources/*.swift -o "build/$arch/SmartChinese"
done
xcrun lipo -create build/arm64/SmartChinese build/x86_64/SmartChinese -output "$app/Contents/MacOS/SmartChinese"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
codesign --force --sign - "$app"
"$app/Contents/MacOS/SmartChinese" --test
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
stage="build/Smart-Chinese-$version"
mkdir -p "$stage"
ditto "$app" "$stage/Smart Chinese.app"
cp install.command uninstall.command README.md LICENSE "$stage/"
ditto -c -k --keepParent "$stage" "dist/Smart-Chinese-$version-macOS-universal.zip"
(cd dist && shasum -a 256 "Smart-Chinese-$version-macOS-universal.zip" > SHA256SUMS)
echo "Built dist/Smart-Chinese-$version-macOS-universal.zip"
