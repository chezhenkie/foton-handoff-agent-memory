//! foton-handoff - automated handoff read/write (Rust binary).
//!
//! Usage:
//!   foton-handoff read <project>      Print the newest handoff for <project>.
//!   foton-handoff write <project>     Read new handoff text from stdin, archive
//!                                     the old one(s), write the new one.
//!   Both accept -n / --dry-run; write -n previews without changes.
//!
//! A handoff is recognized by its title only: the filename
//! {YYYY-MM-DD_HHMM}_{project}.md encodes the unique project name and date/time.
//! No content tags are parsed. The handoff root is the executable's directory;
//! handoffarchive/ is a sibling. The agent has no control over storage location.
//! Success is silent; errors go to stderr. Subcommands are wired in the dispatch below.

use foton_handoff_core::{read, write};

const COMMANDS: [&str; 2] = ["read", "write"];

fn usage() -> String {
    format!(
        "usage: foton-handoff <{}> <project> [-n]",
        COMMANDS.join("|")
    )
}

fn parse_args(args: &[String]) -> Result<(String, String, bool), String> {
    if args.is_empty() {
        return Err("requires a subcommand".to_string());
    }

    let cmd = args[0].to_lowercase();
    if cmd != "read" && cmd != "write" {
        return Err(format!("unknown subcommand '{}'", args[0]));
    }

    let mut dry_run = false;
    let mut positionals = Vec::new();

    for tok in &args[1..] {
        if tok.starts_with('-') {
            if tok == "-n" || tok == "--dry-run" {
                dry_run = true;
            } else {
                return Err(format!("unknown flag '{}'", tok));
            }
        } else {
            positionals.push(tok.as_str());
        }
    }

    if positionals.is_empty() {
        return Err("requires a project name".to_string());
    }
    if positionals.len() > 1 {
        return Err("too many arguments (quote the project name)".to_string());
    }

    let project = positionals[0];
    if project.trim().is_empty() {
        return Err("requires a non-empty project name".to_string());
    }

    Ok((cmd, project.to_string(), dry_run))
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match parse_args(&args) {
        Ok((cmd, project, dry_run)) => {
            let handler: fn(&str, bool) -> i32 = match cmd.as_str() {
                "read" => read,
                "write" => write,
                _ => unreachable!(),
            };
            std::process::exit(handler(&project, dry_run));
        }
        Err(msg) => {
            eprintln!("error: {}", msg);
            eprintln!("{}", usage());
            std::process::exit(2);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::parse_args;

    fn s(v: &[&str]) -> Vec<String> {
        v.iter().map(|x| x.to_string()).collect()
    }

    #[test]
    fn valid_single_word() {
        let (cmd, proj, dry) = parse_args(&s(&["read", "alpha"])).unwrap();
        assert_eq!(cmd, "read");
        assert_eq!(proj, "alpha");
        assert!(!dry);
    }

    #[test]
    fn valid_multi_word_single_arg() {
        let (cmd, proj, dry) = parse_args(&s(&["write", "multi word"])).unwrap();
        assert_eq!(cmd, "write");
        assert_eq!(proj, "multi word");
        assert!(!dry);
    }

    #[test]
    fn flag_n_before_project() {
        let (cmd, proj, dry) = parse_args(&s(&["write", "-n", "alpha"])).unwrap();
        assert_eq!(cmd, "write");
        assert_eq!(proj, "alpha");
        assert!(dry);
    }

    #[test]
    fn flag_n_after_project() {
        let (_, proj, dry) = parse_args(&s(&["write", "alpha", "-n"])).unwrap();
        assert_eq!(proj, "alpha");
        assert!(dry);
    }

    #[test]
    fn flag_dry_run_long() {
        let (_, _, dry) = parse_args(&s(&["write", "alpha", "--dry-run"])).unwrap();
        assert!(dry);
    }

    #[test]
    fn unknown_flag_rejected() {
        let r = parse_args(&s(&["write", "-x", "alpha"]));
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("unknown flag"));
    }

    #[test]
    fn unknown_flag_double_dash_rejected() {
        let r = parse_args(&s(&["read", "--verbose", "alpha"]));
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("unknown flag"));
    }

    #[test]
    fn too_few_positionals() {
        let r = parse_args(&s(&["read"]));
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("requires a project name"));
    }

    #[test]
    fn too_many_positionals() {
        let r = parse_args(&s(&["write", "alpha", "junk"]));
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("too many arguments"));
    }

    #[test]
    fn whitespace_only_project() {
        let r = parse_args(&s(&["write", "   "]));
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("non-empty"));
    }

    #[test]
    fn unknown_subcommand() {
        let r = parse_args(&s(&["bogus", "alpha"]));
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("unknown subcommand"));
    }

    #[test]
    fn no_args_at_all() {
        let r = parse_args(&s(&[]));
        assert!(r.is_err());
    }

    #[test]
    fn subcommand_case_insensitive() {
        let (cmd, _, _) = parse_args(&s(&["READ", "alpha"])).unwrap();
        assert_eq!(cmd, "read");
    }

    #[test]
    fn subcommand_write_case_insensitive() {
        let (cmd, _, _) = parse_args(&s(&["Write", "alpha"])).unwrap();
        assert_eq!(cmd, "write");
    }

    #[test]
    fn flag_between_subcommand_and_project() {
        let (cmd, proj, dry) = parse_args(&s(&["read", "-n", "alpha"])).unwrap();
        assert_eq!(cmd, "read");
        assert_eq!(proj, "alpha");
        assert!(dry);
    }
}
