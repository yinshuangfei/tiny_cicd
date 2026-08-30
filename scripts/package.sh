#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/dist}"
BUNDLE_NAME="${2:-release.tgz}"

case "$OUTPUT_DIR" in
  /*) ;;
  *) OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR" ;;
esac

mkdir -p "$OUTPUT_DIR"

BUNDLE_PATH="$OUTPUT_DIR/$BUNDLE_NAME"

git -C "$ROOT_DIR" ls-files -z --cached --others --exclude-standard | \
  tar -C "$ROOT_DIR" --null -czf "$BUNDLE_PATH" --files-from -

echo "$BUNDLE_PATH"
