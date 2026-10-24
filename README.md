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

Builds run in WSL2; the Windows host has no Rust toolchain. Requires the Rust
toolchain pinned in `rust-toolchain.toml`.

One command builds both targets, runs all tests, and runs speedtests:

```bash
wsl -d Ubuntu -- bash -c 'source $HOME/.cargo/env && cd foton-handoff-proj && bash scripts/build-and-test-all.sh'
```

Or run the steps manually:

```bash
cd foton-handoff-proj/foton-handoff-src
source $HOME/.cargo/env
cargo build --release
```

The Windows .exe is a cross-build and must statically link the C runtime:

```bash
RUSTFLAGS="-C target-feature=+crt-static" \
  cargo build --release --target x86_64-pc-windows-gnu
```

The built binaries stay in the crate `target/` folder; the two ship binaries are
copied to `release/`. A GitHub Actions workflow (`.github/workflows/build.yml`)
runs the same checks on the private remote
`chezhenkie/foton-handoff-agent-memory`; local builds still run in WSL.

## Project layout

```text
foton-handoff-proj\
├── .github\
│   └── workflows\
│       └── build.yml
├── .gitignore
├── agents.md                    (gitignored)
├── README.md
├── foton-handoff-design-and-state.md
├── foton-handoff-e2e-scripts.md
├── foton-handoff-performance-benchmarks.md
├── instructions-for-building-and-testing.md
├── foton-handoff-src\
│   ├── .cargo\
│   │   └── config.toml
│   ├── src\
│   │   ├── commands.rs
│   │   ├── lib.rs
│   │   ├── main.rs
│   │   ├── parse.rs
│   │   ├── paths.rs
│   │   └── store.rs
│   ├── Cargo.toml
│   ├── Cargo.lock
│   ├── rust-toolchain.toml
│   └── .gitignore
├── release\                     (gitignored)
│   ├── foton-handoff
│   └── foton-handoff.exe
└── scripts\
    ├── build-and-test-all.sh
    ├── e2e-linux.sh
    ├── e2e-windows.ps1
    ├── speedtest-linux.sh
    └── speedtest-windows.ps1
```

Binaries are not tracked by git; they are built locally in WSL, released into
`release\`, and stay under `foton-handoff-src/target/` as build output. The
project root itself never holds a binary.

## Testing

Run all checks, builds, e2e tests, and speedtests in one command:

```bash
wsl -d Ubuntu -- bash -c 'source $HOME/.cargo/env && cd foton-handoff-proj && bash scripts/build-and-test-all.sh'
```

Or run individual steps:

```bash
cd foton-handoff-src
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
bash ../scripts/e2e-linux.sh ./target/release/foton-handoff
```

Windows e2e:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ..\scripts\e2e-windows.ps1 -Bin .\target\x86_64-pc-windows-gnu\release\foton-handoff.exe
```

Speedtests (run from WSL):

```bash
bash scripts/speedtest-linux.sh foton-handoff-src/target/release/foton-handoff
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\speedtest-windows.ps1 -Bin foton-handoff-src\target\x86_64-pc-windows-gnu\release\foton-handoff.exe
```

## CI

GitHub Actions workflow `.github/workflows/build.yml` on the private repository
`https://github.com/chezhenkie/foton-handoff-agent-memory` (branch `main`):
`fmt`, Clippy `-D warnings`, unit tests, release build, e2e suite, and a static
CRT check on Windows; both binaries are uploaded as artifacts. Local builds and
tests still run in WSL via `scripts/build-and-test-all.sh`.

Dependencies are locked (`chrono = "=0.4.45"`, pinned toolchain, checked-in
`Cargo.lock`) for reproducible builds. Current source-truth version: v0.1.2.
