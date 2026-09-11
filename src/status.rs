//! What nothing accounts for.
//!
//! Every file in an output directory falls into exactly one of three groups:
//!
//! * **produced** — a chunk writes it, so `lp` owns its content and `--check`
//!   guards it;
//! * **declared** — a `.lpignore` says *"lp does not manage this"*;
//! * **unaccounted** — neither. Nothing explains why it is there.
//!
//! The third group is the one worth reporting: the first is visible in the line
//! map, the second in the ignore file, and only the third is invisible by
//! construction. It is a file a chunk should probably produce, a file to declare,
//! or stale output to delete — and only the user knows which.
//!
//! The output directory *is* `lp`'s: the report covers everything under it, at any
//! depth, not just the neighbourhood of something a chunk wrote.
//!
//! The report never deletes anything. Deletion stays the sweep's job (see
//! `sweep.rs`), which needs a directory declaration to act at all.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use ignore::gitignore::{Gitignore, GitignoreBuilder};

use crate::diag::LpError;
use crate::map::{MAP_FILE, relative};
/// The file that declares a directory's exceptions. Read here, honoured by the
/// sweep — there is only one sweep now, and this is it.
/// The file in which a directory declares what `lp` does not manage.
pub const IGNORE_FILE: &str = ".lpignore";

/// Entries in one directory that nothing accounts for.
#[derive(Debug)]
pub struct Unaccounted {
    /// Directory relative to the output directory (`""` for the output itself).
    pub dir: String,
    /// File or directory names, a directory marked with a trailing `/`.
    pub entries: Vec<String>,
}

