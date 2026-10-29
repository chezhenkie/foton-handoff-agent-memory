#!/bin/bash
set -e

BIN="${1:-}"
if [ -z "$BIN" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  for cand in \
    "$SCRIPT_DIR/../release/foton-handoff" \
    "$SCRIPT_DIR/../foton-handoff-src/target/release/foton-handoff" \
    "$SCRIPT_DIR/../target/release/foton-handoff"; do
    if [ -f "$cand" ] && [ -x "$cand" ]; then BIN="$cand"; break; fi
  done
fi
if [ -z "$BIN" ]; then
  echo "FAIL: no binary given and no candidate found" >&2
  exit 1
fi

ROOT=/tmp/foton-handoff/foton-speedtest-$$
rm -rf "$ROOT"
mkdir -p "$ROOT"

cp "$BIN" "$ROOT/foton-handoff"
chmod +x "$ROOT/foton-handoff"
RUN="$ROOT/foton-handoff"

echo "=== Linux speedtest: $BIN (copied to $RUN) ==="
echo ""

setup_files() {
  local count=$1
  local prefix=$2
  rm -f "$ROOT"/*.md
  rm -rf "$ROOT/handoffarchive"
  for i in $(seq 1 "$count"); do
    echo "# File $i" > "$ROOT/2026-01-01_0000_${prefix}_$(printf '%04d' $i).md"
  done
}

run_scenario() {
  local name="$1"
  local iters=$2
  local cmd="$3"
  
  for _ in 1 2 3; do eval "$cmd" >/dev/null 2>&1; done
  
  local times=()
  for _ in $(seq 1 "$iters"); do
    local t1=$(date +%s%N)
    eval "$cmd" >/dev/null 2>&1
    local t2=$(date +%s%N)
    times+=($(( (t2 - t1) / 1000000 )))
  done
  
  local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
  local min=${sorted[0]}
  local max=${sorted[$((iters-1))]}
  local sum=0
  for t in "${times[@]}"; do sum=$((sum + t)); done
  local mean=$((sum / iters))
  local median_idx=$((iters / 2))
  local median=${sorted[$median_idx]}
  local p95_idx=$((iters * 95 / 100))
  local p95=${sorted[$p95_idx]}
  local ops_per_sec=$((1000 * iters / sum))
  
  echo "| $name | $iters | $min | $median | $mean | $p95 | $max | $ops_per_sec |"
}

echo "| Scenario | Iters | Min | Median | Mean | P95 | Max | Ops/sec |"
echo "|---|---|---|---|---|---|---|---|"

run_scenario "startup only (no args)" 200 "'$RUN' 2>/dev/null || true"

setup_files 10 "test"
run_scenario "read, 10 md files" 200 "'$RUN' read test_0001"

setup_files 1000 "test"
run_scenario "read, 1,000 md files" 200 "'$RUN' read test_0500"

setup_files 5000 "test"
run_scenario "read, 5,000 md files" 100 "'$RUN' read test_2500"

setup_files 10 "test"
run_scenario "write, 10 md files" 200 "echo 'update' | '$RUN' write test_0001"

setup_files 1000 "test"
run_scenario "write, 1,000 md files" 200 "echo 'update' | '$RUN' write test_0500"

setup_files 1000 "test"
run_scenario "write -n, 1,000 md files" 200 "echo 'update' | '$RUN' write test_0500 -n"

echo ""
echo "All timings in milliseconds. Binary location: $ROOT (native ext4)"
echo "Speedtest complete."
