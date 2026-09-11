//! Declarative ownership of an output directory.
//!
//! A directory holding a `.lpignore` file declares: *the files here are `lp`'s,
//! except what this file lists*. Everything under such a directory that no chunk
//! produces is then removed, so deleting or renaming a root chunk cannot leave a
//! stale file behind for a build system to pick up.
//!
//! Two rules keep this from being a footgun:
//!
//! * Nothing is removed outside a directory that carries its own `.lpignore`
//!   (nested ignore files are honoured, so `src/` can be managed while the rest
//!   of the tree is left alone), and nothing matched by that file is touched.
//! * Hidden files (`.lpmap.json`, `.lpignore`, `.gitignore`, …) are never
//!   removed, whatever the rules say.
//!
//! `--check` never deletes: it reports exactly what a sweep would remove, which
//! makes it the dry run.

use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

use ignore::WalkBuilder;

use crate::diag::LpError;
use crate::map::MAP_FILE;

pub const IGNORE_FILE: &str = ".lpignore";

pub struct Sweep {
    /// Files removed, or that would be removed when checking.
    pub removed: Vec<String>,
    /// Directories that declared ownership, relative to the output directory.
    pub roots: Vec<String>,
}

/// Every directory under `out` that carries a `.lpignore`.
pub fn managed_roots(out: &Path) -> Vec<PathBuf> {
    let walker = WalkBuilder::new(out)
        .standard_filters(false)
        .hidden(false)
        .build();
    let mut roots = Vec::new();
    for entry in walker.flatten() {
        if entry.file_name() == IGNORE_FILE
            && let Some(dir) = entry.path().parent()
        {
            roots.push(dir.to_path_buf());
        }
    }
    roots
}

fn under_managed(path: &Path, roots: &[PathBuf], out: &Path) -> bool {
    roots
        .iter()
        .any(|root| path.starts_with(root) && path != out)
}

/// Remove files that no chunk produces, inside directories that declared
/// ownership. `produced` holds paths relative to `out`.
pub fn run(out: &Path, produced: &BTreeSet<String>, delete: bool) -> Result<Sweep, LpError> {
    let roots = managed_roots(out);
    let mut sweep = Sweep {
        removed: Vec::new(),
        roots: roots
            .iter()
            .map(|root| match relative(out, root) {
                rel if rel.is_empty() => ".".to_string(),
                rel => rel,
            })
            .collect(),
    };
    if roots.is_empty() {
        return Ok(sweep);
    }

    let mut candidates: Vec<PathBuf> = Vec::new();
    for root in &roots {
        // The walker yields only entries the `.lpignore` rules do not exclude.
        let walker = WalkBuilder::new(root)
            .standard_filters(false)
            .hidden(false)
            .parents(false)
            .add_custom_ignore_filename(IGNORE_FILE)
            .build();

        for entry in walker {
            let entry = entry
                .map_err(|err| LpError::plain(format!("cannot scan {}: {err}", root.display())))?;
            if entry.depth() == 0 || !entry.file_type().is_some_and(|kind| kind.is_file()) {
                continue;
            }
            let path = entry.path();
            if !under_managed(path, &roots, out) {
                continue;
            }
            // Hidden files are off limits: the map, the ignore files themselves,
            // and whatever else a tool keeps in a dotfile.
            if path
                .file_name()
                .is_some_and(|name| name.to_string_lossy().starts_with('.'))
            {
                continue;
            }
            let rel = relative(out, path);
            if rel == MAP_FILE || produced.contains(&rel) {
                continue;
            }
            candidates.push(path.to_path_buf());
        }
    }

    candidates.sort();
    for path in candidates {
        sweep.removed.push(relative(out, &path));
        if delete {
            std::fs::remove_file(&path).map_err(|e| LpError::io(&path, e))?;
            prune_empty_parents(&path, out, &roots);
        }
    }
    Ok(sweep)
}

/// Relative path with forward slashes, matching the line map's keys.
pub fn relative(out: &Path, path: &Path) -> String {
    path.strip_prefix(out)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

fn prune_empty_parents(path: &Path, out: &Path, roots: &[PathBuf]) {
    let mut dir = path.parent();
    while let Some(current) = dir {
        if current == out || !under_managed(current, roots, out) {
            break;
        }
        let empty = std::fs::read_dir(current).is_ok_and(|mut entries| entries.next().is_none());
        if empty {
            if std::fs::remove_dir(current).is_err() {
                break;
            }
        } else {
            break;
        }
        dir = current.parent();
    }
}
