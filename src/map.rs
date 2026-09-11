//! The line map: which `.typ` line produced which line of which output file.

use std::collections::BTreeMap;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::diag::LpError;

pub const MAP_FILE: &str = ".lpmap.json";
const VERSION: u32 = 1;

#[derive(Debug, Serialize, Deserialize)]
pub struct LpMap {
    pub version: u32,
    pub docs: Vec<String>,
    /// Keyed by the output file's path relative to `--out`.
    pub files: BTreeMap<String, FileMap>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FileMap {
    /// The `.typ` document this file was tangled from.
    pub typ: String,
    pub lang: Option<String>,
    /// `[output line, .typ line]`, 1-based, in output order.
    pub lines: Vec<[usize; 2]>,
    /// Chunks that contributed lines to this file, in document order.
    pub chunks: Vec<ChunkEntry>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ChunkEntry {
    pub name: String,
    pub typ_line: usize,
    pub end_line: usize,
}

impl LpMap {
    pub fn new(docs: &[String]) -> Self {
        Self {
            version: VERSION,
            docs: docs.to_vec(),
            files: BTreeMap::new(),
        }
    }

    pub fn write(&self, out: &Path) -> Result<(), LpError> {
        let path = out.join(MAP_FILE);
        let json = serde_json::to_string_pretty(self)
            .map_err(|e| LpError::plain(format!("{}: {e}", path.display())))?;
        std::fs::write(&path, json + "\n").map_err(|e| LpError::io(&path, e))
    }

    pub fn read(out: &Path) -> Result<Self, LpError> {
        let path = out.join(MAP_FILE);
        let text = std::fs::read_to_string(&path).map_err(|e| LpError::io(&path, e))?;
        serde_json::from_str(&text).map_err(|e| LpError::plain(format!("{}: {e}", path.display())))
    }
}

impl FileMap {
    /// Where did this output line come from? Falls back to the closest earlier
    /// line so blank lines and generated separators still report something.
    pub fn locate(&self, line: usize) -> Option<[usize; 2]> {
        let exact = self.lines.iter().find(|entry| entry[0] == line);
        exact
            .or_else(|| self.lines.iter().rev().find(|entry| entry[0] < line))
            .copied()
    }

    pub fn chunk_at(&self, typ_line: usize) -> Option<&ChunkEntry> {
        self.chunks
            .iter()
            .rev()
            .find(|c| c.typ_line <= typ_line && typ_line <= c.end_line)
    }
}

/// Resolve a user-supplied file argument against the map: relative path first,
/// then path suffix, then unique basename.
pub fn resolve<'a>(map: &'a LpMap, file: &str) -> Result<(&'a str, &'a FileMap), LpError> {
    if let Some((key, entry)) = map.files.get_key_value(file) {
        return Ok((key.as_str(), entry));
    }

    let wanted = file.rsplit('/').next().unwrap_or(file);
    let matches: Vec<(&str, &FileMap)> = map
        .files
        .iter()
        .filter(|(key, _)| {
            key.as_str() == file
                || key.ends_with(&format!("/{file}"))
                || key.rsplit('/').next() == Some(wanted)
        })
        .map(|(key, entry)| (key.as_str(), entry))
        .collect();

    match matches.as_slice() {
        [(key, entry)] => Ok((*key, *entry)),
        [] => Err(
            LpError::plain(format!("{file}: not in the line map")).with_help(format!(
                "known files: {}",
                map.files.keys().cloned().collect::<Vec<_>>().join(", ")
            )),
        ),
        _ => Err(LpError::plain(format!(
            "{file}: ambiguous, matches {}",
            matches
                .iter()
                .map(|(k, _)| *k)
                .collect::<Vec<_>>()
                .join(", ")
        ))),
    }
}
