#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_NAME="release.tgz"
BUNDLE_PATH="$DIST_DIR/$BUNDLE_NAME"

required_files=(
  "$ROOT_DIR/app.py"
  "$ROOT_DIR/Dockerfile"
  "$ROOT_DIR/docker-compose.yml"
  "$ROOT_DIR/README.md"
  "$ROOT_DIR/.github/workflows/cicd.yml"
  "$ROOT_DIR/scripts/package.sh"
  "$ROOT_DIR/scripts/deploy.sh"
)

for file_path in "${required_files[@]}"; do
  if [ ! -f "$file_path" ]; then
    echo "missing required file: ${file_path#$ROOT_DIR/}"
    exit 1
  fi
done

while IFS= read -r -d '' script_path; do
  bash -n "$script_path"
done < <(find "$ROOT_DIR/scripts" -maxdepth 1 -type f -name '*.sh' -print0)

python3 -m py_compile "$ROOT_DIR/app.py"

PYTHONPATH="$ROOT_DIR" python3 - <<'PY'
from app import render_response

cases = [
    ("/healthz", 200, "ok\n"),
    ("/", 200, "tiny_cicd is running\nversion: 1.0.0\n"),
    ("/missing", 404, "not found\n"),
]

for path, expected_status, expected_body in cases:
    status, body = render_response(path, "tiny_cicd", "1.0.0")
    assert status == expected_status, (path, status, expected_status)
    assert body == expected_body, (path, body, expected_body)
PY

bash "$ROOT_DIR/scripts/package.sh" "$DIST_DIR" "$BUNDLE_NAME" >/dev/null
tar -tzf "$BUNDLE_PATH" >/dev/null

archive_contents="$(tar -tzf "$BUNDLE_PATH")"

for expected_path in app.py Dockerfile docker-compose.yml README.md .github/workflows/cicd.yml scripts/package.sh scripts/deploy.sh; do
  if ! grep -Fxq "$expected_path" <<<"$archive_contents"; then
    echo "bundle is missing expected file: $expected_path"
    exit 1
  fi
done

echo "ci check passed: $BUNDLE_PATH"
