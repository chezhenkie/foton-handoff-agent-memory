#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CRATE_DIR="$PROJ_ROOT/foton-handoff-src"

echo "=== foton-handoff local build and test ==="
echo "Project root: $PROJ_ROOT"
echo "Crate dir: $CRATE_DIR"
echo ""

source $HOME/.cargo/env

cd "$CRATE_DIR"

echo "=== Step 1: cargo fmt --check ==="
cargo fmt --check
echo "OK"
echo ""

echo "=== Step 2: cargo clippy ==="
cargo clippy --all-targets -- -D warnings
echo "OK"
echo ""

echo "=== Step 3: cargo test ==="
cargo test
echo "OK"
echo ""

echo "=== Step 4: Build Linux (native) ==="
cargo build --release
LINUX_BIN="$CRATE_DIR/target/release/foton-handoff"
if [ ! -f "$LINUX_BIN" ] || [ ! -x "$LINUX_BIN" ]; then
  echo "FAIL: Linux binary not found at $LINUX_BIN" >&2
  exit 1
fi
echo "OK: $LINUX_BIN"
echo ""

echo "=== Step 5: Build Windows (cross-compile) ==="
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-pc-windows-gnu
WIN_BIN="$CRATE_DIR/target/x86_64-pc-windows-gnu/release/foton-handoff.exe"
if [ ! -f "$WIN_BIN" ]; then
  echo "FAIL: Windows binary not found at $WIN_BIN" >&2
  exit 1
fi
echo "OK: $WIN_BIN"
echo ""

echo "=== Step 6: Linux e2e tests ==="
bash "$SCRIPT_DIR/e2e-linux.sh" "$LINUX_BIN"
echo ""

echo "=== Step 7: Windows e2e tests ==="
WIN_BIN_WIN=$(wslpath -w "$WIN_BIN")
SCRIPT_WIN=$(wslpath -w "$SCRIPT_DIR/e2e-windows.ps1")
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_WIN" -Bin "$WIN_BIN_WIN"
echo ""

echo "=== Step 8: Linux speedtest ==="
bash "$SCRIPT_DIR/speedtest-linux.sh" "$LINUX_BIN"
echo ""

echo "=== Step 9: Windows speedtest ==="
SPEEDTEST_WIN=$(wslpath -w "$SCRIPT_DIR/speedtest-windows.ps1")
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SPEEDTEST_WIN" -Bin "$WIN_BIN_WIN"
echo ""

echo "=== ALL STEPS COMPLETED ==="
