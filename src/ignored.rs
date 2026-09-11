//! What a directory declares it does not manage.
//!
//! `.lpignore` is not only the sweep's allowlist: every line is a decision —
//! *"lp does not manage this"* — and decisions are worth reviewing, including
//! the ones that currently match nothing (a rule for `target/` before cargo has
//! ever run is still a decision). The interesting case is a file parked there
//! that belongs in the document instead: a lock file or a manifest is exact
//! enough to be generated and important enough to be explained, so it reads
//! better as an appendix chunk than as a standing exception.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use ignore::gitignore::{Gitignore, GitignoreBuilder};

use crate::diag::LpError;
use crate::map::{MAP_FILE, relative};
use crate::sweep::IGNORE_FILE;

/// One `.lpignore`, with its rules as written and what each currently covers.
pub struct Declaration {
    /// Directory relative to the output directory (`""` for the output itself).
    pub dir: String,
    pub rules: Vec<Rule>,
}

pub struct Rule {
    pub text: String,
    /// Paths (relative to the output directory) this rule currently protects.
    pub matches: Vec<String>,
    /// True when a matched entry is a directory kept whole.
    pub whole_directory: bool,
}

pub fn run(out: &Path) -> Result<i32, LpError> {
    let declarations = rules(out)?;
    if declarations.is_empty() {
        println!(
            "{}: nothing declared — a chunk produces every file here, and lp removes nothing else",
            out.display()
        );
        return Ok(0);
    }

    for declaration in &declarations {
        let path = match declaration.dir.is_empty() {
            true => format!("./{IGNORE_FILE}"),
            false => format!("{}/{IGNORE_FILE}", declaration.dir),
        };
        println!(
            "{path} — {} declaration{}:",
            declaration.rules.len(),
            if declaration.rules.len() == 1 {
                ""
            } else {
                "s"
            }
        );
        for rule in &declaration.rules {
            let column = format!("  {:<22}", rule.text);
            if rule.matches.is_empty() {
                println!("{column} matches nothing right now");
            } else if rule.whole_directory {
                println!("{column} kept whole (a directory, not descended)");
            } else {
                let shown = rule
                    .matches
                    .iter()
                    .take(3)
                    .cloned()
                    .collect::<Vec<_>>()
                    .join(", ");
                let more = if rule.matches.len() > 3 {
                    format!(", … (+{})", rule.matches.len() - 3)
                } else {
                    String::new()
                };
                println!(
                    "{column} {} file{}: {shown}{more}",
                    rule.matches.len(),
                    if rule.matches.len() == 1 { "" } else { "s" }
                );
            }
        }
        println!();
    }

    println!(
        "Everything else in those directories is lp's: a chunk produces it, or a sweep removes it."
    );
    println!(
        "If a line above names something the program needs explained — a lock file, a manifest —"
    );
    println!(
        "write it into the document instead (an appendix chunk) rather than declaring it unmanaged."
    );
    Ok(0)
}

/// Every declaration under `out`, outermost first, with its rules in file order.
pub fn rules(out: &Path) -> Result<Vec<Declaration>, LpError> {
    let dirs = declaration_dirs(out);
    if dirs.is_empty() {
        return Ok(Vec::new());
    }

    // Walk once from each topmost declaration: nested files refine the outer one,
    // so a second walk rooted inside them would count the same files twice.
    let mut coverage: BTreeMap<(String, String), Vec<(String, bool)>> = BTreeMap::new();
    for dir in dirs.iter().filter(|dir| !has_declaration_above(out, dir)) {
        collect(out, dir, &matchers(dir)?, &mut coverage)?;
    }

    let mut declarations = Vec::new();
    for dir in dirs {
        let rel = relative(out, &dir);
        let mut rules = rules_in(&dir.join(IGNORE_FILE))
            .into_iter()
            .map(|text| {
                let matches = coverage
                    .remove(&(rel.clone(), text.clone()))
                    .unwrap_or_default();
                let whole_directory = matches
                    .iter()
                    .any(|(path, is_dir)| *is_dir && *path == text.trim_end_matches('/'));
                Rule {
                    text,
                    matches: matches.into_iter().map(|(path, _)| path).collect(),
                    whole_directory,
                }
            })
            .collect::<Vec<_>>();
        // A rule whose text the matcher reports differently (escapes, `!`) still
        // deserves a line rather than silence.
        for ((declared_dir, text), matches) in coverage.iter() {
            if *declared_dir == rel {
                rules.push(Rule {
                    text: text.clone(),
                    whole_directory: matches.iter().any(|(_, is_dir)| *is_dir),
                    matches: matches.iter().map(|(path, _)| path.clone()).collect(),
                });
            }
        }
        declarations.push(Declaration { dir: rel, rules });
    }
    Ok(declarations)
}

/// Every directory under `out` that carries a `.lpignore`, outermost first.
pub fn declaration_dirs(out: &Path) -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    walk_for_declarations(out, &mut dirs);
    dirs.sort_by_key(|dir| (dir.components().count(), dir.clone()));
    dirs
}

