#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
VENDOR_DIR="$PROJECT_DIR/vendor/llm"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT="$BUILD_DIR/game-linux-arm64.zip"

for required in \
  "$VENDOR_DIR/manifest.json" \
  "$VENDOR_DIR/models/gemma-3-270m-it-Q4_K_M.gguf" \
  "$VENDOR_DIR/runtimes/linux-arm64/llama-server"; do
  if [ ! -e "$required" ]; then
    printf 'Missing LLM asset: %s\nRun tools/llm/fetch-assets.sh first.\n' "$required" >&2
    exit 1
  fi
done

grep -q 'renderer/rendering_method="gl_compatibility"' "$PROJECT_DIR/project.godot"
grep -q 'textures/vram_compression/import_etc2_astc=true' "$PROJECT_DIR/project.godot"
grep -q 'window/stretch/mode="viewport"' "$PROJECT_DIR/project.godot"

PRESET_NAME=$(awk '
  /^\[preset\.[0-9]+\]$/ {
    current = $0
    sub(/^\[preset\./, "", current)
    sub(/\]$/, "", current)
    in_options = 0
    next
  }
  /^\[preset\.[0-9]+\.options\]$/ {
    current = $0
    sub(/^\[preset\./, "", current)
    sub(/\.options\]$/, "", current)
    in_options = 1
    next
  }
  !in_options && /^name=/ {
    value = substr($0, 6)
    gsub(/^"|"$/, "", value)
    names[current] = value
  }
  in_options && /^binary_format\/architecture="arm64"$/ {
    print names[current]
    exit
  }
' "$PROJECT_DIR/export_presets.cfg")

if [ -z "$PRESET_NAME" ]; then
  printf 'No Linux ARM64 export preset found.\n' >&2
  exit 1
fi
grep -q 'binary_format/embed_pck=false' "$PROJECT_DIR/export_presets.cfg"
grep -q 'texture_format/etc2_astc=true' "$PROJECT_DIR/export_presets.cfg"
grep -q 'texture_format/s3tc_bptc=false' "$PROJECT_DIR/export_presets.cfg"

DOCTOR_JSON=$(npx -y summer-engine@latest doctor --json)
ENGINE=$(printf '%s' "$DOCTOR_JSON" | jq -r '.checks[] | select(.id == "engine-install") | .details.path')
if [ -z "$ENGINE" ] || [ ! -x "$ENGINE" ]; then
  printf 'Summer Engine executable was not found by summer-engine doctor.\n' >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
MARKER=$(mktemp "$BUILD_DIR/export-start.XXXXXX")
STAGE=$(mktemp -d "$BUILD_DIR/llm-stage.XXXXXX")
cleanup() {
  rm -f "$MARKER"
  rm -rf "$STAGE"
}
trap cleanup EXIT

"$ENGINE" --headless --path "$PROJECT_DIR" --import
"$ENGINE" --headless --path "$PROJECT_DIR" --export-release "$PRESET_NAME" "$OUTPUT"
if [ ! -s "$OUTPUT" ] || [ ! "$OUTPUT" -nt "$MARKER" ]; then
  printf 'Fresh Summer export was not created: %s\n' "$OUTPUT" >&2
  exit 1
fi

mkdir -p "$STAGE/llm/models" "$STAGE/llm/runtimes/linux-arm64"
cp "$VENDOR_DIR/manifest.json" "$STAGE/llm/manifest.json"
cp "$VENDOR_DIR/ATTRIBUTION.md" "$STAGE/llm/ATTRIBUTION.md"
cp "$VENDOR_DIR/models/gemma-3-270m-it-Q4_K_M.gguf" "$STAGE/llm/models/"
cp -RP "$VENDOR_DIR/runtimes/linux-arm64/." "$STAGE/llm/runtimes/linux-arm64/"
chmod +x "$STAGE/llm/runtimes/linux-arm64/llama-server"
cp "$PROJECT_DIR/summer-feedback.json" "$STAGE/summer-feedback.json"

(cd "$STAGE" && zip -qry "$OUTPUT" llm summer-feedback.json)
unzip -tq "$OUTPUT" >/dev/null
unzip -Z1 "$OUTPUT" > "$STAGE/archive-files.txt"
grep -qx 'llm/models/gemma-3-270m-it-Q4_K_M.gguf' "$STAGE/archive-files.txt"
grep -qx 'llm/runtimes/linux-arm64/llama-server' "$STAGE/archive-files.txt"
grep -qx 'summer-feedback.json' "$STAGE/archive-files.txt"
printf 'Bundled export ready: %s\n' "$OUTPUT"
