#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
BUILD_DIR="$ROOT_DIR/.build"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$ROOT_DIR/outputs/Codex Usage Meter.app"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:--}"

architectures=(arm64 x86_64)
if [[ -n "${CODEX_METER_ARCHS:-}" ]]; then
    architectures=(${=CODEX_METER_ARCHS})
fi

mkdir -p "$BUILD_DIR/clang-module-cache" "$BUILD_DIR/swiftpm-module-cache" "$BUILD_DIR/cache" "$OUTPUT_DIR"

export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/swiftpm-module-cache"
export XDG_CACHE_HOME="$BUILD_DIR/cache"

cd "$ROOT_DIR"
binary_inputs=()
for architecture in "${architectures[@]}"; do
    swift build \
        -c release \
        --disable-sandbox \
        --arch "$architecture" \
        -Xswiftc -warnings-as-errors
    binary_dir="$(swift build -c release --disable-sandbox --arch "$architecture" --show-bin-path)"
    binary_inputs+=("$binary_dir/CodexMeter")
done

stage_dir="$(mktemp -d "$OUTPUT_DIR/.codex-meter-build.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
staged_app="$stage_dir/Codex Usage Meter.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"

if (( ${#binary_inputs[@]} == 1 )); then
    cp "$binary_inputs[1]" "$staged_app/Contents/MacOS/CodexMeter"
else
    /usr/bin/lipo -create "${binary_inputs[@]}" -output "$staged_app/Contents/MacOS/CodexMeter"
fi

cp "$ROOT_DIR/Resources/Info.plist" "$staged_app/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$staged_app/Contents/Resources/AppIcon.icns"
for localization in "$ROOT_DIR"/Resources/*.lproj; do
    /usr/bin/ditto "$localization" "$staged_app/Contents/Resources/${localization:t}"
done

/usr/bin/plutil -lint "$staged_app/Contents/Info.plist" >/dev/null

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --sign - "$staged_app"
else
    /usr/bin/codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$staged_app"
fi
/usr/bin/codesign --verify --deep --strict "$staged_app"

rm -rf "$APP_DIR"
mv "$staged_app" "$APP_DIR"

echo "$APP_DIR"
