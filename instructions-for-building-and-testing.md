# foton-handoff

Rust implementation of the foton-handoff CLI.

## Build

Shipped builds come from CI. `.github/workflows/build.yml` builds Linux glibc,
static Linux musl (x86_64 and aarch64), Windows (x86_64 and arm64, native MSVC,
`+crt-static`) and macOS arm64 (native Apple Silicon) on every push and pull
request; a `v*` tag publishes the binaries as a GitHub Release. The tag name
follows `Cargo.toml`, so keep `Cargo.toml`, `Cargo.lock` and `CHANGELOG.md` in
step.

Windows builds embed a version resource (`build.rs` via `tauri-winres`): product
metadata in the file properties and `FileVersion` / `ProductVersion` derived from
`Cargo.toml`. The resource compiler is found automatically -- `rc.exe` from the
Windows SDK for MSVC targets, mingw-w64 `windres` for GNU targets. Set `RC` to
override.

A local build is optional and needs only the toolchain pinned in
`rust-toolchain.toml`:

```text
cargo build --release
```

Static Linux musl build (self-contained target, no external musl toolchain):

```text
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl
```

**Windows cross-build (mandatory static linking):**

```text
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-pc-windows-gnu
```

The cross-target linker is named in `.cargo/config.toml` and must exist in
`PATH`; the matching `windres` is needed for the version resource. Self-contained
executable is mandatory: the Windows binary must have no external DLL
dependencies.

The ARM64 Windows binary is built by CI only, on the native `windows-11-arm`
runner with `aarch64-pc-windows-msvc`.

The macOS ARM64 binary is built by CI only, on the native `macos-14` runner with
the host `aarch64-apple-darwin` target. `build.rs` skips the Windows resource on
non-Windows targets, so no Cargo change is needed. The binary is ad-hoc signed
after the build (`codesign --force --sign -`); it is not notarized, so a
downloaded copy needs `xattr -d com.apple.quarantine` before Finder will launch
it.

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

CI runs the full suite on Linux and Windows: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`, a release build, and
the matching e2e script. The two static musl jobs build their own target, fail
if the ELF has a dynamic interpreter (`PT_INTERP`), and run the same e2e suite;
the aarch64 job runs it on a native arm64 runner. The Windows arm64 job does the
same on a native arm64 runner, additionally asserting the PE machine type and
the version resource fields. The macOS arm64 job builds on a native Apple
Silicon runner, checks the arch with `lipo`, re-signs ad hoc, and runs the same
bash e2e suite.

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

The same script accepts a static musl binary:

```text
bash ../scripts/e2e-linux.sh ./target/x86_64-unknown-linux-musl/release/foton-handoff
```

## Windows e2e

After building, run the smoke test on Windows, again from the crate folder:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File ..\scripts\e2e-windows.ps1 -Bin <path-to-foton-handoff.exe>
```

`-Bin` is optional when the release build sits at its default location.
