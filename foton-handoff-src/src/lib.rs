//! foton-handoff core library.
//!
//! Modular building blocks for foton-handoff:
//!   paths    - root/archive location
//!   parse    - project name from handoff filename
//!   store    - find, prune, write handoff files
//!   commands - subcommand handlers (each returns an exit code)

pub mod commands;
pub mod parse;
pub mod paths;
pub mod store;

pub use commands::{read, write};
