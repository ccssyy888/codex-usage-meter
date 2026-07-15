#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_DIR="$ROOT_DIR/outputs/Codex Usage Meter.app"
DIST_DIR="$ROOT_DIR/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
ARCHIVE_NAME="Codex-Usage-Meter-v${VERSION}-macOS"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null
mkdir -p "$DIST_DIR"
VERIFY_DIR="$(mktemp -d "$DIST_DIR/.codex-meter-verify.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT
rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"

/usr/bin/ditto \
    -c -k --keepParent \
    --norsrc --noextattr --noqtn --noacl \
    "$APP_DIR" "$ARCHIVE_PATH"
(
    cd "$DIST_DIR"
    /usr/bin/shasum -a 256 "${ARCHIVE_PATH:t}" > "${CHECKSUM_PATH:t}"
    /usr/bin/shasum -a 256 -c "${CHECKSUM_PATH:t}"
)

/usr/bin/codesign --verify --deep --strict "$APP_DIR"
/usr/bin/ditto -x -k "$ARCHIVE_PATH" "$VERIFY_DIR"
PACKAGED_APP="$VERIFY_DIR/Codex Usage Meter.app"
PACKAGED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PACKAGED_APP/Contents/Info.plist")"
[[ "$PACKAGED_VERSION" == "$VERSION" ]]
/usr/bin/codesign --verify --deep --strict "$PACKAGED_APP"
file "$APP_DIR/Contents/MacOS/CodexMeter"
echo "$ARCHIVE_PATH"
echo "$CHECKSUM_PATH"
