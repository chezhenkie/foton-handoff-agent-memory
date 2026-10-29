# foton-handoff docs audit

Date: 2026-10-29
Baseline: v0.1.7, main `a3610cf`, working tree clean before this audit.
Scope: `README.md`, `CHANGELOG.md`, `foton-handoff-design-and-state.md`, `foton-handoff-e2e-scripts.md`, `foton-handoff-performance-benchmarks.md`, `instructions-for-building-and-testing.md`, checked against `foton-handoff-src/src/`, `foton-handoff-src/build.rs`, `foton-handoff-src/Cargo.toml`, `scripts/`, `.github/workflows/build.yml`.

Method: line-by-line read, plus runtime probes with the v0.1.7 Windows binary in a temporary sandbox under the workspace. The sandbox was removed afterwards. No source or doc changes were made.

## Resolutions (2026-10-29 doc pass)

- D1: A. The docs now state the normalization and the 40-character limit.
- D2: A. The docs now state WSL with PowerShell interop and three builds / three e2e runs.
- D3: A. The docs now state the actual dry-run output; no code change.
- H1 to H4, M1 to M6, L1 to L7 and the design-doc stale statements are applied in the six docs. Two comment-only edits outside the docs: the `scripts/e2e-windows.ps1` header now says "A local candidate", and the `src/paths.rs` module comment now names the `current_dir()` fallback.
- No functional source or version change. `git diff --check` is clean and the tracked docs contain no non-ASCII characters.

## Fix order for next session

1. H1 matching normalization.
2. H2 orchestrator scope.
3. H3 e2e banner.
4. H4 subcommand count.
5. M1 push triggers.
6. M2 CRT scope.
7. M3 release provenance.
8. M4 resource field checks.
9. M5 project trees.
10. M6 ASCII violations.
11. L1 to L7.
12. Design doc stale statements.
13. Decisions D1 to D3.

