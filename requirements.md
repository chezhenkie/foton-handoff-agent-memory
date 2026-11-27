# Requirements

The conditions a host, build and test environment must meet. Usage is in
[README.md](README.md); build and test steps are in
[instructions-for-building-and-testing.md](instructions-for-building-and-testing.md).

## Runtime host

- One of the released targets: Linux x86_64 glibc, Linux x86_64 or aarch64
  musl, Windows x86_64 or arm64, or macOS arm64. No other target is built or
  tested.
- A writable directory holding the executable. The tool writes the new handoff
  there and moves older files for the project into `handoffarchive/` beside it.
  Storage follows `current_exe()`, falling back to the working directory when
  that fails, so the executable must be readable and may sit on read-only media
  only if no `write` is attempted.
- A filesystem that supports rename within the executable's directory, because
  archiving is a rename.
- Text on standard input for `write`. Empty input exits 1; the caller supplies
  the whole handoff.
- A clock in UTC. Filenames carry `{YYYY-MM-DD_HHMM}` in UTC; a wrong local
  offset does not change behaviour, but a wrong system clock does.

## Build toolchain

- Rust 1.98.0 with rustfmt and clippy, as pinned in
  `foton-handoff-src/rust-toolchain.toml` with the minimal profile.
- Network access to crates.io on the first build. The only runtime dependency
  is `chrono =0.4.45`; the only build dependency is `tauri-winres =0.3.7`.
- A native linker for the host target. The glibc build uses the system
  toolchain; the musl build needs only `rustup target add
  x86_64-unknown-linux-musl` or `aarch64-unknown-linux-musl`, because the musl
  target is self-contained.
- For the Windows GNU cross-build, `x86_64-w64-mingw32-gcc` as named in
  `foton-handoff-src/.cargo/config.toml` and a matching `windres`, both on
  `PATH`, and `RUSTFLAGS="-C target-feature=+crt-static"`. The `RC` variable
  overrides the resource compiler. The resulting binary must have no external
  DLL dependencies.
- For a Windows MSVC build, `rc.exe` from the Windows SDK. `build.rs` embeds
  the version resource on Windows only and skips it on other targets.
- A Windows host must not have a running `foton-handoff.exe` from the same path
  during a rebuild, because the open file blocks the linker.

## Tests

- `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings` and
  `cargo test` offline after the first build; the suite needs no network, no
  credentials and no fixtures outside the crate.
- Bash for `scripts/e2e-linux.sh`, and PowerShell for
  `scripts/e2e-windows.ps1`; both run against a built binary and are invoked
  from `foton-handoff-src/`.
- WSL with PowerShell interop (`wslpath`, `powershell.exe`) for
  `scripts/build-and-test-all.sh`, which runs the format, lint and test pass,
  three builds, three e2e runs and two speedtests in one pass. It does not run
  on a plain bash host.
- CI runners: `ubuntu-latest` and `windows-latest` for the native suites,
  static musl jobs for both Linux architectures, `windows-11-arm` for Windows
  arm64 and `macos-15` for macOS arm64.

## macOS

- The CI binary is ad-hoc signed and not notarized. A downloaded copy needs
  `xattr -d com.apple.quarantine` before Finder launches it.

## Release

- Every push to `main`, every `v*` tag and every pull request to `main` builds
  all targets; a `v*` tag publishes the binaries as a GitHub Release.
- The tag name follows the version in `foton-handoff-src/Cargo.toml`, so
  `Cargo.toml`, `Cargo.lock` and `CHANGELOG.md` stay in step.
