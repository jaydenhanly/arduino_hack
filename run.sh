#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="${SUMMER_BIN:-/Applications/Summer.app/Contents/MacOS/Summer}"
if [[ ! -x "$ENGINE" ]]; then
  echo "Set SUMMER_BIN to the installed Summer Engine executable." >&2
  exit 1
fi
exec "$ENGINE" --path "$PROJECT_DIR" "$@"
