#!/usr/bin/env bash
set -euo pipefail

# Pre-deploy validation for every Uno Q hardware component: joystick, face
# buttons, vibration, the LED matrix, and the ambient light sensor. Each probe
# is a headless, logic-only SceneTree script (no rendering, no board
# required) — run this before every physical deploy to catch a broken
# binding or feedback regression early.

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

if [[ -n "${SUMMER_BIN:-}" ]]; then
  ENGINE="$SUMMER_BIN"
elif [[ -x "/Applications/Summer.app/Contents/MacOS/Summer" ]]; then
  ENGINE="/Applications/Summer.app/Contents/MacOS/Summer"
else
  echo "Could not find Summer Engine. Set SUMMER_BIN to its executable." >&2
  exit 1
fi

OUT_ROOT="${OUT_DIR:-$PROJECT_DIR/builds/checks/hardware}"
mkdir -p "$OUT_ROOT"
OUT="$(mktemp -d "$OUT_ROOT/run-XXXXXXXX")"
echo "Hardware pre-deploy validation: $OUT"

ERROR_PATTERN='SCRIPT ERROR[:|]|^[[:space:]]*ERROR[:|]|Parse Error:|Compile Error:|Failed to load script|Assertion failed'
# light_sensor_probe deliberately feeds malformed JSON to verify level_for_state()
# handles it; Godot's own JSON.parse_string logs a benign "Parse JSON failed"
# ERROR line for that, which is not a real failure.
BENIGN_PATTERN='Parse JSON failed'

overall=0
for name in joystick button vibration light light_sensor; do
  log="$OUT/$name.log"
  marker="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')_PROBE checks="
  status=0
  "$ENGINE" --headless --disable-crash-handler --path "$PROJECT_DIR" \
    --script "tests/hardware/${name}_probe.gd" >"$log" 2>&1 || status=$?
  if [[ $status -eq 0 ]] && grep -q "$marker" "$log" && \
      ! grep -vE "$BENIGN_PATTERN" "$log" | grep -qE "$ERROR_PATTERN"; then
    echo "PASS $name: $log"
  else
    echo "FAIL $name: $log"
    tail -n 40 "$log"
    overall=1
  fi
done

exit $overall
