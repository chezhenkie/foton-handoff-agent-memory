# foton-handoff-proj

## Intro

`foton-handoff` is a Rust CLI for automated project handoff files.

**Why this exists:** foton-handoff was built specifically so an LLM never touches
the handoff files directly. Instead of giving a model free-form read/write
access to its memory, the model only ever calls `read` and `write` through
this CLI. That makes every change auditable, deterministic, and safe — a
controlled interface layer between the LLM and its memory system.



## Binding Rules

**Self-contained executable is mandatory.** The Windows build must be a single standalone binary with no external DLL dependencies. All builds must use `RUSTFLAGS="-C target-feature=+crt-static"` to statically link the C runtime. The executable must run on any Windows system without requiring additional runtime libraries.

**Root resolution is hardcoded to the executable's directory. `handoffarchive/` is created as a sibling of the exe if it doesn't exist. The agent has zero control over where files are stored -- no environment variables, no CWD influence. All paths are relative to the exe location. Filenames use UTC datetime so they are identical across Windows, Linux, and CI.

## Functionality


- A handoff is identified solely by its filename: `{YYYY-MM-DD_HHMM}_{project}.md`.
- `read <project>` prints the newest matching handoff to stdout.
- `write <project>` reads new handoff text from stdin, archives every existing handoff for that project into `handoffarchive/`, then writes the new file.
- Both subcommands accept `-n` / `--dry-run` to preview actions without changing anything.
- Matching is exact and case-insensitive; file contents are never parsed.
- Same-minute name collisions get a `-2`, `-3` suffix in both the root and the archive.
- Success is silent; errors are written to stderr.
- `read` on a project with no memory exits 1 and prints a two-line agent instruction on stderr: no memory yet, proceed to write (dry-run -n first), and it is mandatory to tell the user to manually check the project's handoff folder before any write. Normal on first use.
- Always pass the project name quoted ("proj_name"), multi-word names included.



## Usage

```text
foton-handoff read  <project> [-n]
foton-handoff write <project> [-n]
```

Examples:

```text
foton-handoff read myproj
foton-handoff write myproj < updated-handoff.md
foton-handoff write myproj -n < updated-handoff.md
```

## Agent prompt

Exact prompt given to the agent (same text as in `README.md` and intended for AGENTS.md):

```text
 
# foton-handoff.exe is a chained memory system: 
- every write archives the current memory and replaces it with the text you supply; 
- read returns the latest memory for a project. 
- Memory handoff access goes only through this tool. 
- All documents are structured the same way, like this: 
 <exact project folder root name> ## Short Intro ## one-liners for Binding Rules ## Functionality ## Usage ## Directory tree project 
 ## one-liners for completed phases, major findings and milestones ## current state ## next session steps 
- Call it by absolute path: "<User provided path>\foton-handoff.exe" 
- <project> is the exact name of the current project folder. 
- read  <project>   returns the newest memory for <project>. 
- write <project> [-n]   takes new memory text from stdin, archives the old; -n previews only. 
Mandatory: 
- run every write first with -n; if it errors or anything looks wrong, stop and ask the user. 
- Quote the project name ("proj_name"). 
- At the start of every session: run read to load the current project state before doing anything else. 
- When the user says 'end of session', 'end session', 'Make handoff', 'Handof' or 'handoff': 
  run read, write the updated handoff text, do a dry-run write (-n), then on success do the real write. 
 
```


## Directory tree project