/// Everything under the output directory that no chunk produces and no
/// declaration owns.
///
/// Point `--out` at a directory and that directory is `lp`'s: everything under it
/// has to be accounted for, not just the files sitting next to something a chunk
/// produced. A subtree nothing was ever produced in is named as a single entry
/// and not descended into — a build directory is one line, not thousands — while a
/// subtree that does hold produced files is walked and its unaccounted files are
/// named one by one.
///
/// "Declared" means exactly what it means to the sweep, because the same settings
/// decide both: declared entries never appear here at all.
pub fn unaccounted(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<Unaccounted>, LpError> {
    if produced.is_empty() || !out.exists() {
        return Ok(Vec::new());
    }

    let matchers = matchers(out)?;
    let mut files: BTreeSet<String> = BTreeSet::new();
    scan(out, out, produced, &matchers, &mut files)?;

    let mut found: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for entry in compress("", &files) {
        // A compressed entry keeps its trailing slash so a reader can tell a
        // directory from a file.
        let (whole_directory, path) = match entry.strip_suffix('/') {
            Some(path) => (true, path),
            None => (false, entry.as_str()),
        };
        let (dir, name) = crate::map::split(path);
        let name = if whole_directory {
            format!("{name}/")
        } else {
            name.to_string()
        };
        found.entry(dir.to_string()).or_default().push(name);
    }
    Ok(found
        .into_iter()
        .map(|(dir, mut entries)| {
            entries.sort();
            Unaccounted { dir, entries }
        })
        .collect())
}

/// Beyond this many entries a subtree stops being listed file by file and is
/// named as a directory instead: a build directory is one line, not thousands.
const COMPRESS_ABOVE: usize = 8;

/// Turn the unaccounted files into the entries to show, compressing a directory
/// that carries too many of them.
fn compress(dir: &str, files: &BTreeSet<String>) -> Vec<String> {
    let prefix = if dir.is_empty() {
        String::new()
    } else {
        format!("{dir}/")
    };
    let mut entries: Vec<String> = files
        .iter()
        .filter(|file| file.starts_with(&prefix) && !file[prefix.len()..].contains('/'))
        .cloned()
        .collect();

    for sub in subdirectories(dir, files) {
        entries.extend(compress(&sub, files));
    }

    if !dir.is_empty() && entries.len() > COMPRESS_ABOVE {
        return vec![format!("{dir}/")];
    }
    entries
}

fn subdirectories(dir: &str, files: &BTreeSet<String>) -> BTreeSet<String> {
    let prefix = if dir.is_empty() {
        String::new()
    } else {
        format!("{dir}/")
    };
    files
        .iter()
        .filter_map(|file| {
            let rest = file.strip_prefix(&prefix)?;
            let (child, _) = rest.split_once('/')?;
            Some(format!("{prefix}{child}"))
        })
        .collect()
}

/// The `.lpignore` files under `out`, deepest first, so the most specific file
/// decides a path — the same precedence the walker applies.
fn matchers(out: &Path) -> Result<Vec<(PathBuf, Gitignore)>, LpError> {
    let mut dirs = Vec::new();
    collect_declarations(out, &mut dirs);
    dirs.sort_by_key(|dir| std::cmp::Reverse(dir.components().count()));

    let mut matchers = Vec::new();
    for dir in dirs {
        let file = dir.join(IGNORE_FILE);
        let mut builder = GitignoreBuilder::new(&dir);
        if let Some(err) = builder.add(&file) {
            return Err(LpError::plain(format!("{}: {err}", file.display())));
        }
        let matcher = builder
            .build()
            .map_err(|err| LpError::plain(format!("{}: {err}", file.display())))?;
        matchers.push((dir, matcher));
    }
    Ok(matchers)
}

fn collect_declarations(dir: &Path, found: &mut Vec<PathBuf>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    if dir.join(IGNORE_FILE).exists() {
        found.push(dir.to_path_buf());
    }
    for entry in entries.flatten() {
        if entry.file_type().is_ok_and(|kind| kind.is_dir()) {
            collect_declarations(&entry.path(), found);
        }
    }
}

/// Is this path declared? A whitelist (`!`) says no, exactly as when walking.
fn declared(matchers: &[(PathBuf, Gitignore)], path: &Path, is_dir: bool) -> bool {
    for (root, matcher) in matchers {
        let relative = path.strip_prefix(root).unwrap_or(path);
        match matcher.matched(relative, is_dir) {
            ignore::Match::Ignore(_) => return true,
            ignore::Match::Whitelist(_) => return false,
            ignore::Match::None => {}
        }
    }
    false
}

fn scan(
    out: &Path,
    dir: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
    matchers: &[(PathBuf, Gitignore)],
    found: &mut BTreeSet<String>,
) -> Result<(), LpError> {
    let entries = std::fs::read_dir(dir).map_err(|err| LpError::io(dir, err))?;
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        if name == MAP_FILE || name == IGNORE_FILE {
            continue;
        }
        let path = entry.path();
        let is_dir = entry.file_type().is_ok_and(|kind| kind.is_dir());
        // A declared entry is accounted for by the declaration, and a declared
        // directory is not ours to look into at all.
        if declared(matchers, &path, is_dir) {
            continue;
        }

        let here = relative(out, dir);
        if produced
            .get(&here)
            .is_some_and(|names| names.contains(&name))
        {
            continue;
        }
        if is_dir {
            // A directory is never unaccounted by itself: only what is inside it
            // can be, and `compress` decides whether to name it as a whole.
            scan(out, &path, produced, matchers, found)?;
            continue;
        }
        found.insert(crate::map::join(&here, &name));
    }
    Ok(())
}

