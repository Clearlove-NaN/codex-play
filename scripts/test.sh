#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/iron-meridian/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/iron-meridian/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/iron-meridian/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --editor --import --quit
"$GODOT_BIN" --headless --script res://tests/test_battle.gd
timeout 120 "$GODOT_BIN" --headless -- --ui-test