```
foton-handoff-proj/
├── agents.md
├── README.md
├── foton-handoff-design-and-state.md
├── foton-handoff-performance-benchmarks.md
├── instructions-for-building-and-testing.md
├── foton-handoff-src\
│   ├── .cargo\
│   │   └── config.toml
│   ├── .gitignore
│   ├── Cargo.lock
│   ├── Cargo.toml
│   ├── rust-toolchain.toml
│   ├── src\
│   │   ├── commands.rs
│   │   ├── lib.rs
│   │   ├── main.rs
│   │   ├── parse.rs
│   │   ├── paths.rs
│   │   └── store.rs
│   └── target\          (build artifacts: debug\, release\, x86_64-pc-windows-gnu\)
├── release\             (gitignored: foton-handoff, foton-handoff.exe)
└── scripts\
    ├── build-and-test-all.sh
    ├── e2e-linux.sh
    ├── e2e-windows.ps1
    ├── speedtest-linux.sh
    └── speedtest-windows.ps1
```


## Major findings and milestones
- Project rebuilt from ground up in `foton-handoff-proj` after the previous local tree and its GitHub repository were lost. Documents were migrated first; source-code migration is now complete: `Cargo.toml` renamed (package/bin `foton-handoff`, lib `foton_handoff_core`), old identifiers and doc comments swept out of `src/`.
- Functional baseline established first without touching code: the original `foton-handoff.exe` passed a 13-group e2e suite covering commit, read, dry-run, archive moves, same-minute `-2` collision suffixes, cross-project isolation, case-insensitive matching, exit codes 0/1/2 with stderr messages, empty-stdin rejection, `HANDOFF_ROOT` override, and CWD fallback.
- Code audit then drove targeted fixes: stale module comment corrected (root was `HANDOFF_ROOT` else CWD, later fixed to exe-folder-relative); empty/whitespace project names rejected with exit 2 instead of writing unmatchable `{stamp}_.md` files; instructions doc e2e commands corrected to state the crate-folder CWD assumption.
- e2e suites extended to 15 groups on both platforms (group 14: empty-project rejection writes nothing; group 15: invalid-HANDOFF_ROOT warning plus fallback). Linux suite fully green end-to-end: fmt --check, clippy -D warnings, 19 unit tests, release build, all 15 groups.
- Local verification environment established without git/GitHub: Linux (Ubuntu) host with rustup, the pinned 1.98.0 toolchain (+rustfmt/clippy) and build-essential. Cross-build via mingw-w64 considered but intentionally not started.
- Windows verification deferred by decision: the project-root `foton-handoff.exe` predates groups 14/15 and fails them by design; replacing it awaits a fresh build and explicit approval.
- Platform test pair lives at the project root as the single source of truth: `scripts/e2e-windows.ps1` and `scripts/e2e-linux.sh`, identical group numbering, both auto-resolve their binary; Linux candidate detection hardened to require a regular executable file (a directory named like the crate previously matched).
- Test-harness lessons: PS 5.1 can swallow merged native stderr depending on error-action mode, so stderr assertions capture to a file; PS 5.1 additionally drops truly empty-string arguments when calling native executables, so empty-name cases may degrade to the missing-argument path (same exit 2).
- Behavior notes confirmed against documentation: filename stamps are true UTC minutes; project names containing spaces are written with underscores (`my proj` becomes `_my_proj.md`) while `read` normalizes queries so lookups round-trip; a plain `write` always creates an empty `handoffarchive/` sibling even on the first write; `-n` dry-run touches nothing at all.
- Carried over and verified present in current code: parse fix (`DATETIME_PREFIX_LEN` = `15 + 1` with per-position digit checks), `sanitize_topic` normalization fixing read/write round-trips for odd project names, unit tests for `parse` and `store` under mutex-guarded temp dirs with injected root, dependency pins (`chrono = "=0.4.45"`, toolchain `1.98.0`, regenerated lockfile), and cross-environment rules (UTC filenames, exe-relative root, no absolute paths in code).
- Strict argument parsing implemented: `parse_args()` extracted into a pure function in `src/main.rs`; unknown dash-flags rejected (`error: unknown flag`); exactly one positional enforced (`too many arguments (quote the project name)` / `requires a project name`); non-empty validation kept; errors print message + usage, exit 2. 15 unit tests cover valid forms, flag positions, unknown flags, wrong positional counts, whitespace-only project, case-insensitive subcommands.
- e2e suites extended to 16 groups on both platforms (group 16: negative strict-parsing cases `commit -x alpha` / `commit alpha junk` / `read --verbose alpha` exit 2 with nothing written; positive multi-word round-trip `commit "multi word"` -> `read "multi word"`). Linux suite fully green end-to-end: fmt --check, clippy -D warnings, 34 unit tests (19 lib + 15 main), release build, all 16 groups.
- Quoting convention documented in `instructions-for-building-and-testing.md`: *Always pass the project name quoted (`"proj_name"`), multi-word names included.*
- Windows cross-build completed via mingw-w64 from Linux: `x86_64-pc-windows-gnu` target added to pinned 1.98.0 toolchain, `.cargo/config.toml` sets linker to `x86_64-w64-mingw32-gcc`. Fresh `foton-handoff.exe` replaces project-root binary; all 16 Windows e2e groups pass.
- Security isolation fix completed: `HANDOFF_ROOT` env var removed entirely from `src/paths.rs`. Root is now hardcoded to `std::env::current_exe()` parent directory. Store functions refactored to accept `root: &Path` parameter for testability -- no env vars, no global state. E2e scripts copy binary to temp root before running. E2e groups 13 (HANDOFF_ROOT override) and 15 (invalid-HANDOFF_ROOT warning) removed. Both suites at 14 groups, both platforms fully green. 33 unit tests (18 lib + 15 main).
- Binary size review done without code changes: release exe measured at ~1.4 MB
  (static CRT, mingw-w64 cross-build). Size-reduction profile options evaluated
