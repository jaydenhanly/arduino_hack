#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

if [[ -n "${SUMMER_BIN:-}" ]]; then
  ENGINE="$SUMMER_BIN"
elif [[ -x "/Applications/Summer.app/Contents/MacOS/Summer" ]]; then
  ENGINE="/Applications/Summer.app/Contents/MacOS/Summer"
else
  echo "Could not find Summer Engine. Set SUMMER_BIN to its executable." >&2
  exit 1
fi

exec "$ENGINE" \
  --headless \
  --path "$PROJECT_DIR" \
  --script res://tests/llm/smoke.gd
