# foton-handoff

Rust implementation of the foton-handoff CLI.

## Build

```text
cargo build --release
```

Requires the pinned toolchain in `rust-toolchain.toml`.

**Windows cross-build (mandatory static linking):**

```text
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-pc-windows-gnu
```

Self-contained executable is mandatory. The Windows binary must have no external DLL dependencies.

## Usage

```text
foton-handoff read  <project> [-n]
foton-handoff write <project> [-n]
```

- `read` prints the newest handoff for `<project>` to stdout.
- `write` reads new handoff text from stdin, archives existing handoffs for that project into `handoffarchive/`, and writes the new handoff.
- `-n` / `--dry-run` previews what `write` would do without changing anything.
- Always pass the project name quoted (`"proj_name"`), multi-word names included.

## Root directory

The handoff root is the directory containing the executable. `handoffarchive/` is created as a sibling of the exe if it doesn't exist. The agent has no control over storage location -- no environment variables, no CWD influence. All paths are relative to the exe. Filenames use UTC datetime: `{YYYY-MM-DD_HHMM}_{project}.md`.

## Examples

```text
echo "# My Project update" | foton-handoff write myproject
foton-handoff read myproject
foton-handoff write myproject -n < draft.md
```

## Testing

```text
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
```

## Linux e2e

After building, run the smoke test on Linux. Commands assume the current
directory is this crate folder (`foton-handoff/`); the scripts live in the
sibling project-root `scripts/` directory:

```text
bash ../scripts/e2e-linux.sh ./target/release/foton-handoff
```

## Windows e2e

After building, run the smoke test on Windows, again from this crate folder:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File ..\scripts\e2e-windows.ps1 -Bin .\target\release\foton-handoff.exe
```

`-Bin` is optional when the release build sits at its default location.
