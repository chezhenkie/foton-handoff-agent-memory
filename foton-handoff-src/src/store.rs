//! Store operations: find, prune, and write handoff files.

use std::fs;
use std::path::{Path, PathBuf};

use chrono::Utc;

use crate::parse::{project_from_name, sanitize_topic};

pub fn matching_files(root: &Path, project: &str) -> Vec<PathBuf> {
    let needle = sanitize_topic(project, 40).to_lowercase();
    let mut out = Vec::new();
    let entries = match fs::read_dir(root) {
        Ok(e) => e,
        Err(_) => return out,
    };
    for entry in entries.flatten() {
        let name = match entry.file_name().to_str() {
            Some(s) => s.to_string(),
            None => continue,
        };
        if !name.ends_with(".md") {
            continue;
        }
        if let Some(proj) = project_from_name(&name) {
            if proj.to_lowercase() == needle {
                out.push(entry.path());
            }
        }
    }
    out.sort();
    out
}

pub fn newest_for(root: &Path, project: &str) -> Option<PathBuf> {
    let mut matches = matching_files(root, project);
    matches.pop()
}

fn archive_dest(root: &Path, name: &str) -> PathBuf {
    let archive = root.join("handoffarchive");
    let stem = name
        .strip_suffix(".md")
        .map(|s| s.to_string())
        .unwrap_or_else(|| name.to_string());
    let mut dest = archive.join(name);
    let mut n = 1usize;
    while dest.exists() {
        n += 1;
        dest = archive.join(format!("{}-{}.md", stem, n));
    }
    dest
}

pub fn prune_plan(root: &Path, project: &str) -> Vec<(PathBuf, PathBuf)> {
    matching_files(root, project)
        .into_iter()
        .map(|old| {
            let name = old
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or_default()
                .to_string();
            (old, archive_dest(root, &name))
        })
        .collect()
}

pub fn prune(root: &Path, project: &str) -> std::io::Result<usize> {
    let archive = root.join("handoffarchive");
    fs::create_dir_all(&archive)?;
    let mut moved = 0;
    for (src, dest) in prune_plan(root, project) {
        fs::rename(&src, &dest)?;
        moved += 1;
    }
    Ok(moved)
}

pub fn write_new(root: &Path, project: &str, text: &str) -> std::io::Result<PathBuf> {
    let now = Utc::now().format("%Y-%m-%d_%H%M").to_string();
    let topic = sanitize_topic(project, 40);
    let mut name = format!("{}_{}.md", now, topic);
    let mut path = root.join(&name);
    let mut n = 1usize;
    while path.exists() {
        n += 1;
        name = format!("{}_{}-{}.md", now, topic, n);
        path = root.join(&name);
    }
    fs::write(&path, text)?;
    Ok(path)
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::sync::atomic::{AtomicU32, Ordering};
    use std::sync::{Mutex, OnceLock};

    use super::{matching_files, newest_for, prune, prune_plan, write_new};

    fn with_temp_dir(f: impl FnOnce(&Path)) {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        static COUNTER: AtomicU32 = AtomicU32::new(0);
        let guard = LOCK
            .get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        let dir = std::env::temp_dir().join("opencode").join(format!(
            "store-test-{}-{}",
            std::process::id(),
            n
        ));
        fs::create_dir_all(&dir).unwrap();
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| f(&dir)));
        drop(guard);
        if let Err(e) = result {
            std::panic::resume_unwind(e);
        }
    }

    fn write(root: &Path, name: &str) -> PathBuf {
        let p = root.join(name);
        fs::write(&p, "# handoff").unwrap();
        p
    }

    #[test]
    fn matching_is_case_insensitive_and_exact() {
        with_temp_dir(|root| {
            let proj = write(root, "2026-08-21_1000_proj.md");
            let proj2 = write(root, "2026-08-21_1000_proj2.md");
            let found = matching_files(root, "PROJ");
            assert_eq!(found.len(), 1);
            assert!(found.contains(&proj));
            let found2 = matching_files(root, "proj2");
            assert_eq!(found2.len(), 1);
            assert!(found2.contains(&proj2));
        });
    }

    #[test]
    fn matching_normalizes_query_like_write() {
        with_temp_dir(|root| {
            let written = write(root, "2026-08-21_1000_My_Proj.md");
            assert_eq!(matching_files(root, "My Proj"), vec![written.clone()]);
            assert_eq!(matching_files(root, " My Proj "), vec![written]);
        });
    }

    #[test]
    fn matching_ignores_non_handoffs_and_archive() {
        with_temp_dir(|root| {
            fs::create_dir_all(root.join("handoffarchive")).unwrap();
            write(root, "notes.md");
            let expected = write(root, "2026-08-21_1000_proj.md");
            write(&root.join("handoffarchive"), "2026-08-21_0900_proj.md");
            let found = matching_files(root, "proj");
            assert_eq!(found.len(), 1);
            assert!(found.contains(&expected));
        });
    }

    #[test]
    fn newest_is_lexicographically_latest() {
        with_temp_dir(|root| {
            write(root, "2026-08-21_1000_proj.md");
            let newer = write(root, "2026-08-21_1100_proj.md");
            assert_eq!(newest_for(root, "proj"), Some(newer));
        });
    }

    #[test]
    fn prune_plan_suffixes_archive_collisions() {
        with_temp_dir(|root| {
            let archive = root.join("handoffarchive");
            fs::create_dir_all(&archive).unwrap();
            let src = write(root, "2026-08-21_1000_proj.md");
            write(&archive, "2026-08-21_1000_proj.md");
            let plan = prune_plan(root, "proj");
            assert_eq!(plan, vec![(src, archive.join("2026-08-21_1000_proj-2.md"))]);
        });
    }

    #[test]
    fn prune_moves_files_into_archive() {
        with_temp_dir(|root| {
            let archive = root.join("handoffarchive");
            write(root, "2026-08-21_1000_proj.md");
            let moved = prune(root, "proj").unwrap();
            assert_eq!(moved, 1);
            assert!(!root.join("2026-08-21_1000_proj.md").exists());
            assert!(archive.join("2026-08-21_1000_proj.md").exists());
        });
    }

    #[test]
    fn write_new_collision_gets_minus_2_suffix() {
        with_temp_dir(|root| {
            let first = write_new(root, "proj", "# one").unwrap();
            let second = write_new(root, "proj", "# two").unwrap();
            assert_ne!(first, second);
            let second_name = second.file_name().unwrap().to_string_lossy().to_string();
            assert!(second_name.ends_with("-2.md"), "got {}", second_name);
        });
    }

    #[test]
    fn write_new_sanitizes_project() {
        with_temp_dir(|root| {
            let p = write_new(root, "My Proj", "# one").unwrap();
            let name = p.file_name().unwrap().to_string_lossy().to_string();
            assert!(name.ends_with("_My_Proj.md"), "got {}", name);
        });
    }
}
