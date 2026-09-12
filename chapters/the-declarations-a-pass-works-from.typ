#import "@local/lp:0.1.0": chunk, file

= The declarations a pass works from

Everything up to here has been reading: the document declares chunks, and the pieces around it look
things up in the result. What follows is the writing half, and it is not one chapter, because a pass has
parts worth arguing for separately: the declarations it works from, the expansion of one reference, what
it plans to write, writing it, and the book it carries into the tree.

The shape of a pass is the shape of any careful build: *decide what would be written, then write only what
changed, then judge the result*. Those are `plan`, the write loop and the ownership check, and keeping them
apart is what makes `--check` a dry run rather than a special case of writing.

```
  one pass

    the document
        │  one query, and only evaluation can answer it
        ▼
    the declarations ──▶ blocks ──▶ a plan ──▶ the writes ──▶ the ownership check
                                        │            │
                                        │            └─ only the files whose bytes differ
                                        └─ nothing is written before the plan says so

    every line that is written is recorded as it is written ──▶ the maps
```

The chapters that follow take that picture apart one box at a time, and the order they are in is the order the
boxes depend on each other.

== Expansion is one idea, applied recursively

A line that is exactly `<<name>>`, with any indentation, is replaced by the text of that
chunk, with the reference's indentation added to every line of it. That is the whole
mechanism, and it is textual: nothing here knows what language the text is, or that files
have syntax at all.

Two consequences explain most of the code below. A chunk may be referenced before it is
declared — the document is expanded, not interpreted — so the pass cannot work in one
linear sweep. And the same chunk may be referenced from several places, so its text is
assembled per reference rather than written once.

Three things can be wrong, and each has its own check: a reference to a name nobody declared, a cycle of
references, and a declaration with no body. None of the three can point at a place in the document, because
there are no source positions to point at (D14); what they can do is name the chunk and quote the line, which
is what a reader needs in order to find it.

#file("src/tangle.rs", ````rust
<<tangle: the imports>>

<<tangle: a chunk as declared>>

<<tangle: an error quotes the line>>

<<tangle: the set of chunks>>

impl<'a> ChunkSet<'a> {
    <<tangle: one set, in document order>>

    <<tangle: the declared files>>

    <<tangle: every name>>

    <<tangle: the blocks behind a name>>
}

<<tangle: names that stay inside the output directory>>

<<tangle: what counts as a reference>>

<<tangle: how to write one without it being one>>

<<tangle: what comes out of an expansion>>

impl Tangled {
    <<tangle: one line, with its indentation>>
}

<<tangle: expanding a root>>

fn expand_chunk(
    set: &ChunkSet,
    name: &str,
    indent: &str,
    stack: &mut Vec<String>,
    out: &mut Tangled,
) -> Result<(), LpError> {
    <<tangle: a cycle, named>>
    stack.push(name.to_string());

    for block in set.get(name).unwrap_or(&[]) {
        <<tangle: an empty chunk>>

        <<tangle: one line at a time>>
    }

    stack.pop();
    Ok(())
}

<<tangle: what a pass reports>>

<<tangle: what a pass is>>

<<tangle: the plan>>

pub(crate) fn declared_book(docs: &[PathBuf]) -> Result<Option<Book>, LpError> {
    let typst = metadata::binary()?;
    for declaration in metadata::declarations(&typst, docs)? {
        if declaration.kind()? == metadata::Kind::Options {
            return Ok(Some(settings(&declaration)?));
        }
    }
    Ok(None)
}

pub fn plan(docs: &[PathBuf]) -> Result<Plan, LpError> {
    <<tangle: ask typst what the document declares>>

    <<tangle: a document with no files>>

    <<tangle: fragments nobody uses>>

    <<tangle: declarations with no language>>

    let mut maps: BTreeMap<PathBuf, LpMap> = BTreeMap::new();
    let mut texts: BTreeMap<String, String> = BTreeMap::new();
    let mut produced: BTreeSet<String> = BTreeSet::new();
    for root in set.roots() {
        <<tangle: check it, and expand it>>

        <<tangle: the same path twice>>

        <<tangle: record where each line came from>>
    }

    let mut book_copies = Vec::new();
    if let Some(settings) = &book {
        let absolute: Vec<PathBuf> = docs
            .iter()
            .map(|doc| doc.canonicalize().unwrap_or_else(|_| doc.clone()))
            .collect();
        book_copies = crate::book::plan(settings, &metadata::common_ancestor(&absolute))?;
        for copy in &book_copies {
            let (dir, name) = split(&copy.to);
            if maps
                .get(Path::new(dir))
                .is_some_and(|map| map.files.contains_key(name))
            {
                return Err(
                    LpError::plain(format!("the book would overwrite {}", copy.to)).with_help(
                        "a declaration writes that path; change `book-directory` or `book-files`",
                    ),
                );
            }
        }
    }

    Ok(Plan {
        maps,
        texts,
        warnings,
        blocks,
        book,
        book_copies,
    })
}

