#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
VENDOR_DIR="$PROJECT_DIR/vendor/llm"
CACHE_DIR="$PROJECT_DIR/build/llm-downloads"

LLAMA_VERSION="b10819"
MAC_ARCHIVE="llama-${LLAMA_VERSION}-bin-macos-arm64.tar.gz"
LINUX_ARCHIVE="llama-${LLAMA_VERSION}-bin-ubuntu-arm64.tar.gz"
MAC_SHA256="8933e736495eadfef0731ae32054acfaa75699bf4a6ccba77cd8475db085ec66"
LINUX_SHA256="6f6f7e1e9b371d4840860a79ccbf4ad6f7da9da76349ce73079e3289b01033ec"
MODEL_NAME="gemma-3-270m-it-Q4_K_M.gguf"
MODEL_REVISION="c90975dbd40c0c7b275fefaae758c3415c906238"
MODEL_SHA256="b1baabd6b729e4041822220d3e648e00d99cac5df86b10dffb77bcccf0688e39"

mkdir -p "$CACHE_DIR" "$VENDOR_DIR/models" \
  "$VENDOR_DIR/runtimes/macos-arm64" "$VENDOR_DIR/runtimes/linux-arm64"

verify_sha256() {
  local path=$1
  local expected=$2
  printf '%s  %s\n' "$expected" "$path" | shasum -a 256 -c - >/dev/null 2>&1
}

download_checked() {
  local url=$1
  local output=$2
  local expected=$3
  if [ -f "$output" ] && verify_sha256 "$output" "$expected"; then
    return
  fi
  curl --fail --location --retry 3 --output "$output.part" "$url"
  verify_sha256 "$output.part" "$expected"
  mv "$output.part" "$output"
}

install_runtime() {
  local archive=$1
  local destination=$2
  local library_pattern=$3
  local temporary
  temporary=$(mktemp -d "${TMPDIR:-/tmp}/retro-ai-llama.XXXXXX")
  tar -xzf "$archive" -C "$temporary"
  local source_dir="$temporary/llama-${LLAMA_VERSION}"
  cp "$source_dir/llama-server" "$destination/llama-server"
  find "$source_dir" -maxdepth 1 -name "$library_pattern" -exec cp -P {} "$destination/" \;
  cp "$source_dir/LICENSE" "$destination/llama.cpp-LICENSE"
  chmod +x "$destination/llama-server"
  rm -rf "$temporary"
}

download_checked \
  "https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VERSION}/${MAC_ARCHIVE}" \
  "$CACHE_DIR/$MAC_ARCHIVE" \
  "$MAC_SHA256"
download_checked \
  "https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VERSION}/${LINUX_ARCHIVE}" \
  "$CACHE_DIR/$LINUX_ARCHIVE" \
  "$LINUX_SHA256"
download_checked \
  "https://huggingface.co/unsloth/gemma-3-270m-it-GGUF/resolve/${MODEL_REVISION}/${MODEL_NAME}" \
  "$VENDOR_DIR/models/$MODEL_NAME" \
  "$MODEL_SHA256"

install_runtime "$CACHE_DIR/$MAC_ARCHIVE" "$VENDOR_DIR/runtimes/macos-arm64" '*.dylib'
install_runtime "$CACHE_DIR/$LINUX_ARCHIVE" "$VENDOR_DIR/runtimes/linux-arm64" 'lib*.so*'
cp "$SCRIPT_DIR/manifest.json" "$VENDOR_DIR/manifest.json"
cp "$SCRIPT_DIR/ATTRIBUTION.md" "$VENDOR_DIR/ATTRIBUTION.md"

verify_sha256 "$VENDOR_DIR/models/$MODEL_NAME" "$MODEL_SHA256"
printf 'LLM assets ready in %s\n' "$VENDOR_DIR"
