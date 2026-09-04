#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
cd "$ROOT_DIR"

NOTARY_PROFILE="kiro-usage-notary"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen não encontrado. Instale com: brew install xcodegen" >&2
    exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg não encontrado. Instale com: brew install create-dmg" >&2
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "Credenciais de notarização não configuradas. Rode primeiro:" >&2
    echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <seu-apple-id> --team-id 2TMMUPY74C --password <senha-de-app-especifica>" >&2
    exit 1
fi

xcodegen generate

BUILD_DIR="$ROOT_DIR/.build/release"
ARCHIVE_PATH="$BUILD_DIR/KiroUsage.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$BUILD_DIR"

echo "Arquivando (Release)…"
xcodebuild \
    -project "KiroUsage.xcodeproj" \
    -scheme "Kiro Usage" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    archive

echo "Exportando assinado com Developer ID…"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$ROOT_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates

APP_PATH="$EXPORT_PATH/Kiro Usage.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Não encontrei o .app exportado em $EXPORT_PATH" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")

echo "Enviando o app para notarização (pode levar alguns minutos)…"
ZIP_PATH="$BUILD_DIR/Kiro-Usage-for-notarization.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Anexando o ticket de notarização ao app…"
xcrun stapler staple "$APP_PATH"

echo "Conferindo com o Gatekeeper…"
spctl -a -vvv --type execute "$APP_PATH"

echo "Montando o .dmg…"
mkdir -p "$ROOT_DIR/build"
DMG_PATH="$ROOT_DIR/build/Kiro-Usage-$VERSION.dmg"
rm -f "$DMG_PATH"

DMG_SOURCE="$BUILD_DIR/dmg-source"
rm -rf "$DMG_SOURCE"
mkdir -p "$DMG_SOURCE"
cp -R "$APP_PATH" "$DMG_SOURCE/"

create-dmg \
    --volname "Kiro Usage" \
    --background "$ROOT_DIR/Resources/dmg-background.png" \
    --window-size 660 400 \
    --icon-size 128 \
    --text-size 13 \
    --icon "Kiro Usage.app" 170 190 \
    --hide-extension "Kiro Usage.app" \
    --app-drop-link 490 190 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$DMG_SOURCE"

echo
echo "Pronto: $DMG_PATH"