<<tangle: what the documents produce, per directory>>

pub fn run(docs: &[PathBuf], out: &Path, check: bool) -> Result<Outcome, LpError> {
    <<tangle: plan, then an empty outcome>>

    for (root, text) in &plan.texts {
        <<tangle: write what changed>>

        <<tangle: or say what drifted>>
    }

    <<tangle: everything must be accounted for>>

    if !check {
        <<tangle: the maps, and the ones that stopped applying>>
    }
    Ok(outcome)
}

<<tangle: every name a block references>>

<<tangle: where two texts first differ>>

<<tangle: the drift report>>

<<tangle: the two shapes, pinned>>
````)

== A chunk, and the error that quotes it

A `Block` is the record the chapter before this one described, with the one thing that layer had already
resolved and this pass needs: whether the declaration is a file rather than a fragment. The method on it is
the error constructor, and it exists because an error here cannot point at a place — it names the chunk, and
it quotes the line.

#chunk("tangle: the imports", ````rust
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use crate::diag::LpError;
use crate::map::{Book, FileMap, LpMap, MAP_FILE, Run, split};
use crate::metadata;
````)

#chunk("tangle: a chunk as declared", ````rust
pub struct Block {
    pub root: bool,
    pub name: String,
    pub lang: Option<String>,
    pub text: String,
}
````)

#chunk("tangle: an error quotes the line", ````rust
impl Block {
    fn error(&self, index: usize, message: impl Into<String>) -> LpError {
        let line = self.text.lines().nth(index).unwrap_or("");
        LpError::plain(format!("{}: {line}", message.into())).with_help(format!(
            "in chunk ⟪{}⟫, line {} of it",
            self.name,
            index + 1
        ))
    }
}
````)

== The chunks of one invocation

The set is built once per run, over every document that was named, and it keeps the blocks
in the order the document produced them. That order is the order a name's declarations are
concatenated in, which is why the map is a map to a *list* and not to a block.

#chunk("tangle: the set of chunks", ````rust
pub struct ChunkSet<'a> {
    chunks: BTreeMap<&'a str, Vec<&'a Block>>,
}
````)

#chunk("tangle: one set, in document order", ````rust
pub fn new(blocks: &'a [Block]) -> Self {
    let mut chunks: BTreeMap<&str, Vec<&Block>> = BTreeMap::new();
    for block in blocks {
        chunks.entry(block.name.as_str()).or_default().push(block);
    }
    Self { chunks }
}
````)

#chunk("tangle: the declared files", ````rust
pub fn roots(&self) -> Vec<&'a str> {
    let mut roots: Vec<&str> = Vec::new();
    for blocks in self.chunks.values() {
        if let Some(block) = blocks.first()
            && block.root
            && !roots.contains(&block.name.as_str())
        {
            roots.push(block.name.as_str());
        }
    }
    roots
}
````)

#chunk("tangle: every name", ````rust
pub fn names(&self) -> impl Iterator<Item = &'a str> {
    self.chunks.keys().copied()
}
````)

#chunk("tangle: the blocks behind a name", ````rust
pub fn get(&self, name: &str) -> Option<&[&'a Block]> {
    self.chunks.get(name).map(Vec::as_slice)
}
````)

== A declared path is not allowed to escape

A file declaration writes a path, and a path can be a lie: absolute, `..`, a Windows drive.
The check is a whitelist in disguise — every component has to be an ordinary one — and it
runs before anything is expanded, so a document cannot write outside the directory it was
given even by accident.

#chunk("tangle: names that stay inside the output directory", ````rust
pub fn check_output_path(name: &str) -> Result<(), LpError> {
    let unsafe_name = name.is_empty()
        || name.starts_with('/')
        || name.contains('\\')
        || Path::new(name).components().any(|component| {
            matches!(
                component,
                std::path::Component::ParentDir
                    | std::path::Component::RootDir
                    | std::path::Component::Prefix(_)
            )
        });

    if unsafe_name {
        return Err(LpError::plain(format!("unsafe chunk name {name:?}"))
            .with_help("a file declaration must be a relative path inside --out, without `..`"));
    }
    Ok(())
}
````)
