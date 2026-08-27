//! Parsing helpers: project name is taken from the handoff filename (title).
//!
//! NOTE: A handoff is recognized by its title only -- the filename encodes the
//! date/time and the unique project name as `{YYYY-MM-DD_HHMM}_{project}.md`.
//! No content tags are read, so nothing here depends on a head-read limit.
//! Handoffs are expected to be structured with the title at the top.

/// Handoff filename prefix: YYYY-MM-DD_HHMM_ (15 chars + "_")
const DATETIME_PREFIX_LEN: usize = 15 + 1;

/// Extract the project name from a handoff filename, or None.
pub fn project_from_name(name: &str) -> Option<String> {
    let stem = name.strip_suffix(".md").unwrap_or(name);
    if stem.len() < DATETIME_PREFIX_LEN {
        return None;
    }
    // Verify the leading prefix looks like a datetime before stripping,
    // mirroring python's ^\d{4}-\d{2}-\d{2}_\d{4}_ regex.
    let b = stem.as_bytes();
    let is_prefix = b[4] == b'-'
        && b[7] == b'-'
        && b[10] == b'_'
        && b[15] == b'_'
        && b[..4].iter().all(|&c| c.is_ascii_digit())
        && b[5..7].iter().all(|&c| c.is_ascii_digit())
        && b[8..10].iter().all(|&c| c.is_ascii_digit())
        && b[11..15].iter().all(|&c| c.is_ascii_digit());
    if !is_prefix {
        return None;
    }
    let project = &stem[DATETIME_PREFIX_LEN..];
    if project.is_empty() {
        None
    } else {
        Some(project.to_string())
    }
}

/// Turn a project name into a safe filename fragment.
pub fn sanitize_topic(topic: &str, limit: usize) -> String {
    let mut safe = String::with_capacity(topic.len());
    for ch in topic.chars() {
        if ch.is_alphanumeric() || ch == '-' || ch == '_' || ch == ' ' {
            safe.push(ch);
        } else {
            safe.push('_');
        }
    }
    let trimmed = safe.trim();
    let spaced = trimmed.replace(' ', "_");
    spaced.chars().take(limit).collect()
}

#[cfg(test)]
mod tests {
    use super::{project_from_name, sanitize_topic};

    #[test]
    fn project_from_valid_name() {
        assert_eq!(
            project_from_name("2026-08-21_1015_myproj.md"),
            Some("myproj".to_string())
        );
        assert_eq!(
            project_from_name("2026-08-21_1015_My_Proj.md"),
            Some("My_Proj".to_string())
        );
    }

    #[test]
    fn project_from_valid_name_collision_suffix() {
        assert_eq!(
            project_from_name("2026-08-21_1015_myproj-2.md"),
            Some("myproj-2".to_string())
        );
    }

    #[test]
    fn project_from_name_without_dot_md_suffix() {
        assert_eq!(
            project_from_name("2026-08-21_1015_myproj"),
            Some("myproj".to_string())
        );
    }

    #[test]
    fn project_from_bad_prefixes() {
        // wrong separators
        assert_eq!(project_from_name("2026-08/21_1015_x.md"), None);
        // non-digit in date portion
        assert_eq!(project_from_name("2026-0a-21_1015_x.md"), None);
        // missing trailing underscore after HHMM
        assert_eq!(project_from_name("2026-08-21_1015x.md"), None);
        // not a datetime at all
        assert_eq!(project_from_name("notes.md"), None);
    }

    #[test]
    fn project_from_too_short() {
        assert_eq!(project_from_name("2026-08-2.md"), None);
    }

    #[test]
    fn project_from_empty_project() {
        assert_eq!(project_from_name("2026-08-21_1015_.md"), None);
    }

    #[test]
    fn sanitize_replaces_and_trims() {
        assert_eq!(sanitize_topic(" My Proj ", 40), "My_Proj");
        assert_eq!(sanitize_topic("a/b?c", 40), "a_b_c");
    }

    #[test]
    fn sanitize_preserves_safe_chars() {
        assert_eq!(sanitize_topic("My-Proj_2", 40), "My-Proj_2");
    }

    #[test]
    fn sanitize_enforces_limit() {
        assert_eq!(
            sanitize_topic("abcdefghijklmnopqrstuvwxyz0123456789abcdefghi", 40).len(),
            40
        );
    }

    #[test]
    fn sanitize_is_idempotent() {
        let once = sanitize_topic("My Proj", 40);
        assert_eq!(sanitize_topic(&once, 40), once);
    }
}
