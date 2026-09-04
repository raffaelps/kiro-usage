#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
cd "$ROOT_DIR"

NOTARY_PROFILE="kiro-usage-notary"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen não encontrado. Instale com: brew install xcodegen" >&2
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

echo "Montando o .dmg…"
DMG_STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

mkdir -p "$ROOT_DIR/build"
DMG_PATH="$ROOT_DIR/build/Kiro-Usage-$VERSION.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "Kiro Usage" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"

echo "Enviando para notarização (pode levar alguns minutos)…"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Anexando o ticket de notarização…"
xcrun stapler staple "$DMG_PATH"

echo "Conferindo com o Gatekeeper…"
spctl -a -vvv --type open --context context:primary-signature "$DMG_PATH"

echo
echo "Pronto: $DMG_PATH"
