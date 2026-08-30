#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

mkdir -p "$LOG_DIR" "$STATE_DIR"

LAST_SHA=""
if [ -f "$STATE_FILE" ]; then
  LAST_SHA="$(tr -d '[:space:]' < "$STATE_FILE")"
fi

echo "watching $REPO_URL ($BRANCH)"
echo "workdir  $BUILD_DIR"
echo "arch     $ARCH"
echo "poll     ${POLL_INTERVAL}s"
echo "start    $(timestamp)"
echo

while true; do
  sha="$(remote_sha || true)"
  if [ -z "$sha" ]; then
    echo "$(timestamp) cannot read $BRANCH from $REPO_URL" >&2
    sleep "$POLL_INTERVAL"
    continue
  fi

  if [ "$sha" = "$LAST_SHA" ]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  echo "$(timestamp) push detected: $(short_sha "$LAST_SHA") -> $(short_sha "$sha")"
  set +e
  bash "$ROOT_DIR/scripts/ci.sh"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "$(timestamp) CI PASS  $(short_sha "$sha")"
  elif [ "$rc" -eq 2 ]; then
    echo "$(timestamp) CI sync failed, will retry" >&2
    sleep "$POLL_INTERVAL"
    continue
  else
    echo "$(timestamp) CI FAIL  $(short_sha "$sha")  (see $LOG_DIR)"
  fi
  LAST_SHA="$sha"
  printf '%s\n' "$LAST_SHA" > "$STATE_FILE"
  echo
done
