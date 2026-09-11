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
//! The report never deletes anything. Deletion stays the sweep's job (see
//! `sweep.rs`), which needs a directory declaration to act at all.

use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use ignore::WalkBuilder;

use crate::diag::LpError;
use crate::map::{LpMap, MAP_FILE, relative};
use crate::sweep::IGNORE_FILE;

/// Entries in one directory that nothing accounts for.
#[derive(Debug)]
pub struct Unaccounted {
    /// Directory relative to the output directory (`""` for the output itself).
    pub dir: String,
    /// File or directory names, a directory marked with a trailing `/`.
    pub entries: Vec<String>,
}

/// The directories a previous pass wrote into, and the names it wrote there.
pub fn produced(out: &Path) -> BTreeMap<String, BTreeSet<String>> {
    LpMap::read_all(out)
        .into_iter()
        .map(|(dir, map)| (dir, map.files.into_keys().collect()))
        .collect()
}

/// Everything in a produced directory that is neither produced nor declared.
///
/// The walk is rooted at the output directory with the same settings the sweep
/// uses, so "declared" here means exactly what it means there: the ignore crate
/// answers both questions, and only directories a pass actually wrote into are
/// inspected.
pub fn unaccounted(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<Unaccounted>, LpError> {
    if produced.is_empty() || !out.exists() {
        return Ok(Vec::new());
    }

    let mut builder = WalkBuilder::new(out);
    builder
        .standard_filters(false)
        .hidden(false)
        .parents(false)
        .add_custom_ignore_filename(IGNORE_FILE);

    // A directory holding produced files is accounted for as a directory, even
    // though no line map lists it by name.
    let mut directories: BTreeSet<String> = BTreeSet::new();
    for dir in produced.keys() {
        let mut current = Some(dir.as_str());
        while let Some(path) = current {
            directories.insert(path.to_string());
            current = path.rsplit_once('/').map(|(parent, _)| parent);
        }
    }

    let mut found: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for entry in builder.build() {
        let entry =
            entry.map_err(|err| LpError::plain(format!("cannot scan {}: {err}", out.display())))?;
        if entry.depth() == 0 {
            continue; // the output directory itself is not an entry in itself
        }
        let path = entry.path();
        if path
            .file_name()
            .is_some_and(|name| name == MAP_FILE || name == IGNORE_FILE)
        {
            continue;
        }
        let Some(parent) = path.parent() else {
            continue;
        };
        let dir = relative(out, parent);
        let Some(names) = produced.get(&dir) else {
            continue;
        };
        let name = entry.file_name().to_string_lossy().to_string();
        if names.contains(&name) {
            continue;
        }
        let is_dir = entry.file_type().is_some_and(|kind| kind.is_dir());
        if is_dir && directories.contains(&crate::map::join(&dir, &name)) {
            continue;
        }
        found
            .entry(dir)
            .or_default()
            .push(if is_dir { format!("{name}/") } else { name });
    }

    Ok(found
        .into_iter()
        .map(|(dir, mut entries)| {
            // Stable output: the walk order is the file system's.
            entries.sort();
            Unaccounted { dir, entries }
        })
        .collect())
}

pub fn run(out: &Path) -> Result<i32, LpError> {
    let produced = produced(out);
    if produced.is_empty() {
        println!(
            "{}: no line maps — nothing has been tangled here, so there is nothing to account for",
            out.display()
        );
        return Ok(0);
    }

    let unaccounted = unaccounted(out, &produced)?;
    if unaccounted.is_empty() {
        let accounted: usize = produced.values().map(BTreeSet::len).sum();
        println!(
            "{}: every file in a produced directory is accounted for ({accounted} produced by chunks or declared)",
            out.display()
        );
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
            println!("  {entry}");
        }
    }
    println!();
    println!(
        "Every other file in those directories is either produced by a chunk or declared in a .lpignore."
    );
    println!(
        "Each line above is one of: something a chunk should produce, something to declare in"
    );
    println!(
        "that directory's .lpignore, or stale output to delete. lp removes none of them on its own."
    );
    Ok(0)
}

#[cfg(test)]
mod tests {
    use super::{produced, unaccounted};
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

        assert_eq!(found.len(), 1);
        assert_eq!(found[0].dir, "");
        assert_eq!(
            found[0].entries,
            vec!["stray-dir/".to_string(), "stray.txt".to_string()]
        );
    }

    #[test]
    fn directories_that_were_never_written_into_are_left_alone() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join("src/produced.rs"), "chunk output");
        write(&out.join("elsewhere/whatever.txt"), "not our business");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("src", &["produced.rs"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        assert!(
            found.is_empty(),
            "{:?}",
            found.iter().map(|group| &group.dir).collect::<Vec<_>>()
        );
    }

    #[test]
    fn the_map_is_the_record_of_what_was_produced() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(
            &out.join("src/.lpmap.json"),
            r#"{"version":2,"docs":["d.typ"],"files":{"a.rs":{"typ":"d.typ","lang":null,"lines":[],"chunks":[]}}}"#,
        );
        write(&out.join("src/a.rs"), "x");
        write(&out.join("src/b.rs"), "x");

        let produced = produced(out);
        assert_eq!(
            produced.get("src"),
            Some(&["a.rs".to_string()].into_iter().collect())
        );
        let found = unaccounted(out, &produced).unwrap();
        assert_eq!(found[0].dir, "src");
        assert_eq!(found[0].entries, vec!["b.rs".to_string()]);
    }
}
