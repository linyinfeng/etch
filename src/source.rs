//! The files a document is written in.
//!
//! Chunks are decided by Typst's own evaluation (`metadata.rs`) and their
//! positions by searching this text (`locate.rs`); nothing here parses Typst.
//! What remains is bookkeeping: the text of a file, the name to show in
//! diagnostics, and the two rules that are ours rather than Typst's — what a root
//! chunk name looks like, and which paths may be written to.

use std::ops::Range;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use miette::NamedSource;

use crate::diag::LpError;

/// One file read while loading a document: its text, plus the name to show in
/// diagnostics. Shared, because every placed chunk points back at it.
#[derive(Debug)]
pub struct FileText {
    pub path: PathBuf,
    pub text: String,
    pub named: NamedSource<String>,
}

impl FileText {
    pub fn load(path: &Path) -> Result<Self, LpError> {
        let text = std::fs::read_to_string(path).map_err(|err| LpError::io(path, err))?;
        Ok(Self {
            path: path.to_path_buf(),
            named: NamedSource::new(path.display().to_string(), text.clone()),
            text,
        })
    }

    /// Byte range of a 1-based line, without its newline.
    pub fn line_range(&self, line: usize) -> Option<Range<usize>> {
        let mut offset = 0;
        for (index, text) in self.text.split_inclusive('\n').enumerate() {
            if index + 1 == line {
                return Some(offset..offset + text.trim_end_matches('\n').len());
            }
            offset += text.len();
        }
        None
    }

    pub fn lines(&self) -> Vec<&str> {
        self.text.lines().collect()
    }
}

/// Every file the documents may hold chunks in: the ones named, plus whatever
/// they `#include`.
///
/// The includes are found by *searching* for a literal `#include "path"` rather
/// than by parsing — the same rule as everywhere else here. A computed include
/// (`#include some-path`) is not followed: its chunks still appear (Typst
/// evaluated them) but land in `locate`'s template/generated tiers.
pub fn sources(docs: &[PathBuf]) -> Result<Vec<Arc<FileText>>, LpError> {
    let mut found: Vec<Arc<FileText>> = Vec::new();
    let mut queue: Vec<PathBuf> = docs.to_vec();
    while let Some(path) = queue.pop() {
        if found.iter().any(|file| file.path == path) {
            continue;
        }
        let file = Arc::new(FileText::load(&path)?);
        let dir = path.parent().unwrap_or(Path::new(".")).to_path_buf();
        for included in included_paths(&file.text, &dir) {
            if !found.iter().any(|file| file.path == included) {
                queue.push(included);
            }
        }
        found.push(file);
    }
    found.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(found)
}

/// Literal `#include "..."` targets in a file, resolved against its directory.
fn included_paths(text: &str, dir: &Path) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    let mut rest = text;
    while let Some(at) = rest.find("#include") {
        rest = rest[at + "#include".len()..].trim_start();
        let rest_after_paren = rest.strip_prefix('(').map(str::trim_start).unwrap_or(rest);
        let Some(quoted) = rest_after_paren.strip_prefix('"') else {
            continue;
        };
        let Some(end) = quoted.find('"') else {
            continue;
        };
        let target = dir.join(&quoted[..end]);
        if target.exists() {
            paths.push(target);
        }
        rest = &quoted[end + 1..];
    }
    paths
}

/// A chunk name that names a file is a *root*: tangling writes it to disk.
/// Everything else is a fragment that only appears where it is referenced.
pub fn is_root(name: &str) -> bool {
    let file = name.rsplit('/').next().unwrap_or(name);
    match file.rsplit_once('.') {
        Some((stem, ext)) => {
            !stem.is_empty() && !ext.is_empty() && ext.chars().all(|c| c.is_ascii_alphanumeric())
        }
        None => false,
    }
}

/// Reject names that would write outside the output directory.
pub fn check_output_path(name: &str) -> Result<(), LpError> {
    let unsafe_name = name.is_empty()
        || name.starts_with('/')
        || name.contains('\\')
        || Path::new(name).components().any(|c| {
            matches!(
                c,
                std::path::Component::ParentDir
                    | std::path::Component::RootDir
                    | std::path::Component::Prefix(_)
            )
        });

    if unsafe_name {
        return Err(LpError::plain(format!("unsafe chunk name {name:?}"))
            .with_help("root chunk names must be relative paths inside --out, without `..`"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roots_are_names_that_look_like_files() {
        for name in ["main.c", "src/lib.rs", "Cargo.toml"] {
            assert!(is_root(name), "{name}");
        }
        for name in ["imports", "body", "v1", "notes.", ".hidden"] {
            assert!(!is_root(name), "{name}");
        }
    }

    #[test]
    fn output_paths_cannot_escape_the_output_directory() {
        assert!(check_output_path("src/lib.rs").is_ok());
        for name in ["", "/etc/passwd", "../escape", "a/../../escape", "a\\b"] {
            assert!(check_output_path(name).is_err(), "{name}");
        }
    }
}
