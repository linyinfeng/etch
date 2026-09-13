use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use ignore::WalkBuilder;
use serde::Serialize;

use crate::diag::EtchError;
use crate::disk;
use crate::map::{MAP_FILE, relative};

pub const IGNORE_FILE: &str = ".etchignore";

#[derive(Debug, Serialize)]
pub struct Unaccounted {
    pub dir: String,
    pub entries: Vec<String>,
}

pub fn unaccounted(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<Unaccounted>, EtchError> {
    if produced.is_empty() || !out.exists() {
        return Ok(Vec::new());
    }

    let mut builder = WalkBuilder::new(out);
    builder
        .standard_filters(false)
        .hidden(false)
        .parents(false)
        .add_custom_ignore_filename(IGNORE_FILE);

    let mut files: BTreeSet<String> = BTreeSet::new();
    for entry in builder.build() {
        let entry = entry
            .map_err(|err| EtchError::plain(format!("cannot scan {}: {err}", out.display())))?;
        if entry.file_type().is_some_and(|kind| kind.is_dir()) {
            continue;
        }
        let path = entry.path();
        if is_own_output(path) {
            continue;
        }
        let rel = relative(out, path);
        if rel
            .split('/')
            .any(|part| part == crate::metadata::PACKAGE_ROOT)
        {
            continue;
        }
        let (dir, name) = crate::map::split(&rel);
        if produced.get(dir).is_some_and(|names| names.contains(name)) {
            continue;
        }
        files.insert(rel);
    }

    let mut found: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for entry in compress("", &files) {
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

fn is_own_output(path: &Path) -> bool {
    path.file_name().is_some_and(|name| name == MAP_FILE)
}

const COMPRESS_ABOVE: usize = 8;

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

pub fn delete(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<String>, EtchError> {
    let mut removed = Vec::new();
    for group in unaccounted(out, produced)? {
        for entry in group.entries {
            let whole_directory = entry.ends_with('/');
            let name = entry.trim_end_matches('/');
            let relative = crate::map::join(&group.dir, name);
            let path = out.join(&relative);
            if whole_directory {
                disk::remove_dir_all(&path)?;
            } else {
                disk::remove_file(&path)?;
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
        let empty = disk::entries(current).is_ok_and(|entries| entries.is_empty());
        if !empty || disk::remove_dir(current).is_err() {
            break;
        }
        dir = current.parent();
    }
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
        write(&out.join(".etchignore"), "declared.txt\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("declared.txt"), "mine, not etch's");
        write(&out.join("stray.txt"), "who put this here");
        write(&out.join("stray-dir/inside.txt"), "and this");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt", ".etchignore"])]
                .into_iter()
                .collect();
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
        write(&out.join(".etchignore"), "**/*.log\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("deep/nested/app.log"), "declared");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt", ".etchignore"])]
                .into_iter()
                .collect();
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

    #[test]
    fn the_ignore_file_is_not_exempt_and_the_tools_own_output_is() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".etchignore"), "theirs.txt\n");
        write(&out.join("theirs.txt"), "protected");
        write(&out.join(".etch/package/lib.typ"), "the package");
        write(&out.join("src/.etchmap.json"), "the map");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["theirs.txt"])].into_iter().collect();
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
            vec![".etchignore".to_string()],
            "the ignore file is reported; the tool's own two names are not"
        );
    }
}
