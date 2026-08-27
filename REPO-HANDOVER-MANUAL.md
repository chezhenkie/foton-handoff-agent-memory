# Repo Handover / Rebuild Manual

Procedure for running a "post-account-deletion restart" on ANY local repo,
producing a fresh local git repo with no remote, and de-stale-ing all docs.

The user deletes their git/GitHub account and all local git files, then restarts
opencode from each repo folder with an instruction like:

> "Check handle first then check all docs for stale. After that build new git, no github for now."
> (also: "check handofe" == check handoff, "all dogs/docs" == all docs)

Follow this procedure exactly, in order.

---

## Phase 0 - Read the handoff (mandatory)

The chained-memory system is a mandatory first step on every session.

```powershell
& "foton-handoff.exe" read "PROJECTNAME"
```

- PROJECTNAME is the exact current project folder name, always quoted.
- Extract from the handoff:
  - the "Binding Rules" (gitignore contents, remote, build method, version)
  - the expected directory tree
  - the "Current state" and "Next session steps"
- Note what the handoff claims the repo SHOULD look like so you can diff against disk.

## Phase 1 - Survey the actual state on disk

Do NOT assume docs are missing or the environment is broken. Assumptions usually
come from misreading. Compare disk to the handoff.

1. Confirm whether a git repo exists at all:
   ```powershell
   git status ; git rev-parse --is-inside-work-tree
   ```
   Expected in this scenario: `fatal: not a git repository` (everything deleted).

2. List ALL files, including hidden and recursive, to find what is and isn't there:
   - Directory listing (read tool): `C:\...\<project>`
   - Hidden/recursive full paths (bash): `Get-ChildItem -Recurse -Force | Select-Object -ExpandProperty FullName`
   - Always use the glob tool for scans (read-only), not `Get-ChildItem` for searching.

3. Compare against the handoff tree:
   - Missing files that should exist (e.g. `.gitignore`, `.github/workflows/build.yml`) -> recreate.
   - Stray files not in the handoff tree -> decide track vs ignore (ASK user).

## Phase 2 - Check all docs for stale content

Search every markdown file for stale references. The specific stale signals for a
"deleted account" handover are:

- The OLD GitHub remote URL / account name (e.g. `github.com/SOMENAME/...`)
- GitHub Releases / Actions / other dead-links under the old account
- "build via GitHub Actions, no local toolchain" if a local WSL toolchain now exists
- Version numbers that conflict across files
- Any instruction that no longer matches reality (git push, tags, clone URLs)

Grep across the whole repo:

```powershell
# adapt the terms to the project
# github, GitHub, 0.7, 0.8, remote, oldaccountname, Actions, CI, git
```

Also check toolchain availability in WSL, because "we have local build option now, check wsl"
is a common signal (global AGENTS.md: builds happen in WSL2 only):

```powershell
wsl -d Ubuntu -- bash -c 'source $HOME/.cargo/env; which cargo rustc; cargo --version; rustup target list --installed'
# cargo, rustc versions + x86_64-pc-windows-gnu target and MinGW linker must be present
wsl -d Ubuntu -- bash -c 'which x86_64-w64-mingw32-gcc'
```

RESOLVE version conflicts by asking the user. Do not self-decide between e.g.
source files (Cargo.toml, README) vs AGENTS.md. AGENTS.md is FORBIDDEN to edit
(it claims a different version is common after renames); treat the source tree as truth
unless the user says otherwise.

## Phase 3 - Ask before making substantive choices

Per the global AGENTS.md, when uncertain do not make wild tool calls or edits: ask.
Use the multi-choice `question` tool. Key decisions to confirm before acting:

