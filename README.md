# foton-handoff * isolated agent-proof memory system
# small, fast, robust , portable and multiplatform

A small CLI for managing project handoff files. Each `write` creates a new
UTC-dated Markdown file and moves older handoffs for the same project into
`handoffarchive/`. Nothing is deleted or overwritten in place.

Why it exists: total isolation between the agent and its memory. The archive
logic runs entirely inside the executable — moving, dating, and suffixing
files is invisible to the agent,never touching archive files.
The argument surface given to the agent is minimal by design:
one subcommand and one quoted project name, optional flag `-n`;

Use it so an LLM never touches memory handoff files directly: it only calls `read`
and `write` through this tool.

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

## How it works

A handoff is identified solely by its filename:

```text
{YYYY-MM-DD_HHMM}_{project}.md     e.g. 2026-08-21_1435_myproject.md
```

- Datetimes are UTC.
- Matching is exact and case-insensitive.
- `read <project>` prints the newest matching handoff to stdout.
- `write <project>` reads new handoff text from stdin, archives existing
  handoffs into `handoffarchive/`, then writes the new file.
- Same-minute name collisions get `-2`, `-3`, ... suffixes in both root and
  archive.
- Success is silent; errors go to stderr with a non-zero exit code.
- `read` on a project with no memory exits 1 and tells the agent on stderr that
  no memory exists yet, to proceed with a dry-run write first, and to have the
  user manually check the handoff folder. This is normal on first use.
- Always quote the project name (`"proj_name"`), including multi-word names.

## Usage

```text
foton-handoff read  <project> [-n]
foton-handoff write <project> [-n]
```

Examples:

```bash
foton-handoff read myproj
foton-handoff write myproj < updated-handoff.md
foton-handoff write myproj -n < updated-handoff.md
```

`-n` / `--dry-run` is accepted by both subcommands. On `write` it prints the
archive/write actions without touching the filesystem.

Exit codes:

- `0` — success
- `1` — runtime error: no matching handoff, empty stdin, or I/O failure
- `2` — usage error: missing arguments, unknown subcommand, or empty project
  name

## Handoff root

The handoff root is the directory containing the executable.
`handoffarchive/` is created as a sibling of the executable. The agent has no
control over the storage location: no environment variables, no CWD influence.

## Build

CI builds four targets. Every push and pull request runs the check and test
matrix in `.github/workflows/build.yml`:

- `linux` - Ubuntu x86_64, glibc, dynamically linked. fmt, Clippy, unit tests,
  release build, e2e.
- `linux-musl` - `x86_64-unknown-linux-musl`, static. Build, interpreter check,
  e2e.
- `linux-musl-arm64` - `aarch64-unknown-linux-musl` on a native arm64 runner,
  static. Build, interpreter check, e2e.
- `windows` - native MSVC with `+crt-static`. fmt, Clippy, unit tests, release
  build, static CRT check, e2e.

A `v*` tag then publishes all four binaries as a GitHub Release. No local
toolchain is needed to produce a shipped build, and the build host is unrelated
to the machine the binary runs on.

A local build is optional and needs only the toolchain pinned in
`foton-handoff-src/rust-toolchain.toml`:

```bash
cd foton-handoff-src
cargo build --release
```

A static Linux build uses the self-contained musl target; no external musl
toolchain is required:

```bash
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl
```

Cross-building the Windows .exe from a non-Windows host needs the
`x86_64-pc-windows-gnu` target, a mingw-w64 linker named in
`foton-handoff-src/.cargo/config.toml`, and a static C runtime:

```bash
RUSTFLAGS="-C target-feature=+crt-static" \
  cargo build --release --target x86_64-pc-windows-gnu
```

Build output stays under `foton-handoff-src/target/`. `release/` at the project
root is an optional local drop point for built binaries and is gitignored; the
project root itself never holds a binary.

## Project layout

```text
foton-handoff-proj/
+-- .github/
|   +-- workflows/
|       +-- build.yml
+-- .gitignore
+-- agents.md                    (gitignored)
+-- README.md
+-- foton-handoff-design-and-state.md
+-- foton-handoff-e2e-scripts.md
+-- foton-handoff-performance-benchmarks.md
+-- instructions-for-building-and-testing.md
+-- foton-handoff-src/
|   +-- .cargo/
|   |   +-- config.toml
|   +-- src/
|   |   +-- commands.rs
|   |   +-- lib.rs
|   |   +-- main.rs
|   |   +-- parse.rs
|   |   +-- paths.rs
|   |   +-- store.rs
|   +-- Cargo.toml
|   +-- Cargo.lock
|   +-- rust-toolchain.toml
|   +-- .gitignore
+-- release/                     (gitignored)
|   +-- foton-handoff
|   +-- foton-handoff.exe
+-- scripts/
    +-- build-and-test-all.sh
    +-- e2e-linux.sh
    +-- e2e-windows.ps1
    +-- speedtest-linux.sh
    +-- speedtest-windows.ps1
```

Binaries are not tracked by git. CI builds and publishes them as Releases; a
local build can be dropped into `release/` for convenience. Build output stays
under `foton-handoff-src/target/`, and the project root itself never holds a
binary.

## Testing

`scripts/build-and-test-all.sh` runs the local suite in one pass: fmt, Clippy,
unit tests, the glibc and musl builds, both e2e suites, both speedtests. It
resolves the crate path from its own location and needs a bash host; the Windows
steps call `powershell.exe`, so they only run where PowerShell is available.

```bash
bash scripts/build-and-test-all.sh
```

Individual steps:

```bash
cd foton-handoff-src
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
bash ../scripts/e2e-linux.sh ./target/release/foton-handoff
```

Windows e2e and speedtest take the path of the Windows binary:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\e2e-windows.ps1 -Bin <path-to-foton-handoff.exe>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\speedtest-windows.ps1 -Bin <path-to-foton-handoff.exe>
```

Linux speedtest:

```bash
bash scripts/speedtest-linux.sh <path-to-foton-handoff>
```

## CI

GitHub Actions workflow `.github/workflows/build.yml` on the public repository
`https://github.com/chezhenkie/foton-handoff-agent-memory` (branch `main`):
fmt, Clippy `-D warnings`, unit tests, release build, e2e suite, and a static
CRT check on Windows; the two musl jobs run their own release build, interpreter
check and e2e suite. All four binaries are uploaded as artifacts. A push of a
`v*` tag runs the same jobs and then publishes a GitHub Release with
`foton-handoff-linux`, `foton-handoff-windows.exe`, `foton-handoff-linux-musl`,
`foton-handoff-linux-arm64-musl` and `SHA256SUMS.txt`. CI is the only source of
shipped binaries; local runs are a development convenience.

Dependencies are locked (`chrono = "=0.4.45"`, pinned toolchain, checked-in
`Cargo.lock`) for reproducible builds. Current source-truth version: v0.1.4.
