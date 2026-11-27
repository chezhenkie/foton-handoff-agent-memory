//! Shared config: resolves the handoff root and archive paths.
//!
//! Root is the executable's own directory, resolved via `current_exe()`.
//! The agent has zero control over storage location -- no environment
//! variables. `current_dir()` is used only if `current_exe()` fails.
//! `handoffarchive/` is a sibling of the exe.

use std::env;
use std::path::PathBuf;

pub fn root() -> PathBuf {
    env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|p| p.to_path_buf()))
        .unwrap_or_else(|| env::current_dir().unwrap_or_else(|_| PathBuf::from(".")))
}

pub fn archive() -> PathBuf {
    root().join("handoffarchive")
}