fn has_declaration_above(out: &Path, dir: &Path) -> bool {
    let mut parent = dir.parent();
    while let Some(current) = parent {
        if current.join(IGNORE_FILE).exists() {
            return true;
        }
        if current == out {
            break;
        }
        parent = current.parent();
    }
    false
}

fn walk_for_declarations(dir: &Path, found: &mut Vec<PathBuf>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    if dir.join(IGNORE_FILE).exists() {
        found.push(dir.to_path_buf());
    }
    for entry in entries.flatten() {
        if entry.file_type().is_ok_and(|kind| kind.is_dir()) {
            walk_for_declarations(&entry.path(), found);
        }
    }
}

/// The rules of one ignore file, as written, comments and blanks dropped.
fn rules_in(file: &Path) -> Vec<String> {
    let Ok(text) = std::fs::read_to_string(file) else {
        return Vec::new();
    };
    text.lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(str::to_string)
        .collect()
}

/// The rules that apply inside `dir`, deepest file first (gitignore precedence).
fn matchers(dir: &Path) -> Result<Vec<(PathBuf, Gitignore)>, LpError> {
    let mut dirs = Vec::new();
    walk_for_declarations(dir, &mut dirs);
    dirs.sort_by_key(|candidate| std::cmp::Reverse(candidate.components().count()));

    let mut matchers = Vec::new();
    for candidate in dirs {
        let file = candidate.join(IGNORE_FILE);
        let mut builder = GitignoreBuilder::new(&candidate);
        if let Some(err) = builder.add(&file) {
            return Err(LpError::plain(format!("{}: {err}", file.display())));
        }
        let matcher = builder
            .build()
            .map_err(|err| LpError::plain(format!("{}: {err}", file.display())))?;
        matchers.push((candidate, matcher));
    }
    Ok(matchers)
}

/// Which declaration decides this path, if any: the rule text and the directory
/// of the file that matched (deeper files win, as when walking).
fn decided(
    matchers: &[(PathBuf, Gitignore)],
    path: &Path,
    is_dir: bool,
) -> Option<(PathBuf, String)> {
    for (root, matcher) in matchers {
        let relative = path.strip_prefix(root).unwrap_or(path);
        match matcher.matched(relative, is_dir) {
            ignore::Match::Ignore(glob) => {
                return Some((root.clone(), glob.original().to_string()));
            }
            ignore::Match::Whitelist(_) => return None,
            ignore::Match::None => {}
        }
    }
    None
}

fn collect(
    out: &Path,
    dir: &Path,
    matchers: &[(PathBuf, Gitignore)],
    coverage: &mut BTreeMap<(String, String), Vec<(String, bool)>>,
) -> Result<(), LpError> {
    let entries = std::fs::read_dir(dir).map_err(|err| LpError::io(dir, err))?;
    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name();
        if name == MAP_FILE || name == IGNORE_FILE {
            continue;
        }
        let is_dir = entry.file_type().is_ok_and(|kind| kind.is_dir());
        match decided(matchers, &path, is_dir) {
            Some((declared_in, rule)) => coverage
                .entry((relative(out, &declared_in), rule))
                .or_default()
                .push((relative(out, &path), is_dir)),
            None if is_dir => collect(out, &path, matchers, coverage)?,
            None => {}
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::rules;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn a_rule_is_listed_even_when_it_matches_nothing_yet() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        fs::write(
            out.join(".lpignore"),
            "# comment\ntarget/\nnothing-here.txt\n",
        )
        .unwrap();
        fs::write(out.join("ours.txt"), "x").unwrap();

        let declared = rules(out).unwrap();
        assert_eq!(declared.len(), 1);
        let rules = &declared[0].rules;
        assert_eq!(rules.len(), 2, "comments are not rules");
        assert_eq!(rules[0].text, "target/");
        assert!(rules[0].matches.is_empty());
        assert_eq!(rules[1].text, "nothing-here.txt");
    }

    #[test]
    fn matches_are_attributed_to_the_file_that_declared_them() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        fs::write(out.join(".lpignore"), "*.log\n").unwrap();
        fs::create_dir_all(out.join("src")).unwrap();
        fs::write(out.join("src/.lpignore"), "!*.py\n").unwrap();
        fs::write(out.join("a.log"), "x").unwrap();
        fs::write(out.join("src/b.log"), "x").unwrap();
        fs::write(out.join("src/c.py"), "x").unwrap();

        let declared = rules(out).unwrap();
        let outer = declared.iter().find(|d| d.dir.is_empty()).unwrap();
        assert_eq!(outer.rules[0].text, "*.log");
        // Both logs belong to the outer rule: the inner file only speaks about
        // `*.py`, so it decides nothing for them.
        let mut matched = outer.rules[0].matches.clone();
        matched.sort();
        assert_eq!(matched, vec!["a.log".to_string(), "src/b.log".to_string()]);

        let inner = declared.iter().find(|d| d.dir == "src").unwrap();
        assert_eq!(inner.rules[0].text, "!*.py");
        assert!(
            inner.rules[0].matches.is_empty(),
            "a whitelist takes a file back"
        );
    }
}
