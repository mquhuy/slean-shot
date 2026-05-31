#!/bin/bash
# Build, sign, notarize, staple, and package SleanShot as a distributable DMG.
#
# Prerequisites (one-time):
#   xcrun notarytool store-credentials sleanshot \
#     --apple-id i4myuh@gmail.com --team-id H9AQ2SA8YL
#   (paste an app-specific password from appleid.apple.com)
#
# Usage: ./release.sh

set -euo pipefail

PROJECT="SleanShot.xcodeproj"
SCHEME="SleanShot"
APP_NAME="SleanShot"
TEAM_ID="H9AQ2SA8YL"
NOTARY_PROFILE="sleanshot"

BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTS="$BUILD_DIR/ExportOptions.plist"
APP="$EXPORT_DIR/$APP_NAME.app"

# Derive version from the built app later; staging dir for the DMG.
DMG_STAGE="$BUILD_DIR/dmg-stage"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"

echo "==> 1/6  Archiving (Release)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" \
  clean archive

echo "==> 2/6  Exporting Developer ID app…"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
echo "    Version: $VERSION"

echo "==> 3/6  Zipping for notarization…"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP" "$ZIP_PATH"

echo "==> 4/6  Submitting to Apple notary service (waits)…"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> 5/6  Stapling ticket…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl -a -vvv -t install "$APP" || true

echo "==> 6/6  Building DMG…"
rm -rf "$DMG_STAGE" "$DMG_PATH"
mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov -format UDZO \
  "$DMG_PATH"

# Sign + notarize the DMG itself so Gatekeeper trusts the container too.
codesign --force --sign "Developer ID Application: Quang Huy Mai ($TEAM_ID)" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"

rm -rf "$DMG_STAGE" "$ZIP_PATH"
echo ""
echo "✅ Done: $DMG_PATH"
echo "   Verify on a clean Mac: open the DMG, drag to Applications, launch."