1. **Which version is source truth** (when AGENTS.md vs source disagree).
2. **How to treat GitHub references** in docs: strip vs keep (user may be re-creating
   a GitHub under a NEW name later - in that case KEEP the CI file and don't strip links).
3. **Git init scope**: fresh init, recreate .gitignore and .github/workflows/build.yml,
   set a remote or not ("no github for now" = no remote; keep file for future).
4. **Stray files** (unlisted pngs, leftover binaries): ignore vs commit.

Only proceed once the user answers. Do not guess.

## Phase 4 - Update the docs

Apply the confirmed decisions. From the reference run on bridge-rust-proj:

- README: rewrite the "Building from source" section to the LOCAL WSL build, e.g.
  ```
  cd <project>/<crate>
  source $HOME/.cargo/env
  cargo build --release --target x86_64-pc-windows-gnu
  ```
  Mention the CI workflow file stays for when a remote is re-added under a new name.
- Remove dead old-account URLs (Releases, remote, fork links). Replace with neutral text
  ("build from source", "release once the new repo is created").
- BRIDGE-SPEC / any spec: update the CI section similarly (local WSL + future CI).
- CHANGELOG: historical entries are left as-is; only the working tree's current state changes.
- Version: keep the source-truth version consistently; do NOT touch AGENTS.md.

## Phase 5 - Recreate the ignored/tooling files that were deleted

Because git was deleted, these are typically gone and must be rebuilt:

1. Root `.gitignore` - recreate per the handoff "Binding Rules". Common entries:
   `AGENTS.md`, `extra-docs/`, `*.exe`, `writefile.py`, stray PNGs.
2. `.github/workflows/build.yml` - recreate the CI workflow (Clippy + test + build,
   upload artifact) so the repo is GitHub-ready for the future remote.

Verify the ignore rules behave:

```powershell
git status --ignored --short | Select-String '^!!'
```

Confirm the intended files are visible/untracked and the ignored ones disappear.

## Phase 6 - Build the new git (NO remote for now)

1. Check Windows git is present: `git --version` (usually C:\Program Files\Git\cmd\git.exe).
2. Set git identity. The old account's identity is stale; the user chose
   `Your Name / you@example.com` (local AND global). Explain local vs global:
   - LOCAL: written to `<repo>/.git/config`, applies only to this repo.
   - GLOBAL: written to `~/.gitconfig`, applies to ALL repos unless overridden locally.
   Ask if global should also change when the old global identity references the deleted account.
   ```powershell
   git config user.name "Your Name"; git config user.email "you@example.com"
   git config --global user.name "Your Name"; git config --global user.email "you@example.com"
   ```
3. `git init`
4. `git add -A`
5. Inspect `git status --short` (LF/CRLF warnings are normal on Windows - ignore).
6. `git commit -m "Reinitialize repo after account deletion; local WSL build; v0.7.0 source truth"`
   (adapt version text to the actual source-truth version)
7. Verify: `git status` clean, `git log --oneline -1`, `git remote -v` shows NO remote.

## Phase 7 - Update the handoff (end of session)

Mandatory handoff flow: read, write updated text, dry-run `-n`, then real write.

1. Write updated handoff content to a temp file INSIDE the workspace
   (e.g. `<project>\handoff-tmp.txt`) - never external temp dirs (permission walls).
2. Dry-run first - note the `-n` goes AFTER the project name:
   ```powershell
   & cmd /c "`"<exe>`" write `"PROJECT`" -n < `"C:\...\<project>\handoff-tmp.txt`""
   ```
3. Confirm the dry-run output (would archive / would write) looks correct.
4. Real write (same command without `-n`).
5. Verify with `read`.
6. Delete the temp file; confirm `git status --short` is clean.

Handoff must be updated: remote state (none), version source truth, new identity,
recreated .gitignore + build.yml, initial commit hash.

---

## Summary checklist

- [ ] Handoff read
- [ ] Disk surveyed vs handoff tree
- [ ] All docs grepped for stale github/version/account refs
- [ ] WSL build toolchain verified (target + MinGW linker)
- [ ] User questions answered (version, github treatment, git init, stray files)
- [ ] Docs updated (README build section, spec CI, dead URLs removed)
- [ ] Root .gitignore recreated + verified
- [ ] .github/workflows/build.yml recreated
- [ ] git init + identity (local/global) + initial commit + no remote
- [ ] Handoff dry-run + real write + cleanup
- [ ] Working tree clean
