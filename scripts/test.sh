#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Always isolate test saves, including when the caller has normal XDG paths set.
MERIDIAN_TEST_ROOT="$(mktemp -d /tmp/iron-meridian-tests.XXXXXX)"
trap 'rm -rf "$MERIDIAN_TEST_ROOT"' EXIT
export XDG_DATA_HOME="$MERIDIAN_TEST_ROOT/data"
export XDG_CONFIG_HOME="$MERIDIAN_TEST_ROOT/config"
export XDG_CACHE_HOME="$MERIDIAN_TEST_ROOT/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --editor --import --quit
timeout 120 "$GODOT_BIN" --headless --script res://tests/test_world.gd
timeout 120 "$GODOT_BIN" --headless -- --ui-test
if [[ -f tests/test_world_input.gd ]]; then
 timeout 120 "$GODOT_BIN" --headless --script res://tests/test_world_input.gd
fi