- Repository hygiene change: the project-root `foton-handoff.exe` was deleted and is no longer produced. Binaries now live only in the crate `target/` folder (Windows `target/x86_64-pc-windows-gnu/release/`, Linux `target/release/`). Script default paths, README, and the e2e scripts guide updated to match; no binary is ever copied to the project root.

**Current state** :
- Package/bin renamed to `foton-handoff`, lib to `foton_handoff_core`; old names swept from src.
- Subcommand `commit` renamed to `write` across code, docs, and e2e scripts to avoid confusion with Git/GitHub commits.
- Release binary shrunk via `[profile.release]` (`lto = true`, `codegen-units = 1`, `opt-level = "s"`, `strip = true`). Windows exe now ~339 KB (was ~1.4 MB); Linux release binary ~375 KB.
- Local verification environment established: Linux (Ubuntu) host with rustup, pinned 1.98.0 toolchain, rustfmt/clippy, mingw-w64 cross-compiler and build-essential.
- Strict `parse_args()` in `src/main.rs`: rejects unknown flags, enforces exactly one positional, validates non-empty project; 15 unit tests. 33 total unit tests (18 lib + 15 main).
- Both e2e suites at 14 groups, both platforms fully green. Linux: fmt, clippy -D warnings, 33 unit tests, release build, 14 e2e groups. Windows: mingw-w64 cross-build from Linux with static CRT, 14 e2e groups.
- Root is hardcoded to exe directory via `current_exe()`. No env vars, no CWD influence. Agent has zero control over storage location.
- Project lives on the public remote `chezhenkie/foton-handoff-agent-memory` (branch `main`). CI builds four targets and publishes tag builds as Releases; local builds are optional, build output lives under `foton-handoff-src/target/`, and a local copy can be dropped into `release/` -- the project root itself never holds a binary.
- `.github/workflows/build.yml` runs fmt, Clippy, unit tests, release build and e2e on Linux and Windows for every push and pull request to `main`, and uploads both binaries as artifacts. Two static musl jobs (`ubuntu-latest` x86_64, `ubuntu-24.04-arm` aarch64) build their own target, fail on a dynamic interpreter (`PT_INTERP`) and run the e2e suite natively. A `v*` tag push additionally runs the `release` job: it downloads all four artifacts, renames them to `foton-handoff-linux`, `foton-handoff-windows.exe`, `foton-handoff-linux-musl` and `foton-handoff-linux-arm64-musl`, writes `SHA256SUMS.txt`, and publishes a GitHub Release. The job sets `permissions: contents: write` and passes `--repo` because it has no checkout.
- Local build-and-test orchestrator added: `scripts/build-and-test-all.sh` runs fmt, clippy, unit tests, both builds (Linux native + Windows cross-compile), both e2e suites, and both speedtests in one command. Stops on first failure.
- Speedtest scripts added: `scripts/speedtest-linux.sh` and `scripts/speedtest-windows.ps1` run 7 benchmark scenarios (startup, read with 10/1k/5k files, write with 10/1k files, write -n with 1k files) following the speedtest methodology rules (no cross-filesystem testing).
- Current source-truth version: v0.1.4 (Cargo.toml) and CHANGELOG.
- Agent prompt finalized (chained-memory wording, mandatory dry-run-first rule with stop-and-ask on error, session start/end triggers); embedded verbatim in README (top section) and in this doc. Pasting it into AGENTS.md is a user action.

