# foton-handoff

Rust implementation of the foton-handoff CLI.

## Build

Shipped builds come from CI. `.github/workflows/build.yml` builds Linux (native)
and Windows (native MSVC, `+crt-static`) on every push and pull request; a `v*`
tag publishes both binaries as a GitHub Release. The tag name follows
`Cargo.toml`, so keep `Cargo.toml`, `Cargo.lock` and `CHANGELOG.md` in step.

A local build is optional and needs only the toolchain pinned in
`rust-toolchain.toml`:

```text
cargo build --release
```

**Windows cross-build (mandatory static linking):**

```text
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-pc-windows-gnu
```

The cross-target linker is named in `.cargo/config.toml` and must exist in
`PATH`. Self-contained executable is mandatory: the Windows binary must have no
external DLL dependencies.

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

CI runs the full suite on both platforms: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`, a release build, and
the matching e2e script.

The same checks run locally without CI:

```text
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
```

`scripts/build-and-test-all.sh` runs all of that plus both builds, both e2e
suites and both speedtests in one pass from a bash host; the Windows steps call
`powershell.exe`, so they only run where PowerShell is available.

## Linux e2e

After building, run the smoke test on Linux. Commands assume the current
directory is the crate folder (`foton-handoff-src/`); the scripts live in the
project-root `scripts/` directory:

```text
bash ../scripts/e2e-linux.sh ./target/release/foton-handoff
```

## Windows e2e

After building, run the smoke test on Windows, again from the crate folder:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File ..\scripts\e2e-windows.ps1 -Bin <path-to-foton-handoff.exe>
```

`-Bin` is optional when the release build sits at its default location.
