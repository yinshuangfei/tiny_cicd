#!/usr/bin/env bash
set -uo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<EOF
usage: $0 [--no-pull]

Pull ${REPO_URL} (${BRANCH}) into ${BUILD_DIR}, then compile and run there.
EOF
}

DO_PULL=1
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    --no-pull)
      DO_PULL=0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$LOG_DIR" "$STATE_DIR"
MAKE_DIR="$BUILD_DIR/arch/$ARCH"

COMPILE_STATUS="SKIP"
RUN_STATUS="SKIP"
RESULT="FAIL"
COMMIT_SHA=""
COMMIT_SUBJECT=""
LOG_FILE=""

sync_repo() {
  if [ ! -d "$BUILD_DIR/.git" ]; then
    if [ -e "$BUILD_DIR" ] && [ -n "$(ls -A "$BUILD_DIR" 2>/dev/null)" ]; then
      echo "build directory exists but is not a git checkout: $BUILD_DIR" >&2
      return 1
    fi
    echo "[sync] clone $REPO_URL ($BRANCH) -> $BUILD_DIR"
    git clone --branch "$BRANCH" "$REPO_URL" "$BUILD_DIR"
  else
    echo "[sync] fetch $REPO_URL ($BRANCH)"
    git -C "$BUILD_DIR" remote set-url origin "$REPO_URL"
    git -C "$BUILD_DIR" fetch --prune origin
    git -C "$BUILD_DIR" checkout --force "$BRANCH"
    git -C "$BUILD_DIR" reset --hard "origin/${BRANCH}"
    git -C "$BUILD_DIR" clean -fdx
  fi
}

compile_x86() {
  echo "[compile] make -C arch/x86 -j$(nproc) kernel.elf"
  make -C "$MAKE_DIR" -j"$(nproc)" kernel.elf
}

compile_riscv() {
  echo "[compile] make -C arch/riscv -j$(nproc) kernel/kernel fs.img"
  make -C "$MAKE_DIR" -j"$(nproc)" kernel/kernel fs.img
}

compile_arch() {
  if [ ! -f "$MAKE_DIR/Makefile" ]; then
    echo "[compile] missing Makefile: ${MAKE_DIR#$ROOT_DIR/}/Makefile" >&2
    return 1
  fi
  case "$ARCH" in
    x86) compile_x86 ;;
    riscv) compile_riscv ;;
    *)
      echo "[compile] unsupported ARCH=$ARCH" >&2
      return 1
      ;;
  esac
}

run_x86_e2e() {
  echo "[run] make -C arch/x86 e2e"
  make -C "$MAKE_DIR" e2e
}

run_x86_qemu() {
  echo "[run] qemu-system-x86_64 smoke test (${QEMU_TIMEOUT}s)"
  make -C "$MAKE_DIR" hd.img hd1.img hd2.img hd3.img hd4.img hd5.img
  local qemu_log
  qemu_log="$(mktemp)"
  set +e
  timeout --signal=KILL "$QEMU_TIMEOUT" \
    make -C "$MAKE_DIR" K=1 qemu >"$qemu_log" 2>&1
  local rc=$?
  set -e
  cat "$qemu_log"
  if grep -q 'Welcome to Tiny-OS' "$qemu_log"; then
    echo "[run] qemu booted (Welcome to Tiny-OS)"
    rm -f "$qemu_log"
    return 0
  fi
  echo "[run] qemu did not print boot banner (timeout/exit=$rc)" >&2
  rm -f "$qemu_log"
  return 1
}

run_riscv_qemu() {
  echo "[run] qemu-system-riscv64 smoke test (${QEMU_TIMEOUT}s)"
  local qemu_log
  qemu_log="$(mktemp)"
  set +e
  timeout --signal=KILL "$QEMU_TIMEOUT" \
    make -C "$MAKE_DIR" qemu >"$qemu_log" 2>&1
  local rc=$?
  set -e
  cat "$qemu_log"
  if grep -Eq 'init: starting sh|\\$' "$qemu_log"; then
    echo "[run] qemu reached user shell"
    rm -f "$qemu_log"
    return 0
  fi
  echo "[run] qemu did not reach user shell (timeout/exit=$rc)" >&2
  rm -f "$qemu_log"
  return 1
}

run_arch() {
  case "$ARCH" in
    x86)
      if [ -f "$MAKE_DIR/e2e_test/test_dual_mount.py" ]; then
        run_x86_e2e
      else
        run_x86_qemu
      fi
      ;;
    riscv)
      run_riscv_qemu
      ;;
    *)
      echo "[run] unsupported ARCH=$ARCH" >&2
      return 1
      ;;
  esac
}

print_summary() {
  cat <<EOF

========================================
tiny_cicd  local CI
time:    $(timestamp)
repo:    $REPO_URL
branch:  $BRANCH
commit:  $(short_sha "$COMMIT_SHA") $COMMIT_SUBJECT
arch:    $ARCH
workdir: $BUILD_DIR
----------------------------------------
compile: $COMPILE_STATUS
run:     $RUN_STATUS
----------------------------------------
RESULT:  $RESULT
log:     ${LOG_FILE:-"(none)"}
========================================
EOF
}

if [ "$DO_PULL" -eq 1 ]; then
  if ! sync_repo; then
    RESULT="FAIL"
    COMPILE_STATUS="SKIP"
    RUN_STATUS="SKIP"
    print_summary
    exit 2
  fi
elif [ ! -d "$BUILD_DIR/.git" ]; then
  echo "no checkout at $BUILD_DIR; run without --no-pull first" >&2
  exit 1
fi

COMMIT_SHA="$(git -C "$BUILD_DIR" rev-parse HEAD)"
COMMIT_SUBJECT="$(git -C "$BUILD_DIR" log -1 --format='%s')"
LOG_FILE="$LOG_DIR/ci-$(short_sha "$COMMIT_SHA").log"
: >"$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== tiny_cicd $(timestamp) ==="
echo "commit $(git -C "$BUILD_DIR" log -1 --oneline)"
echo

if compile_arch; then
  COMPILE_STATUS="PASS"
else
  COMPILE_STATUS="FAIL"
fi
echo

if [ "$COMPILE_STATUS" = "PASS" ]; then
  if run_arch; then
    RUN_STATUS="PASS"
  else
    RUN_STATUS="FAIL"
  fi
else
  echo "[run] skipped because compile failed"
fi

if [ "$COMPILE_STATUS" = "PASS" ] && [ "$RUN_STATUS" = "PASS" ]; then
  RESULT="PASS"
fi

printf '%s\n' "$COMMIT_SHA" > "$STATE_FILE"
print_summary

if [ "$RESULT" = "PASS" ]; then
  exit 0
fi
exit 1
