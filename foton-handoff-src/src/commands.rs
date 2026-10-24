//! Subcommand handlers. Each handler returns a process exit code.

use std::io::{self, Read};

use crate::paths;
use crate::store::{newest_for, prune, prune_plan, write_new};

pub fn read(project: &str, _dry_run: bool) -> i32 {
    let root = paths::root();
    let newest = match newest_for(&root, project) {
        Some(p) => p,
        None => {
            eprintln!(
                "error: no handoff found for project '{}' -- no memory yet; proceed to write (dry-run -n first)\nmandatory: tell the user to manually check the project's handoff folder before any write",
                project
            );
            return 1;
        }
    };
    match std::fs::read_to_string(&newest) {
        Ok(text) => {
            print!("{}", text);
            0
        }
        Err(e) => {
            eprintln!("error: could not read '{}': {}", newest.display(), e);
            1
        }
    }
}

pub fn write(project: &str, dry_run: bool) -> i32 {
    let mut new_text = String::new();
    if let Err(e) = io::stdin().read_to_string(&mut new_text) {
        eprintln!("error: could not read stdin: {}", e);
        return 1;
    }
    if new_text.trim().is_empty() {
        eprintln!("error: no handoff text received on stdin");
        return 1;
    }

    let root = paths::root();
    let plan = prune_plan(&root, project);
    if dry_run {
        if plan.is_empty() {
            println!("would archive: (nothing)");
        }
        for (src, dest) in &plan {
            let rel = dest
                .strip_prefix(&root)
                .unwrap_or(dest)
                .display()
                .to_string()
                .replace('\\', "/");
            println!(
                "would archive: {} -> {}",
                src.file_name().unwrap_or_default().to_string_lossy(),
                rel
            );
        }
        println!("would write:   newest for project '{}'", project);
        return 0;
    }

    if let Err(e) = prune(&root, project) {
        eprintln!("error: prune failed: {}", e);
        return 1;
    }
    match write_new(&root, project, &new_text) {
        Ok(_) => 0,
        Err(e) => {
            eprintln!("error: write failed: {}", e);
            1
        }
    }
}
