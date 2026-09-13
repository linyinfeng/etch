use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use ignore::WalkBuilder;
use serde::{Deserialize, Serialize};

use crate::diag::EtchError;
use crate::disk;

pub const MAP_FILE: &str = ".etchmap.json";
const VERSION: u32 = 6;

#[derive(Debug, Serialize, Deserialize)]
pub struct EtchMap {
    pub version: u32,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub docs: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub book: Option<Book>,
    pub files: BTreeMap<String, FileMap>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Book {
    pub directory: String,
    pub files: Vec<String>,
    #[serde(default, skip_serializing)]
    pub extra: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileMap {
    pub lang: Option<String>,
    pub runs: Vec<Run>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Run {
    pub chunk: String,
    pub first: usize,
    pub last: usize,
}

impl Default for EtchMap {
    fn default() -> Self {
        Self {
            version: VERSION,
            docs: Vec::new(),
            book: None,
            files: BTreeMap::new(),
        }
    }
}

impl EtchMap {
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

    pub fn write_if_changed(&self, dir: &Path) -> Result<bool, EtchError> {
        let (path, json) = self.serialize(dir)?;
        if disk::read_ok(&path)?.as_deref() == Some(json.as_str()) {
            return Ok(false);
        }
        disk::write(&path, json)?;
        Ok(true)
    }

    pub fn read(dir: &Path) -> Result<Self, EtchError> {
        let path = dir.join(MAP_FILE);
        let text = disk::read(&path)?;
        serde_json::from_str(&text)
            .map_err(|err| EtchError::plain(format!("{}: {err}", path.display())))
    }

    pub fn read_all(out: &Path) -> Vec<(String, EtchMap)> {
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

    fn serialize(&self, dir: &Path) -> Result<(PathBuf, String), EtchError> {
        let path = dir.join(MAP_FILE);
        let json = serde_json::to_string_pretty(self)
            .map_err(|err| EtchError::plain(format!("{}: {err}", path.display())))?;
        Ok((path, json + "\n"))
    }
}

impl FileMap {
    pub fn locate(&self, line: usize) -> Option<(&Run, usize)> {
        let run = self
            .runs
            .iter()
            .find(|run| run.first <= line && line <= run.last)
            .or_else(|| self.runs.iter().rev().find(|run| run.first < line))?;
        Some((run, line.saturating_sub(run.first) + 1))
    }
}

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

pub fn relative(out: &Path, path: &Path) -> String {
    path.strip_prefix(out)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

pub fn resolve_all<'a>(
    maps: &'a [(String, EtchMap)],
    file: &str,
) -> Result<(&'a str, &'a str, &'a FileMap), EtchError> {
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
        return Err(EtchError::plain(format!("{file}: no map knows this file"))
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
        return Err(
            EtchError::plain(format!("{file}: which map?")).with_help(format!("candidates: {all}"))
        );
    }
    Ok(*best)
}
