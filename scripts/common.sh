#!/usr/bin/env bash
# Shared settings for local tiny_os CI. Sourced by ci.sh and watch.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT_DIR/config.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/config.env"
  set +a
fi

REPO_URL="${REPO_URL:-git@github.com:yinshuangfei/tiny_os.git}"
BRANCH="${BRANCH:-main}"
ARCH="${ARCH:-x86}"
POLL_INTERVAL="${POLL_INTERVAL:-10}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-25}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"
STATE_DIR="${STATE_DIR:-$ROOT_DIR/.ci-state}"
STATE_FILE="${STATE_FILE:-$STATE_DIR/last_sha}"

# e2e / disk-image tools often live here
PATH="/usr/local/bin:/usr/sbin:/sbin:${PATH}"
export PATH

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

remote_sha() {
  git ls-remote "$REPO_URL" "refs/heads/${BRANCH}" | awk '{print $1}'
}

short_sha() {
  local sha="${1:-}"
  if [ ${#sha} -ge 7 ]; then
    printf '%s' "${sha:0:7}"
  else
    printf '%s' "$sha"
  fi
}
