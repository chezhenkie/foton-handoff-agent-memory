#!/bin/bash
# Bash e2e smoke test for foton-handoff (Linux and macOS). Mirrors scripts/e2e-windows.ps1.
#
# Usage:
#   bash scripts/e2e-linux.sh [path/to/foton-handoff]
#
# With no argument, these candidates are tried relative to this script's folder:
#   ../release/foton-handoff
#   ../foton-handoff-src/target/release/foton-handoff
#   ../target/release/foton-handoff
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

ROOT=/tmp/foton-handoff/foton-e2e-$$
rm -rf "$ROOT"
mkdir -p "$ROOT"

cp "$BIN" "$ROOT/foton-handoff"
chmod +x "$ROOT/foton-handoff"
RUN="$ROOT/foton-handoff"

echo "=== binary: $BIN (copied to $RUN) ==="

echo "=== 1. write writes a handoff ==="
echo "# Project Alpha" | "$RUN" write alpha
test "$(ls "$ROOT"/*.md 2>/dev/null | wc -l)" -eq 1

echo "=== 2. read retrieves it ==="
OUT=$("$RUN" read alpha)
echo "$OUT"
test "$OUT" = "# Project Alpha"

echo "=== 3. dry-run previews archive, moves nothing ==="
echo "# Project Alpha v2" | "$RUN" write alpha -n >/dev/null
test "$(ls "$ROOT"/handoffarchive/*.md 2>/dev/null | wc -l)" -eq 0

echo "=== 4. real write archives old and writes new ==="
echo "# Project Alpha v2" | "$RUN" write alpha
test "$(ls "$ROOT"/handoffarchive/*alpha*.md 2>/dev/null | wc -l)" -ge 1
test "$(ls "$ROOT"/*alpha*.md 2>/dev/null | wc -l)" -eq 1

echo "=== 5. read returns newest ==="
OUT=$("$RUN" read alpha)
echo "$OUT"
test "$OUT" = "# Project Alpha v2"

echo "=== 6. same-minute write collision gets -2 suffix ==="
echo "# Another Alpha" | "$RUN" write alpha
ls "$ROOT"/handoffarchive
test -f "$ROOT"/handoffarchive/*alpha-2.md

echo "=== 7. cross-project isolation ==="
echo "# Project Beta" | "$RUN" write beta
test "$("$RUN" read beta)" = "# Project Beta"
COUNT_ALPHA=$(ls "$ROOT"/handoffarchive/*alpha* 2>/dev/null | wc -l)
COUNT_BETA=$(ls "$ROOT"/*beta* 2>/dev/null | wc -l)
echo "archive alpha files=$COUNT_ALPHA root beta files=$COUNT_BETA"
test "$COUNT_ALPHA" -eq 2
test "$COUNT_BETA" -eq 1

echo "=== 8. unknown subcommand exits 2 ==="
set +e
"$RUN" bogus proj >/dev/null 2>&1
code=$?
set -e
echo "exit=$code"
test "$code" -eq 2

echo "=== 9. case-insensitive project matching ==="
OUT=$("$RUN" read ALPHA)
echo "$OUT"
test "$OUT" = "# Another Alpha"

echo "=== 10. read on missing project exits 1 with stderr ==="
set +e
ERRFILE="$ROOT/stderr-missing.txt"
"$RUN" read ghost >"$ROOT/stdout-missing.txt" 2>"$ERRFILE"
code=$?
set -e
echo "exit=$code stderr=$(cat "$ERRFILE")"
test "$code" -eq 1
test -s "$ERRFILE"

echo "=== 11. missing project argument exits 2 ==="
set +e
"$RUN" >/dev/null 2>&1; codeA=$?
"$RUN" read >/dev/null 2>&1; codeB=$?
"$RUN" write >/dev/null 2>&1; codeC=$?
set -e
echo "exit codes: $codeA $codeB $codeC"
test "$codeA" -eq 2
test "$codeB" -eq 2
test "$codeC" -eq 2

echo "=== 12. empty stdin write exits 1 and writes nothing ==="
set +e
: | "$RUN" write voidproj >/dev/null 2>&1
code=$?
set -e
echo "exit=$code"
test "$code" -eq 1
test "$(ls "$ROOT"/*voidproj* 2>/dev/null | wc -l)" -eq 0

echo "=== 13. empty project name exits 2 and writes nothing ==="
BEFORE=$(ls "$ROOT"/*.md 2>/dev/null | wc -l)
set +e
"$RUN" write "" >/dev/null 2>&1; codeA=$?
"$RUN" read "" >/dev/null 2>&1; codeB=$?
"$RUN" write "   " >/dev/null 2>&1; codeC=$?
set -e
echo "exit codes: $codeA $codeB $codeC"
test "$codeA" -eq 2
test "$codeB" -eq 2
test "$codeC" -eq 2
AFTER=$(ls "$ROOT"/*.md 2>/dev/null | wc -l)
test "$BEFORE" -eq "$AFTER"

echo "=== 14. strict argument parsing ==="
BEFORE14=$(ls "$ROOT"/*.md 2>/dev/null | wc -l)
set +e
"$RUN" write -x alpha >/dev/null 2>&1; codeA=$?
"$RUN" write alpha junk >/dev/null 2>&1; codeB=$?
"$RUN" read --verbose alpha >/dev/null 2>&1; codeC=$?
set -e
echo "exit codes: $codeA $codeB $codeC"
test "$codeA" -eq 2
test "$codeB" -eq 2
test "$codeC" -eq 2
AFTER14=$(ls "$ROOT"/*.md 2>/dev/null | wc -l)
test "$BEFORE14" -eq "$AFTER14"

set +e
echo "# Multi Word Handoff" | "$RUN" write "multi word"
codeD=$?
OUT=$("$RUN" read "multi word")
codeE=$?
set -e
echo "write/read multi-word exit: $codeD $codeE"
test "$codeD" -eq 0
test "$codeE" -eq 0
test "$OUT" = "# Multi Word Handoff"

echo "=== ALL E2E TESTS PASSED ==="
