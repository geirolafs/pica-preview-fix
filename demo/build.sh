#!/bin/bash
# Rebuild "Pica (Patched).app" from the current /Applications/Pica.app.
# Re-run this after Pica auto-updates the original.
set -e
cd "$(dirname "$0")"
SRC="/Applications/Pica.app"
OUT="/Applications/Pica (Patched).app"

echo "Building fix dylib…"
clang -dynamiclib -framework Foundation -framework CoreText -o libpicafix.dylib picafix.m
install_name_tool -id @executable_path/../Frameworks/libpicafix.dylib libpicafix.dylib

echo "Copying $SRC → $OUT"
rm -rf "$OUT"; cp -R "$SRC" "$OUT"
cp libpicafix.dylib "$OUT/Contents/Frameworks/libpicafix.dylib"

echo "Injecting load command…"
python3 add_load_cmd.py "$OUT/Contents/MacOS/Pica"

echo "Tweaking Info.plist (name + disable auto-update)…"
PB=/usr/libexec/PlistBuddy
$PB -c "Set :CFBundleDisplayName Pica (Patched)" "$OUT/Contents/Info.plist"
$PB -c "Set :CFBundleName Pica (Patched)" "$OUT/Contents/Info.plist"
$PB -c "Set :SUEnableAutomaticChecks false" "$OUT/Contents/Info.plist" 2>/dev/null || \
  $PB -c "Add :SUEnableAutomaticChecks bool false" "$OUT/Contents/Info.plist"

echo "Re-signing (ad-hoc, library validation disabled)…"
codesign --force --sign - --entitlements ent.plist "$OUT/Contents/Frameworks/libpicafix.dylib"
codesign --remove-signature "$OUT/Contents/MacOS/Pica" 2>/dev/null || true
codesign --force --sign - --entitlements ent.plist "$OUT/Contents/MacOS/Pica"
codesign --force --sign - --entitlements ent.plist "$OUT"
echo "Done → $OUT"
