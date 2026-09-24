#!/usr/bin/env bash
# Builds MenuType.app and packages it as a drag-to-install .dmg.
#
#   ./make-dmg.sh
#
# The disk image contains MenuType.app plus an /Applications symlink, so the
# usual "drag the icon onto Applications" gesture works.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MenuType"
VERSION="1.0.0"
DMG="$PWD/$APP_NAME-$VERSION.dmg"
STAGE=".build/dmg"

./build.sh release

echo "==> Staging disk image"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $APP_NAME-$VERSION.dmg"
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG" >/dev/null

rm -rf "$STAGE"

SIZE="$(du -h "$DMG" | cut -f1)"
echo
echo "Built: $DMG  ($SIZE)"
echo "Mount: open '$DMG'"