**Next session** : none planned. Pending user action: paste the agent prompt into AGENTS.md files with the real exe path substituted.

## completed steps

### 1-6. Completed (previous sessions)
- Strict `parse_args()` extracted in `src/main.rs`; unknown flags rejected, positional count enforced, non-empty project validated; errors print message + usage, exit 2.
- 15 unit tests for `parse_args` (valid forms, flag positions, unknown flags, wrong positional counts, whitespace-only project, case-insensitive subcommands).
- e2e group 16 added to both platform scripts: negative strict-parsing cases exit 2 with nothing written; positive multi-word round-trip locks quoting convention.
- Quoting convention documented in `instructions-for-building-and-testing.md`.
- Linux verification green: fmt --check, clippy -D warnings, 34 unit tests, release build, 16 e2e groups.
- Windows cross-build completed via mingw-w64 from Linux; all 16 groups pass.

### 7-9. Completed (this session)
- `HANDOFF_ROOT` env var removed from `src/paths.rs`. Root is `current_exe()` parent, fallback to CWD.
- `WARN_INVALID_HANDOFFROOT` static and warning logic removed.
- Store functions refactored to accept `root: &Path` parameter (testability without env vars).
- `with_temp_root()` replaced by `with_temp_dir()` -- passes temp path directly to store functions.
- E2e groups 13 (HANDOFF_ROOT override) and 15 (invalid-HANDOFF_ROOT warning) removed from both scripts. Suites renumbered to 14 groups.
- E2e scripts copy binary to temp root before running -- exe's `current_exe()` resolves to temp dir.
- Linux green: fmt --check, clippy -D warnings, 33 unit tests, release build, 14 e2e groups.
- Windows green: mingw-w64 cross-build with `+crt-static`, 14 e2e groups. Fresh exe copied to project root.

### 10. Completed (this session)
- Subcommand `commit` renamed to `write` in `src/commands.rs`, `src/lib.rs`, `src/main.rs`, and unit tests.
- All docs updated: `README.md`, `foton-handoff-design-and-state.md`, `foton-handoff-performance-benchmarks.md`, `instructions-for-building-and-testing.md`.
- E2e scripts updated to use `write`: `scripts/e2e-linux.sh`, `scripts/e2e-windows.ps1`.
- Cargo.toml description updated.
- Linux verification green: fmt --check, clippy -D warnings, 33 unit tests, release build, 14 e2e groups.
- Windows cross-build via mingw-w64 with `+crt-static`; fresh `foton-handoff.exe` copied to project root; all 14 Windows e2e groups pass.

