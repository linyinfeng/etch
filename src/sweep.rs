//! Declarative ownership of an output directory.
//!
//! A directory holding a `.lpignore` file declares: *the files here are `lp`'s,
//! except what this file lists*. Everything under such a directory that no chunk
//! produces is then removed, so deleting or renaming a root chunk cannot leave a
//! stale file behind for a build system to pick up.
//!
//! The rules are gitignore's, because they *are* gitignore: pattern matching,
//! `!` re-inclusion, `**`, directory-only patterns, nested ignore files and the
//! precedence between them all come from the `ignore` crate (the engine behind
//! ripgrep). A single walk of the output directory applies every `.lpignore` in
//! the tree, deepest file winning — no discovery pass, no reimplementation.
//!
//! Three deliberate differences from a work tree:
//!
//! * Patterns only ever decide what `lp` **keeps**, never what it takes: a file
//!   is a candidate for removal only when a directory above it declared
//!   ownership, and deletion always requires that declaration. Without one, the
//!   ledger in `tangle.rs` is the only record of what is ours.
//! * `.git` is never entered, so a repository living inside the output directory
//!   is not content (git does not track its own store either).
//! * `.lpmap.json` and `.lpignore` are control files, never content — deleting
//!   the ledger, or the rules that decide what may be deleted, would be a
//!   self-inflicted wound. Everything else, dotfiles included, is an ordinary
//!   file: list it in `.lpignore` or lose it.

use std::collections::{BTreeMap, BTreeSet};
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

/// Remove files that no chunk produces, inside directories that declared
/// ownership. `produced` holds paths relative to `out`.
pub fn run(out: &Path, produced: &BTreeSet<String>, delete: bool) -> Result<Sweep, LpError> {
    let mut sweep = Sweep {
        removed: Vec::new(),
        roots: Vec::new(),
    };
    let mut roots: BTreeSet<PathBuf> = BTreeSet::new();
    let mut declared: BTreeMap<PathBuf, bool> = BTreeMap::new();
    let mut candidates: Vec<PathBuf> = Vec::new();

    let mut builder = WalkBuilder::new(out);
    builder
        .standard_filters(false)
        .hidden(false)
        .parents(false)
        .require_git(false)
        .add_custom_ignore_filename(IGNORE_FILE)
        .filter_entry(|entry| entry.file_name() != ".git");

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
        // The walker yields only entries the `.lpignore` rules keep; what remains
        // is content of whichever directory declared ownership above it.
        let Some(root) = declaring_root(out, path, &mut declared) else {
            continue;
        };
        let rel = relative(out, path);
        if produced.contains(&rel) {
            continue;
        }
        roots.insert(root);
        candidates.push(path.to_path_buf());
    }

    sweep.roots = roots
        .iter()
        .map(|root| match relative(out, root) {
            rel if rel.is_empty() => ".".to_string(),
            rel => rel,
        })
        .collect();

    candidates.sort();
    for path in candidates {
        sweep.removed.push(relative(out, &path));
        if delete {
            std::fs::remove_file(&path).map_err(|e| LpError::io(&path, e))?;
            prune_empty_parents(&path, out, &mut declared);
        }
    }
    Ok(sweep)
}

/// The outermost directory at or above `path` (but not above `out`) that carries
/// a `.lpignore`. `None` means nothing declared ownership of this path.
fn declaring_root(out: &Path, path: &Path, cache: &mut BTreeMap<PathBuf, bool>) -> Option<PathBuf> {
    let declares = |dir: &Path, cache: &mut BTreeMap<PathBuf, bool>| {
        *cache
            .entry(dir.to_path_buf())
            .or_insert_with(|| dir.join(IGNORE_FILE).exists())
    };

    let mut root = None;
    let mut dir = path.parent();
    while let Some(current) = dir {
        if !current.starts_with(out) {
            break;
        }
        if declares(current, cache) {
            root = Some(current.to_path_buf());
        }
        dir = current.parent();
    }
    root
}

/// `lp`'s own control files never count as content.
fn is_control_file(path: &Path) -> bool {
    path.file_name()
        .is_some_and(|name| name == MAP_FILE || name == IGNORE_FILE)
}

/// Relative path with forward slashes, matching the line map's keys.
pub fn relative(out: &Path, path: &Path) -> String {
    path.strip_prefix(out)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

fn prune_empty_parents(path: &Path, out: &Path, cache: &mut BTreeMap<PathBuf, bool>) {
    let mut dir = path.parent();
    while let Some(current) = dir {
        if current == out || declaring_root(out, current, cache).is_none() {
            break;
        }
        let empty = std::fs::read_dir(current).is_ok_and(|mut entries| entries.next().is_none());
        if !empty || std::fs::remove_dir(current).is_err() {
            break;
        }
        dir = current.parent();
    }
}