Doc-only changes do not need a build. If D3 is implemented as a code change, run `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and both e2e suites.

## Decisions required

### D1: matching semantics

Option A: document the current normalization. The code trims the name, maps spaces to `_`, replaces every character outside `[A-Za-z0-9_- ]` with `_`, keeps the first 40 characters, and compares case-insensitively. This is tested and intentional.

Option B: remove the replacement and truncation from `sanitize_topic`, then keep "exact" in the docs.

Default: A. The code path is used consistently for write and read, and the unit tests cover it. The docs are the wrong side.

### D2: orchestrator portability

Option A: document that `scripts/build-and-test-all.sh` requires WSL with PowerShell interop, and that it performs three builds and three e2e runs.

Option B: make the script host-neutral. Guard `wslpath`, skip the Windows cross-build and Windows e2e when `wslpath` or `powershell.exe` is absent, and keep the Linux and musl steps.

Default: A for the doc pass. B is a separate change with its own verification.

### D3: dry-run output

Option A: document the current output. `write -n` prints the archive moves and `would write:   newest for project '<name>'`, without naming the target file.

Option B: print the target filename in `commands.rs`. This matches the handoff wording but changes e2e-visible stdout; update group 3 in the e2e guide and both scripts.

Default: B is small, but only if the handoff wording is the intended contract. Otherwise A.

## High

### H1: matching is documented as exact, but the code normalizes and truncates

Claims:
- `README.md:52`: "Matching is exact and case-insensitive."
- `foton-handoff-design-and-state.md:28`: same.
- `CHANGELOG.md:70`: "exact, case-insensitive matching".
- `foton-handoff-design-and-state.md:122`: says `my proj` becomes `_my_proj.md`.

Code:
- `store.rs:11`: `sanitize_topic(project, 40).to_lowercase()`.
- `parse.rs:40-52`: replacement, trim, space-to-underscore, 40-character limit.
- `store.rs:26`: filename project fragment is lowercased before comparison.

Probe evidence:
- `write a/b` created `..._a_b.md`; `read a?b` returned that handoff.
- A 50-character project name and a different 45-character name sharing the first 40 characters mapped to the same project. The second write archived the first handoff and replaced it.

Fix: state the normalization and the 40-character limit. Note that distinct names can alias, for example `a/b` and `a?b`, or two long names with the same prefix. Fix the `_my_proj.md` example to `my_proj` plus the separator.

### H2: orchestrator described as two builds and two e2e suites

Claims:
- `README.md:209-212`: "fmt, Clippy, unit tests, the glibc and musl builds, both e2e suites, both speedtests".
- `instructions-for-building-and-testing.md:100-102`: "both builds, both e2e suites and both speedtests".
- `foton-handoff-e2e-scripts.md:88-91`: same.
- `foton-handoff-design-and-state.md:143`: "both builds (Linux native + Windows cross-compile), both e2e suites".

Code:
- `scripts/build-and-test-all.sh:35-43`: native Linux build.
- `:45-53`: Windows cross-build.
- `:74-83`: Linux musl build.
- `:56`, `:62`, `:86`: three e2e runs.
- `:60-61`, `:70-71`: `wslpath` calls.

Reality: three builds, three e2e runs, two speedtests. The script needs WSL with PowerShell interop, not any bash host. On native Linux or macOS it fails at the first `wslpath` call.

Fix: say "three builds, three e2e runs, two speedtests" and "WSL with PowerShell interop". If D2 chooses B, update after the script change.

### H3: e2e success banner mismatch

Claim: `foton-handoff-e2e-scripts.md:195-196` says the Linux banner is `=== ALL LINUX E2E TESTS PASSED ===`.

Code: `scripts/e2e-linux.sh:157` prints `=== ALL E2E TESTS PASSED ===`.

Fix: update the doc.

### H4: README says one subcommand

Claim: `README.md:12`: "one subcommand and one quoted project name".

Code: `main.rs:17`: `const COMMANDS: [&str; 2] = ["read", "write"]`.

Fix: say "one subcommand per call" or "read or write".

## Medium

### M1: "every push and pull request" overstates CI coverage

Claims:
- `README.md:97`.
- `instructions-for-building-and-testing.md:9`.

Code: `.github/workflows/build.yml:4-9` triggers pushes only on `main` and `v*` tags, plus pull requests to `main` and `workflow_dispatch`. A push to a feature branch without a pull request runs nothing.

Fix: "every push to main, every v* tag, and every pull request to main".

### M2: static CRT rule is scoped to all builds, but CI applies it to Windows only

Claim: `foton-handoff-design-and-state.md:17`: "All builds must use RUSTFLAGS=-C target-feature=+crt-static".

Code:
- `build.yml:54-55`: Windows x86_64.
- `build.yml:120-121`: Windows arm64.
- No `RUSTFLAGS` on the Linux or macOS jobs.
- `README.md:100` correctly describes Linux glibc as dynamically linked.

Fix: scope the rule to Windows builds.

### M3: "binaries ship from release" contradicts the CI-only rule

Claim: `foton-handoff-e2e-scripts.md:49`: "Binaries ship from release\".

Code and docs: `README.md:257-258` says CI is the only source of shipped binaries and local runs are a development convenience. `release/` is a local drop point. Current disk contains only `release/v0.1.7/`, no top-level binaries.

Fix: "local candidate" or "local drop point", not "ship".

### M4: CHANGELOG overstates the version resource checks

Claim: `CHANGELOG.md:23`: both Windows jobs fail on a missing or wrong "version resource field or the version number".

Code:
- `build.yml:77-91` and `:165-179` check `ProductName`, `InternalName`, `OriginalFilename`, `FileDescription` prefix, `LegalCopyright` prefix, `FileVersion`.
- `CompanyName`, `Comments` and `ProductVersion` are not asserted.

Fix: name the checked fields, or say "the checked version resource fields".

### M5: project trees are incomplete

`README.md:164-200` omits:
- `.gitattributes`
- `CHANGELOG.md`

`foton-handoff-design-and-state.md:80-110` omits:
- `.gitattributes`
- `CHANGELOG.md`
- `.github/`
- `foton-handoff-e2e-scripts.md`

`README.md` shows `release/foton-handoff` and `release/foton-handoff.exe`. Current disk has only `release/v0.1.7/`.

Fix: complete both trees. Mark `release/` as an example because it is gitignored, or update it to the current `v0.1.7` layout.

### M6: ASCII rule violations

Repo rule: printable ASCII only.

Non-ASCII:
- `README.md:9`: em dash.
- `README.md:84-86`: em dashes in the exit code list.
- `foton-handoff-design-and-state.md:10`: em dash.
- `foton-handoff-design-and-state.md:82-109`: box-drawing characters in the tree.
- `foton-handoff-performance-benchmarks.md:18`, `19`, `23`: em and en dashes.

Also `README.md:10` has "agent,never" with no space.

Fix: replace with plain hyphens and `+--` style tree characters. The README tree at `README.md:164-200` is already ASCII and is the model.

## Low

### L1: README points to itself for the prompt

Claim: `README.md:19`: "same text as in README.md". The text is in the README itself.

Fix: point to `foton-handoff-design-and-state.md`.

### L2: read -n is accepted and ignored

Claim: `foton-handoff-design-and-state.md:27`: both subcommands accept `-n` to preview actions.

Code: `commands.rs:8`: `pub fn read(project: &str, _dry_run: bool)`. The flag is parsed and discarded.

Fix: document that `read` accepts and ignores `-n`, or reject it for `read`. README:79 is already scoped to `write`.

### L3: "no CWD influence" has a fallback

Claims:
- `README.md:91-93`.
- `paths.rs:4-5` module comment.

Code: `paths.rs:14` falls back to `current_dir()` when `current_exe()` fails. `foton-handoff-design-and-state.md:161` admits the fallback.

Fix: "root is the current_exe() parent; CWD is used only if current_exe() fails".

### L4: e2e EAP group list is wrong

Claim: `foton-handoff-e2e-scripts.md:148` lists groups 8, 11, 12, 13, 14 for `SilentlyContinue`.

Code:
- Group 10 uses `Continue`.
- Group 12 uses `Start-Process` with file redirects and does not change EAP.
- Groups 8, 11, 13, 14 use `SilentlyContinue`.

Fix: correct the list and mention group 12's file redirect.

### L5: README Windows commands run from the wrong directory

Claim: `README.md:233-236` uses `scripts\e2e-windows.ps1` and `scripts\speedtest-windows.ps1`.

Context: the preceding block at `README.md:220-227` leaves the reader in `foton-handoff-src`.

Fix: use `..\scripts\...` or state "run from the project root".

### L6: design doc project-name example

Claim: `foton-handoff-design-and-state.md:122`: `my proj` becomes `_my_proj.md`.

Reality: the project fragment is `my_proj`; the leading `_` is the filename separator.

Fix: use the full filename form `{date}_my_proj.md`.

### L7: benchmark percentile method is not stated

Claim: `foton-handoff-performance-benchmarks.md:1` says "median of N runs" and the table has P95.

Scripts:
- `scripts/speedtest-linux.sh:61-64` and `scripts/speedtest-windows.ps1:74-75` use `sorted[iters/2]` and `sorted[iters*95/100]`.
- For 200 runs that is the 101st value for the median and the 191st for P95, not interpolated percentiles.

Fix: state the method, or compute interpolated percentiles. Low priority; numbers are unaffected in practice.

## Design doc stale statements

- `foton-handoff-design-and-state.md:130` ends mid-sentence: "Size-reduction profile options evaluated".
- `:168`, `:176`, `:182` say a fresh exe was copied to the project root. This contradicts `:131` and the README rule that the project root never holds a binary.
- `:142` says CI "uploads both x86_64 binaries". Six artifacts are uploaded now.
- `:193` says the release workflow prepends `git log` changes above a template with `fetch-depth: 0` on every future tag. The current workflow has no checkout, no template and uses `--generate-notes` (`build.yml:347-368`).
- `:131` says binaries live only in the crate target folder. `release/` is an accepted local drop point and currently holds `v0.1.7`.
- `:136` says the Windows exe is about 339 KB. Current local cross-build is 348,160 B; the CI asset is 323,072 B.

Fix: either mark the completed-steps block as historical and dated, or remove the current-tense claims that no longer hold. Add a short "history" label where needed.

## Handoff drift

The memory file also disagreed with the tree. These were corrected in the handoff written after this audit:

- `release/` contains only `v0.1.7`; the handoff claimed `v0.1.5/`, `v0.1.6/` and top-level binaries.
- Unit test split was stated as 18 store and 15 parse. Actual: 10 parse, 8 store, 15 parse_args.
- "A dry-run write lists the file that would be created" is false. It prints `would write:   newest for project '<name>'`.
- "CI runs fmt on every platform job" is false. The two musl jobs and the Windows arm64 job do not run fmt or Clippy.

## Verification after the doc pass

Doc-only changes:

1. `git diff --check`.
2. ASCII scan on all tracked docs: `rg -n "[^\x00-\x7F]" *.md`.
3. Confirm every changed line reference still points at the intended claim.
4. `git status --short` must show only the intended doc files plus this audit file.

If D3 changes code:

1. `cargo fmt --check`.
2. `cargo clippy --all-targets -- -D warnings`.
3. `cargo test`.
4. Linux and Windows e2e suites.
5. Update the dry-run assertions in both e2e scripts and `foton-handoff-e2e-scripts.md` group 3.

## Notes

- The benchmark numbers were not re-measured. The scenario names and iteration counts match both speedtest scripts.
- The v0.1.7 version is consistent across `Cargo.toml`, `Cargo.lock`, `CHANGELOG.md`, README and the git tag.
- `release/v0.1.7/SHA256SUMS.txt` and the six assets were not re-verified in this audit.
