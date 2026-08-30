#!/usr/bin/env bash
set -euo pipefail

BUNDLE_PATH="${1:-}"

if [ -z "$BUNDLE_PATH" ]; then
  echo "usage: $0 <bundle-path>"
  exit 1
fi

required_env=(
  DEPLOY_HOST
  DEPLOY_USER
  DEPLOY_TARGET
  DEPLOY_SSH_KEY
)

for env_name in "${required_env[@]}"; do
  if [ -z "${!env_name:-}" ]; then
    echo "missing required environment variable: $env_name"
    exit 1
  fi
done

if [ ! -f "$BUNDLE_PATH" ]; then
  echo "bundle not found: $BUNDLE_PATH"
  exit 1
fi

DEPLOY_PORT="${DEPLOY_PORT:-22}"
REMOTE_TMP="${REMOTE_TMP:-/tmp/tiny_cicd_release.tgz}"
POST_DEPLOY_CMD="${DEPLOY_POST_DEPLOY:-docker compose up -d --build}"
POST_DEPLOY_B64="$(printf '%s' "$POST_DEPLOY_CMD" | base64 | tr -d '\n')"

KEY_FILE="$(mktemp)"
KNOWN_HOSTS_FILE="$(mktemp)"

cleanup() {
  rm -f "$KEY_FILE" "$KNOWN_HOSTS_FILE"
}

trap cleanup EXIT

printf '%s\n' "$DEPLOY_SSH_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

ssh-keyscan -p "$DEPLOY_PORT" "$DEPLOY_HOST" > "$KNOWN_HOSTS_FILE"

scp \
  -P "$DEPLOY_PORT" \
  -i "$KEY_FILE" \
  -o UserKnownHostsFile="$KNOWN_HOSTS_FILE" \
  -o StrictHostKeyChecking=yes \
  "$BUNDLE_PATH" \
  "$DEPLOY_USER@$DEPLOY_HOST:$REMOTE_TMP"

ssh \
  -p "$DEPLOY_PORT" \
  -i "$KEY_FILE" \
  -o UserKnownHostsFile="$KNOWN_HOSTS_FILE" \
  -o StrictHostKeyChecking=yes \
  "$DEPLOY_USER@$DEPLOY_HOST" \
  "DEPLOY_TARGET=$(printf '%q' "$DEPLOY_TARGET") REMOTE_TMP=$(printf '%q' "$REMOTE_TMP") POST_DEPLOY_B64=$(printf '%q' "$POST_DEPLOY_B64") bash -s" <<'REMOTE'
set -euo pipefail

mkdir -p "$DEPLOY_TARGET"
tar -xzf "$REMOTE_TMP" -C "$DEPLOY_TARGET"
rm -f "$REMOTE_TMP"
cd "$DEPLOY_TARGET"

if [ -n "${POST_DEPLOY_B64:-}" ]; then
  printf '%s' "$POST_DEPLOY_B64" | base64 -d | bash
fi
REMOTE

echo "deploy completed: $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_TARGET"
