# foton-handoff e2e test scripts

This document describes the two end-to-end (e2e) test scripts in `scripts/`:

- `scripts/e2e-windows.ps1` -- Windows PowerShell 5.1 suite
- `scripts/e2e-linux.sh`     -- Linux bash suite

Both suites test a compiled `foton-handoff` binary as a black box. They make no
assumptions about how the binary was built and exercise only its command line,
stdin/stdout/stderr behavior, exit codes, and the files it creates.

---

## 1. Purpose and scope

Unit tests (`cargo test`) verify internal logic. The e2e suites verify what an
agent or user actually experiences when running the exe:

- correct archive-and-replace semantics across separate process invocations
- correct file layout (`<root>\*.md` current memory, `<root>\handoffarchive\`
  archived memory)
- the documented exit code contract:

  | Exit | Meaning |
  |------|---------|
  | 0    | success |
  | 1    | operational error (missing project on read, empty stdin on write) |
  | 2    | usage error (unknown subcommand, bad/missing/extra arguments) |

- cross-project isolation and case-insensitive project name matching
- strict argument parsing (no hidden flags, no positional extras)

Each suite has 14 numbered groups plus one trailing multi-word round trip.
The two suites are intentionally near-mirror images of each other so that any
behavior difference between platforms shows up as a failure on exactly one side.

---

## 2. Invocation

### Windows

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\e2e-windows.ps1 [-Bin path\to\foton-handoff.exe]
```

If `-Bin` is omitted, the script tries these candidates relative to the
script's own folder (`$PSScriptRoot`), in order, and uses the first that exists:

```
..\foton-handoff.exe
..\foton-handoff-win11.exe
..\foton-handoff\target\release\foton-handoff.exe
..\target\release\foton-handoff.exe
```

### Linux

```
bash scripts/e2e-linux.sh [path/to/foton-handoff]
```

If the argument is omitted, candidates tried relative to the script folder are:

```
../foton-handoff
../foton-handoff/target/release/foton-handoff
../target/release/foton-handoff
```

On both platforms the script exits non-zero if no binary is given and none of
the default candidates exist.

### CI integration

`.github/workflows/build.yml` runs both suites as dedicated steps in their
build jobs when a remote is re-added under a new account, always passing the
freshly built binary explicitly:

- Linux job:   `bash scripts/e2e-linux.sh foton-handoff/target/release/foton-handoff`
- Windows job: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\e2e-windows.ps1 -Bin <staged exe>`

A failing suite step fails the whole job. Until the repo gains a remote again,
both suites run locally against the WSL-built binaries.

---

## 3. Sandbox mechanics

The tool resolves its storage root from the directory of its own executable.
The scripts exploit this to keep tests hermetic:

1. Create a unique temp root per run:
   - Windows: `%TEMP%\opencode\foton-e2e-<PID>-<HHmmss>`
   - Linux:   `/tmp/opencode/foton-e2e-<PID>`
2. Copy the target binary into that root.
3. Run every test invocation against the copy.

Consequences:

- The tool's root equals the sandbox root; nothing outside it is touched.
- Parallel runs never collide (PID + timestamp in the name).
- The real binary under test stays untouched wherever it lives.
- Cleanup is not required; sandbox dirs are disposable. Delete them at will.

---

## 4. Test groups

Numbering below matches the `=== N. ... ===` banners printed by both scripts.

| # | Group | What it does | Expected |
|---|-------|--------------|----------|
| 1 | write writes a handoff | Pipes `# Project Alpha` into `write alpha`; counts `*.md` in root | exit 0, exactly 1 md file |
| 2 | read retrieves it | `read alpha`, compares full stdout | exit 0, output equals written text |
| 3 | dry-run previews archive | `write alpha -n` with new text; checks output mentions "would archive:" and "would write:", checks `handoffarchive` stays empty | exit 0, nothing moved |
| 4 | real write archives old and writes new | Repeats the write without `-n` | exit 0, >=1 archived alpha file, exactly 1 alpha md left in root |
| 5 | read returns newest | `read alpha` again | exit 0, returns the second text |
| 6 | same-minute collision gets -2 suffix | Third write to `alpha` within the same minute; the previous memory would collide with an existing archive filename | exit 0, exactly one `*alpha-2.md` in archive |
| 7 | cross-project isolation | Writes and reads project `beta`; counts alpha archives and beta files separately | alpha history untouched, beta independent |
| 8 | unknown subcommand | Runs `bogus proj`, discarding output | exit 2 |
| 9 | case-insensitive matching | `read ALPHA` must find project `alpha` | exit 0, newest alpha text |
| 10 | read on missing project | `read ghost`, stdout redirected to a file, stderr captured separately | exit 1, non-empty stderr |
| 11 | missing project argument | Runs bare exe, `read` alone, `write` alone | exit 2 for all three |
| 12 | empty stdin write | Zero-byte stdin into `write voidproj` | exit 1 ("no handoff text received"), no `*voidproj*` files created |
| 13 | empty project name | `write ""`, `read ""`, `write "   "` (whitespace-only) | exit 2 for all three, md file count unchanged |
| 14 | strict argument parsing | `write -x alpha`, `write alpha junk`, `read --verbose alpha` | exit 2 for all three, md file count unchanged |
| - | multi-word round trip (trailing) | Writes then reads project `"multi word"` (name containing a space, quoted) | exit 0 both ways, text round-trips |

Groups 13 and 14 additionally assert that failed invocations leave the file
tree unchanged, i.e. rejected input must not create partial state.

---

## 5. Platform-specific implementation notes

### Windows (`e2e-windows.ps1`)

- `$ErrorActionPreference = "Stop"` globally, but temporarily lowered to
  `SilentlyContinue` around every invocation that is *expected* to fail
  (groups 8, 11, 12, 13, 14), because PS 5.1 turns native stderr lines into
  error records that would otherwise abort the script.
- Exit codes are read from `$LASTEXITCODE` immediately after each call.
- Group 10 redirects stdout and stderr to files rather than relying on PS
  stream merging, since merged `2>&1` output cannot be reliably inspected for
  emptiness under PS 5.1.
- Group 12 feeds stdin through a real zero-byte file using
  `Start-Process -RedirectStandardInput`. Earlier revisions used a PowerShell
  null pipeline (`$null | & $runExe ...`); that passed locally but exited 0
  under GitHub Actions' headless nested console, where the child inherited an
  open stdin handle instead of receiving EOF. The file redirect is deterministic
  in every environment. On failure the captured stderr text is included in the
  FAIL message.
- Output comparisons join PS line arrays with `` `n `` before comparing, so
  trailing newline differences do not cause false failures.

### Linux (`e2e-linux.sh`)

- `set -e` makes any unexpected non-zero exit abort immediately; it is toggled
  off (`set +e`) around invocations whose non-zero exit is the assertion
  itself, then restored.
- Assertions use `test` with command substitution, e.g.
  `test "$(ls "$ROOT"/*.md 2>/dev/null | wc -l)" -eq 1`.
- Group 12 uses `: | "$RUN" write voidproj`, which closes stdin after writing
  zero bytes.
- Stderr presence in group 10 is asserted with `test -s` (file exists and is
  non-empty).

---

## 6. Adding a new group

When extending the suites:

1. Add the group to BOTH scripts, keeping the numbering and banner wording in
   sync; the mirrors exist to expose platform drift.
2. Assert both the exit code AND the filesystem effect (or absence of one).
3. On Windows, wrap expected-failure invocations in
   `ErrorActionPreference = SilentlyContinue` save/restore.
4. Never write inside the repo tree; everything goes under `$root`.
5. Re-run both suites locally before tagging, and let CI confirm:

   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\e2e-windows.ps1 -Bin <exe>
   bash scripts/e2e-linux.sh <binary>
   ```

Success banner: `=== ALL WINDOWS E2E TESTS PASSED ===` /
`=== ALL LINUX E2E TESTS PASSED ===`, exit code 0.