/// Delete everything nothing accounts for.
///
/// This is the only way `lp` ever removes a file, and it never happens as a side
/// effect of tangling: stale output is either declared (then it is accounted for)
/// or deleted on request.
pub fn delete(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<String>, LpError> {
    let mut removed = Vec::new();
    for group in unaccounted(out, produced)? {
        for entry in group.entries {
            let whole_directory = entry.ends_with('/');
            let name = entry.trim_end_matches('/');
            let relative = crate::map::join(&group.dir, name);
            let path = out.join(&relative);
            if whole_directory {
                std::fs::remove_dir_all(&path).map_err(|err| LpError::io(&path, err))?;
            } else {
                std::fs::remove_file(&path).map_err(|err| LpError::io(&path, err))?;
            }
            prune_empty_dirs(path.parent().unwrap_or(out), out);
            removed.push(relative);
        }
    }
    Ok(removed)
}

pub fn prune_empty_dirs(start: &Path, stop: &Path) {
    let mut dir = Some(start);
    while let Some(current) = dir {
        if current == stop || !current.starts_with(stop) {
            break;
        }
        let empty = std::fs::read_dir(current).is_ok_and(|mut entries| entries.next().is_none());
        if !empty || std::fs::remove_dir(current).is_err() {
            break;
        }
        dir = current.parent();
    }
}

pub fn run(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
    delete_unaccounted: bool,
) -> Result<i32, LpError> {
    if produced.is_empty() {
        println!(
            "{}: no line maps — nothing has been tangled here, so there is nothing to account for",
            out.display()
        );
        return Ok(0);
    }

    let unaccounted = unaccounted(out, produced)?;
    if unaccounted.is_empty() {
        let accounted: usize = produced.values().map(BTreeSet::len).sum();
        println!(
            "{}: every file under the output directory is accounted for ({accounted} produced by chunks, the rest declared)",
            out.display()
        );
        return Ok(0);
    }

    if delete_unaccounted {
        for relative in delete(out, produced)? {
            println!("deleted {relative}");
        }
        return Ok(0);
    }

    for group in &unaccounted {
        let label = if group.dir.is_empty() {
            "."
        } else {
            group.dir.as_str()
        };
        println!("{label}/ — {} nothing accounts for:", group.entries.len());
        for entry in &group.entries {
            // The full path, so a line here can be copied, grepped, or declared
            // as it stands.
            println!("  {}", crate::map::join(&group.dir, entry));
        }
    }
    println!();
    println!(
        "Everything else under there is either produced by a chunk or declared in a .lpignore."
    );
    println!(
        "Each line above is one of: something a chunk should produce, something to declare in"
    );
    println!("that directory's .lpignore, or stale output to delete.");
    println!("Nothing is removed on its own: declare it, or run `lp unaccounted --delete`.");
    Ok(1)
}

#[cfg(test)]
mod tests {
    use super::unaccounted;
    use std::collections::{BTreeMap, BTreeSet};
    use std::fs;
    use tempfile::TempDir;

    fn write(path: &std::path::Path, contents: &str) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, contents).unwrap();
    }

    fn names(dir: &str, list: &[&str]) -> (String, BTreeSet<String>) {
        (
            dir.to_string(),
            list.iter().map(|name| name.to_string()).collect(),
        )
    }

    #[test]
    fn only_files_nothing_accounts_for_are_reported() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".lpignore"), "declared.txt\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("declared.txt"), "mine, not lp's");
        write(&out.join("stray.txt"), "who put this here");
        write(&out.join("stray-dir/inside.txt"), "and this");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();

        let listed: Vec<String> = found
            .iter()
            .flat_map(|group| {
                group
                    .entries
                    .iter()
                    .map(|entry| crate::map::join(&group.dir, entry))
                    .collect::<Vec<_>>()
            })
            .collect();
        let mut listed = listed;
        listed.sort();
        assert_eq!(
            listed,
            vec!["stray-dir/inside.txt".to_string(), "stray.txt".to_string()]
        );
    }

    #[test]
    fn a_directory_holding_only_declared_files_is_accounted_for() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".lpignore"), "**/*.log\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("deep/nested/app.log"), "declared");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt"])].into_iter().collect();
        assert!(unaccounted(out, &produced).unwrap().is_empty());
    }

    #[test]
    fn a_large_unaccounted_subtree_is_named_once() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join("produced.txt"), "chunk output");
        for i in 0..20 {
            write(&out.join(format!("vendor/nested/file{i}.txt")), "x");
        }

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].dir, "vendor");
        assert_eq!(
            found[0].entries,
            vec!["nested/".to_string()],
            "one line, not twenty — the directory that actually overflows"
        );
    }

    #[test]
    fn the_output_directory_is_ours_all_the_way_down() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join("src/produced.rs"), "chunk output");
        write(&out.join("src/next-to-it.rs"), "stray");
        write(&out.join("elsewhere/deep/a.txt"), "x");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("src", &["produced.rs"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        let listed: Vec<String> = found
            .iter()
            .flat_map(|group| {
                group
                    .entries
                    .iter()
                    .map(|entry| crate::map::join(&group.dir, entry))
                    .collect::<Vec<_>>()
            })
            .collect();
        assert_eq!(
            listed,
            vec![
                "elsewhere/deep/a.txt".to_string(),
                "src/next-to-it.rs".to_string()
            ],
            "anything under the output directory, at any depth"
        );
    }
}
