//! Where the lines of a generated file came from.
//!
//! Not line numbers: Typst exposes no source positions, and recovering them would
//! mean searching the source or parsing Typst again — neither is worth doing for
//! a convenience (ADR D14). What expansion *does* know for free is which chunk
//! produced each run of output lines, and how far into that chunk the run starts.
//! That is what a map records, one per directory, next to the files it explains.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use ignore::WalkBuilder;
use serde::{Deserialize, Serialize};

use crate::diag::LpError;

pub const MAP_FILE: &str = ".lpmap.json";
const VERSION: u32 = 5;

#[derive(Debug, Serialize, Deserialize)]
pub struct LpMap {
    pub version: u32,
    /// Documents that produced the files listed here.
    pub docs: Vec<String>,
    /// Keyed by file name *within this directory*.
    pub files: BTreeMap<String, FileMap>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileMap {
    pub lang: Option<String>,
    /// Consecutive output lines that came from one chunk, in output order.
    pub runs: Vec<Run>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Run {
    pub chunk: String,
    /// 1-based first and last output line of the run.
    pub first: usize,
    pub last: usize,
}

impl Default for LpMap {
    fn default() -> Self {
        Self {
            version: VERSION,
            docs: Vec::new(),
            files: BTreeMap::new(),
        }
    }
}

impl LpMap {
    pub fn is_empty(&self) -> bool {
        self.files.is_empty()
    }

    pub fn set_docs(&mut self, docs: impl IntoIterator<Item = String>) {
        self.docs = docs
            .into_iter()
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect();
    }

    /// Write only when the serialized map actually differs, so a no-op pass leaves
    /// the mtime alone.
    pub fn write_if_changed(&self, dir: &Path) -> Result<bool, LpError> {
        let (path, json) = self.serialize(dir)?;
        if std::fs::read_to_string(&path).ok().as_deref() == Some(json.as_str()) {
            return Ok(false);
        }
        std::fs::write(&path, json).map_err(|err| LpError::io(&path, err))?;
        Ok(true)
    }

    pub fn read(dir: &Path) -> Result<Self, LpError> {
        let path = dir.join(MAP_FILE);
        let text = std::fs::read_to_string(&path).map_err(|err| LpError::io(&path, err))?;
        serde_json::from_str(&text)
            .map_err(|err| LpError::plain(format!("{}: {err}", path.display())))
    }

    /// Every map under `out`, paired with its directory relative to `out` (`""`
    /// for the output directory itself), in a stable order.
    pub fn read_all(out: &Path) -> Vec<(String, LpMap)> {
        if !out.exists() {
            return Vec::new();
        }

        let walker = WalkBuilder::new(out)
            .standard_filters(false)
            .hidden(false)
            .build();
        let mut found = Vec::new();
        for entry in walker.flatten() {
            if entry.file_name() != MAP_FILE {
                continue;
            }
            let Some(dir) = entry.path().parent() else {
                continue;
            };
            if let Ok(map) = Self::read(dir) {
                found.push((relative(out, dir), map));
            }
        }
        found.sort_by(|a, b| a.0.cmp(&b.0));
        found
    }

    fn serialize(&self, dir: &Path) -> Result<(PathBuf, String), LpError> {
        let path = dir.join(MAP_FILE);
        let json = serde_json::to_string_pretty(self)
            .map_err(|err| LpError::plain(format!("{}: {err}", path.display())))?;
        Ok((path, json + "\n"))
    }
}

impl FileMap {
    /// Which chunk produced this output line, and how far into it the line is
    /// (1-based). Falls back to the closest earlier run so blank lines still
    /// report something.
    pub fn locate(&self, line: usize) -> Option<(&Run, usize)> {
        let run = self
            .runs
            .iter()
            .find(|run| run.first <= line && line <= run.last)
            .or_else(|| self.runs.iter().rev().find(|run| run.first < line))?;
        Some((run, line.saturating_sub(run.first) + 1))
    }
}

/// Split an output path into `(directory, file name)`; the directory is `""` for
/// files directly in the output directory. Both use forward slashes.
pub fn split(rel: &str) -> (&str, &str) {
    match rel.rsplit_once('/') {
        Some((dir, name)) => (dir, name),
        None => ("", rel),
    }
}

pub fn join(dir: &str, name: &str) -> String {
    if dir.is_empty() {
        name.to_string()
    } else {
        format!("{dir}/{name}")
    }
}

/// Relative path with forward slashes.
pub fn relative(out: &Path, path: &Path) -> String {
    path.strip_prefix(out)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

/// Find the map that knows a file: every directory's map is consulted, and the
/// most specific one wins.
///
/// The path may be written relative to the output directory, to the working
/// directory, or absolutely — so the *directory* part of what a toolchain reported
/// is compared against each map's own directory, and only maps that are a suffix
/// of it (or the output directory itself) are considered. A bare file name with
/// several candidates is an error rather than a guess.
pub fn resolve_all<'a>(
    maps: &'a [(String, LpMap)],
    file: &str,
) -> Result<(&'a str, &'a str, &'a FileMap), LpError> {
    let normalized = file.replace('\\', "/");
    let (indir, name) = split(&normalized);

    let mut candidates: Vec<(&str, &str, &FileMap)> = Vec::new();
    for (dir, map) in maps {
        let Some((key, entry)) = map.files.get_key_value(name) else {
            continue;
        };
        let in_scope = indir.is_empty()
            || dir.is_empty()
            || indir == dir
            || indir.ends_with(&format!("/{dir}"));
        if in_scope {
            candidates.push((dir.as_str(), key.as_str(), entry));
        }
    }

    candidates.sort_by_key(|(dir, _, _)| std::cmp::Reverse(dir.len()));
    let Some(best) = candidates.first() else {
        let known = maps
            .iter()
            .flat_map(|(dir, map)| map.files.keys().map(move |name| join(dir, name)))
            .collect::<Vec<_>>()
            .join(", ");
        return Err(LpError::plain(format!("{file}: not in the line map"))
            .with_help(format!("known files: {known}")));
    };
    if candidates
        .get(1)
        .is_some_and(|(dir, _, _)| dir.len() == best.0.len())
    {
        let all = candidates
            .iter()
            .map(|(dir, name, _)| join(dir, name))
            .collect::<Vec<_>>()
            .join(", ");
        return Err(LpError::plain(format!("{file}: which line map?"))
            .with_help(format!("candidates: {all}")));
    }
    Ok(*best)
}
