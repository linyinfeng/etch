#import "../../package/lib.typ": chunk, file

= Where each generated line came from

The previous chapter assumed that something knows which declaration produced a line. This
is that something: a record written while tangling, kept next to the files it explains.

What the expansion knows for free is exactly what a diagnostic cannot supply. The compiler
sees `src/main.rs` and nothing else, but the pass that wrote that file knew, line by line,
which declaration it was writing for. So the answer is recorded at the only moment it is
cheap, and the rest of the program reads it back afterwards.

== Runs, not lines

A record per output line would be three times the size and would say nothing more: the
lines from one declaration are consecutive by construction, and only a reference
interrupts them. So a map stores *runs* — the first and last output line of a stretch that
came from one chunk — and the offset into the chunk is computed when someone asks, which
is once per diagnostic.

The maps live one per directory rather than in one file at the top, because a map travels
with the files it explains: move a directory, and its map goes with it. It also means a
lookup only has to consult the maps under the output directory, and that the most specific
one can win when more than one could explain a name.

There is a version number because a map outlives one run: a checkout can hold maps written
by an older `etch`, and reading one has to be able to say "not mine" instead of guessing.

== The shape of the record

The names in the skeleton carry a file prefix, `map:`, and the reason is worth knowing early: chunk names are
global to the whole document, and the document is not one file. Two chapters that both called a fragment
`the module note` would concatenate their bodies into whichever file referenced that name — silently, because
a repeated name is a concatenation and not a collision.

#file("src/map.rs", ````rust
<<map: the imports>>

<<map: the two constants>>

<<map: what a map holds>>

<<map: a fresh map>>

impl EtchMap {
    <<map: is it empty?>>

    <<map: who wrote these files>>

    <<map: write only what changed>>

    <<map: read one map>>

    <<map: when there is no output directory>>

    <<map: walk it>>

    <<map: the json, and where it goes>>
}

impl FileMap {
    <<map: which chunk produced a line>>
}

<<map: paths, in one shape>>

<<map: finding the map that knows a file>>
````)

`docs` is a list, not a single path, because several documents can be tangled into one
output directory — the chapters of a book, say — and the map should not pretend that one
of them is *the* source.

`lang` is the language the fence declared, and nothing in this program reads it back. It is
in the map because the map is an interface: whatever consumes generated code later — an
editor, another tool — cannot derive the language from a file name, and re-deriving it is
not its job.

#chunk("map: the imports", ````rust
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use ignore::WalkBuilder;
use serde::{Deserialize, Serialize};

use crate::diag::EtchError;
use crate::disk;
````)

== Two names the rest of the program shares

The file name is a constant because three other places care about it: this module writes
it, the ownership check in `status.rs` exempts it, and `explain.rs` walks the tree looking
for exactly this name. The version is a constant for the same reason — it is a fact about
the format, and facts about the format belong in one place.

#chunk("map: the two constants", ````rust
pub const MAP_FILE: &str = ".etchmap.json";
const VERSION: u32 = 6;
````)

== What a map holds

Three structures, all serde-shaped, because the file's format is the interface: a map, the
entry for one file, and one run of lines.

#chunk("map: what a map holds", ````rust
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
````)

== A new map is empty, and says which version it is

A `Default` implementation, and the only thing in it worth reading is the version: a map that
was constructed rather than read still says which schema it is.

#chunk("map: a fresh map", ````rust
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
````)

== Writing, reading, and the one that must not write

Six small methods, and only one of them has a decision in it. `write_if_changed` compares
the serialized bytes before writing, because build tools watch mtimes: a pass that changed
nothing should leave the directory exactly as it found it, or every save would look like a
reason to rebuild.

Reading is split in two for the same reason the maps are: `read` knows one directory, and
the search knows all of them, in a stable order so that two runs report the same thing.
That search is the whole index — there is no registry of documents to keep in sync, the
directory tree *is* the index.

#chunk("map: is it empty?", ````rust
pub fn is_empty(&self) -> bool {
    self.files.is_empty()
}
````)

#chunk("map: who wrote these files", ````rust
pub fn set_docs(&mut self, docs: impl IntoIterator<Item = String>) {
    self.docs = docs
        .into_iter()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect();
}
````)

#chunk("map: write only what changed", ````rust
pub fn write_if_changed(&self, dir: &Path) -> Result<bool, EtchError> {
    let (path, json) = self.serialize(dir)?;
    if disk::read_ok(&path)?.as_deref() == Some(json.as_str()) {
        return Ok(false);
    }
    disk::write(&path, json)?;
    Ok(true)
}
````)

#chunk("map: read one map", ````rust
pub fn read(dir: &Path) -> Result<Self, EtchError> {
    let path = dir.join(MAP_FILE);
    let text = disk::read(&path)?;
    serde_json::from_str(&text)
        .map_err(|err| EtchError::plain(format!("{}: {err}", path.display())))
}
````)

The search is two fragments rather than one: the guard for an output directory that does not exist yet, and
the walk.

#chunk("map: when there is no output directory", ````rust
pub fn read_all(out: &Path) -> Vec<(String, EtchMap)> {
    if !out.exists() {
        return Vec::new();
    }
````)

#chunk("map: walk it", ````rust
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
````)

#chunk("map: the json, and where it goes", ````rust
fn serialize(&self, dir: &Path) -> Result<(PathBuf, String), EtchError> {
    let path = dir.join(MAP_FILE);
    let json = serde_json::to_string_pretty(self)
        .map_err(|err| EtchError::plain(format!("{}: {err}", path.display())))?;
    Ok((path, json + "\n"))
}
````)

== Which chunk produced a line

The lookup asks for the run that covers the line, and if there is none it takes the closest
earlier run instead of giving up. That tolerance is deliberate: for a line the map does not
cover — a file edited after the last pass, or a line number from a stale build — "the
declaration that was writing just before this point" is a better answer than a shrug, and
the offset it reports is allowed to run past the end of the chunk when that is what the
truth looks like.

#chunk("map: which chunk produced a line", ````rust
pub fn locate(&self, line: usize) -> Option<(&Run, usize)> {
    let run = self
        .runs
        .iter()
        .find(|run| run.first <= line && line <= run.last)
        .or_else(|| self.runs.iter().rev().find(|run| run.first < line))?;
    Some((run, line.saturating_sub(run.first) + 1))
}
````)

== Paths, in one shape

Every path in this module is a string with forward slashes, and the output directory itself
is the empty string. Those strings travel through Typst declaration names, through
diagnostics written by other tools, and through JSON, so the shape is fixed once here
rather than re-derived at each use.

#chunk("map: paths, in one shape", ````rust
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
````)

== Finding the map that knows a file

This is the part that has to be careful, because the same file is named differently by
different callers: a diagnostic may write the path relative to the output directory,
relative to the working directory, or absolutely. So the directory part of what was
reported is compared against each map's own directory, and a map is a candidate when it is
a suffix of that path, or is the output directory itself.

When several maps could explain the name, the most specific one wins — a map further down
the tree says more about a file than one above it. When two are equally specific, that is
an error with the candidates listed, because picking one would silently answer about the
wrong file. And when none matches, the error lists every file the maps know, which turns a
typo into something visible instead of a mystery.

#chunk("map: finding the map that knows a file", ````rust
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
````)
