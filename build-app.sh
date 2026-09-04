#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen não encontrado. Instale com: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate

DERIVED_DATA="$ROOT_DIR/.build/xcode"
xcodebuild \
    -project "KiroUsage.xcodeproj" \
    -scheme "Kiro Usage" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    build

APP_SRC=$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 1 -name "*.app" | head -n 1)
if [[ -z "$APP_SRC" ]]; then
    echo "Não encontrei o .app gerado em $DERIVED_DATA/Build/Products/Release" >&2
    exit 1
fi

rm -rf "$ROOT_DIR/build"
mkdir -p "$ROOT_DIR/build"
cp -R "$APP_SRC" "$ROOT_DIR/build/"

echo "$ROOT_DIR/build/$(basename "$APP_SRC")"
