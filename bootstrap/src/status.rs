//! What nothing accounts for.
//!
//! Every file under the output directory falls into exactly one of three groups:
//!
//! * **produced** — a `#file` declaration writes it;
//! * **declared** — a `.lpignore` says *"lp does not manage this"*;
//! * **unaccounted** — neither. Nothing explains why it is there.
//!
//! The third group is the one worth reporting: a file a chunk should probably
//! produce, a file to declare, or stale output to delete — and only the user knows
//! which. Nothing here deletes anything; `delete` is called from
//! `lp unaccounted --delete` and never as a side effect of tangling.
//!
//! Point `--out` at a directory and the whole directory is `lp`'s, at any depth.
//! The `.lpignore` rules say what is not, and the crate's own walker applies them
//! — nested files, deepest wins, whitelists — so there is no second
//! implementation of that logic here.

use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use ignore::WalkBuilder;

use crate::diag::LpError;
use crate::map::{MAP_FILE, relative};

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
pub fn unaccounted(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<Unaccounted>, LpError> {
    if produced.is_empty() || !out.exists() {
        return Ok(Vec::new());
    }

    // What the walker yields is content: it applies every `.lpignore` in the tree
    // as it descends, so a declared file — or a whole declared directory — never
    // reaches this loop.
    let mut builder = WalkBuilder::new(out);
    builder
        .standard_filters(false)
        .hidden(false)
        .parents(false)
        .add_custom_ignore_filename(IGNORE_FILE);

    let mut files: BTreeSet<String> = BTreeSet::new();
    for entry in builder.build() {
        let entry =
            entry.map_err(|err| LpError::plain(format!("cannot scan {}: {err}", out.display())))?;
        if !entry.file_type().is_some_and(|kind| kind.is_file()) {
            continue;
        }
        let path = entry.path();
        if is_control_file(path) {
            continue;
        }
        let rel = relative(out, path);
        let (dir, name) = crate::map::split(&rel);
        if produced.get(dir).is_some_and(|names| names.contains(name)) {
            continue;
        }
        files.insert(rel);
    }

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

/// `lp`'s own control files are never content.
fn is_control_file(path: &Path) -> bool {
    path.file_name()
        .is_some_and(|name| name == MAP_FILE || name == IGNORE_FILE)
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
            "{}: the document declares no files, so lp writes nothing here and owns nothing",
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