### 11. Completed (this session)
- Added `[profile.release]` to `Cargo.toml` with `lto = true`, `codegen-units = 1`, `opt-level = "s"`, `strip = true`.
- Release binary sizes: Windows exe ~339 KB (was ~1.4 MB), Linux binary ~375 KB.
- Linux verification green: fmt --check, clippy -D warnings, 33 unit tests, release build, 14 e2e groups.
- Windows cross-build via mingw-w64 with `+crt-static`; fresh `foton-handoff.exe` copied to project root; all 14 Windows e2e groups pass.

### 12. Completed (this session)
- Local git initialized on `main`; private GitHub repo `ELongRange/foton-agent-handoff` created and pushed.
- Tag-triggered release workflow built; v0.1.0 published with Windows MSVC static-CRT exe (~314 KB) and Linux musl fully-static binary (~465 KB).
- Workflow lessons: `gh release create` needs explicit `--repo` when the job has no git checkout; setup-rust-toolchain's `target:` input does not reach the pinned toolchain -- run `rustup target add <target>` inside the crate dir so `rust-toolchain.toml` applies; static glibc (+crt-static on linux-gnu) measured ~1.22 MB vs musl ~465 KB, Linux builds switched to musl.
- CI extended toward local parity: lint job (fmt --check, clippy -D warnings), e2e suites run in CI against freshly built binaries, release notes templated (`.github/release-notes-template.md`).
- Validation tag `v0.1.1` exercised the full pipeline; two CI-only failures found and fixed: (a) Windows e2e group 12 exited 0 under Actions because a PowerShell null pipe (`$null |`) does not deliver EOF to the child in headless nested consoles -- replaced with `Start-Process -RedirectStandardInput` from a zero-byte file; (b) release job lacked checkout so the notes template was absent -- added `actions/checkout@v4`. v0.1.1 then published green: lint, unit tests, both 14-group e2e suites, templated notes, ~314 KB exe / ~465 KB musl binary.
- `foton-handoff-e2e-scripts.md` added at project root documenting invocation, binary discovery, sandbox mechanics, all test groups with expected outcomes, exit-code contract, and platform-specific implementation notes.
- README reworked: rationale intro (isolation, internal archive logic, minimal arg surface), agent prompt moved to top section, layout tree made relative and includes workflow files, badge/CI fixed to `release.yml`.
- Agent prompt embedded verbatim in README and this doc; `.gitattributes` added pinning shell/PS line endings.
- All three release bodies rewritten with distinct `## Changes` sections (v0.1.0 initial, v0.1.1 CI validation, v0.1.2 stderr instruction); release workflow now prepends an auto-generated `## Changes` list from `git log <prev-tag>..<tag>` above the template on every future tag (release checkout uses `fetch-depth: 0`).

### 13. Completed (this session)
- Repository flipped to public (`gh repo edit --visibility public`); README, CI section and e2e guide no longer describe a private remote.
- CI extended with `linux-musl` (`x86_64-unknown-linux-musl` on `ubuntu-latest`) and `linux-musl-arm64` (`aarch64-unknown-linux-musl` on `ubuntu-24.04-arm`, the arm64 hosted runner for public repositories). Both build with `rustup target add` against pinned 1.98.0, fail on a dynamic interpreter (`PT_INTERP`), and run the 14-group e2e suite; arm64 runs natively.
- Self-contained musl linking confirmed with toolchain 1.98.0: the `x86_64-unknown-linux-musl` release build is static-pie, 475,760 B, no interpreter, and passes a write/read smoke test. No external musl toolchain (`musl-tools`) needed.
- Release job publishes four binaries plus `SHA256SUMS.txt`; the glibc build remains `foton-handoff-linux`.
- Version bumped to 0.1.3 in `Cargo.toml` and `Cargo.lock`; CHANGELOG entry added.
- v0.1.3 published all four assets. Verification found `SHA256SUMS.txt` recorded `dist/` path prefixes, so `sha256sum -c` failed once the assets were downloaded into one folder; the hash values themselves were correct. The release job now writes the sums inside `dist/` with bare filenames, and v0.1.4 re-releases all four assets with a verifiable sums file.
