#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# This cloud environment keeps SDKs and Godot's editor configuration here.
# On another machine, configure Java/Android paths in Godot's editor first.
if [[ -d /workspace/toolchains/config/godot ]]; then
 export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/toolchains/userdata}"
 export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/toolchains/config}"
 export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/toolchains/cache}"
 export JAVA_HOME="${JAVA_HOME:-/workspace/toolchains/jdk}"
fi
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT="${1:-$PWD/artifacts/IronMeridian-0.1.0.apk}"
mkdir -p "$(dirname "$OUTPUT")"
"$GODOT_BIN" --headless --editor --import --quit
"$GODOT_BIN" --headless --export-debug Android "$OUTPUT"
SDK_PATH="${ANDROID_HOME:-/workspace/toolchains/android-sdk}"
if [[ -x "$SDK_PATH/build-tools/35.0.1/apksigner" ]]; then
 "$SDK_PATH/build-tools/35.0.1/apksigner" verify --verbose "$OUTPUT"
fi
printf 'APK: %s\n' "$OUTPUT"
