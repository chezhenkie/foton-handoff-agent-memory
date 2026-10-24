# Changelog

All notable changes to foton-handoff. Dates are UTC.

## Unreleased

- Source folder renamed `foton-handoff/` -> `foton-handoff-src/`; `instructions-for-building-and-testing.md` moved from the crate folder to the project root; scripts, CI and docs follow the new paths.
- `release/` added at the project root as the ship location for both binaries (`foton-handoff`, `foton-handoff.exe`), gitignored. Build output stays under `foton-handoff-src/target/`; the project root itself holds no binary.
- Private GitHub remote `chezhenkie/foton-handoff-agent-memory` with a CI workflow: `fmt`, Clippy `-D warnings`, unit tests, release build and e2e suite on Linux and Windows, a static CRT check on Windows, and both binaries uploaded as artifacts.
- `.gitattributes` normalizes text files to LF so CI checkouts match local builds.
- `Cargo.lock` version corrected from `0.1.0` to `0.1.2` to match `Cargo.toml`.
- Tag-triggered release job restored in `.github/workflows/build.yml`: a `v*` tag push runs both build jobs, then publishes `foton-handoff-linux`, `foton-handoff-windows.exe` and `SHA256SUMS.txt` to a GitHub Release with generated notes.
- Actions bumped to current majors: `actions/checkout@v7`, `actions/upload-artifact@v7`, `actions/download-artifact@v8` (Node 24 runtime, removes the v4 deprecation annotation).

## v0.1.2 - 2026-08-22

- `read` on a project with no memory exits 1 and prints a two-line agent instruction on stderr: no memory yet (normal on first use), proceed to write with a dry-run (`-n`) first, and it is mandatory to tell the user to manually check the project's handoff folder before any write.
- Agent prompt reworked: documents follow a fixed section structure; `<project>` is the exact name of the current project folder.
- Docs updated: README, design/state doc, e2e scripts guide.

## v0.1.1 - 2026-08-22

CI validation release; shipped binaries are code-identical to v0.1.0.

- Lint job added (`cargo fmt --check`, `clippy -D warnings`); it gates both build jobs.
- Unit tests and both 14-group e2e suites run inside CI on every tag against freshly built binaries.
- Release notes templated via `.github/release-notes-template.md`.
- Fixed: `gh release create` needed explicit `--repo` because the release job has no git checkout.
- Fixed: `rustup target add` must run inside the crate directory so the pinned toolchain applies.
- Fixed: Windows e2e empty-stdin group under Actions -- zero-byte file redirect replaces the PowerShell null pipe.
- Linux builds confirmed on musl after static glibc measured ~1.22 MB vs musl ~465 KB.

## v0.1.0 - 2026-08-22

Initial release.

- Rust CLI with chained-memory semantics: `write` archives the current handoff into `handoffarchive/` and replaces it; `read` prints the newest.
- UTC-stamped filenames `{YYYY-MM-DD_HHMM}_{project}.md`; exact, case-insensitive matching; `-2`/`-3` suffixes on same-minute collisions.
- Storage root hardcoded to the directory containing the executable. No environment variables, no CWD influence.
- Strict argument parsing; exit codes 0 (ok), 1 (runtime), 2 (usage).
- Fully static Windows exe (MSVC, `+crt-static`) and fully static Linux binary (musl).
- Tag-triggered release pipeline: fmt/clippy lint gate, unit tests, and both 14-group e2e suites before publishing.
