#import "@local/lp:0.1.0": chunk, file, show-rule, tangle-options
#show: show-rule

// Where the tangled tree keeps this book, so that a tree can be read — and re-tangled — without the
// repository it came from. The tree's own `.gitignore` travels with it: the book is the whole of what
// this repository was before tangling, not only its prose.
#tangle-options((
  book-directory: "book",
  book-files: (
    "lp.typ",
    "README.md",
    ".gitignore",
    "chapters/the-tool-in-its-own-words.typ",
    "chapters/four-claims.typ",
    "chapters/errors.typ",
  ),
))

#include "chapters/the-tool-in-its-own-words.typ"

= Part I — Writing a literate program

#include "chapters/four-claims.typ"

= The package: what a declaration is

This document is written with four functions — `chunk`, `file`, `tangle-options` and
`show-rule` — and none of them is
built into the tool. They are declared in `typst/lp.typ`, which this document produces: the syntax
and the tool that reads it share one source, so there is no second opinion about what a
declaration looks like.

`chunk` and `file` do two things each. They attach a metadata record — the name, the language
from the fence, the text — and then render the code as a titled block. That is the whole
difference between a fragment and a root: the same body, one word, and a record that says which
of the two it is. `show-rule` marks references when the document is woven.

The declarations deliberately do not depend on that show rule. A show rule that consumes an
element can hide it from a query, and that is not a hypothesis: a styling rule once made every
chunk in this project vanish from the pass that collects them (ADR D12). So the
metadata is attached where the declaration is written, and rendering is free to be as decorative
as it likes afterwards.

== The shape of the package

#file("typst/typst.toml", ````toml
<<package: the manifest>>
````)

#file("typst/lp.typ", ````typst
<<package: what a reference looks like>>

<<package: the escape>>

<<package: the indentation a reference contributes>>

<<package: the show rule>>

<<package: how a chunk is rendered>>

<<package: a fence without a language>>

<<package: a fragment>>

<<package: a root>>

<<package: options>>
````)

== The two patterns

The reference is a whole line: indentation, `<<`, a name without angle brackets, `>>`, and
nothing else. The indentation is captured rather than ignored, because it is part of what a
reference *means* — it is what indents the expansion when tangling, so the woven page has to show
it too, or the page disagrees with the file it claims to describe.

The second pattern is the escape, and it exists because this document quotes itself: a chapter
showing what a reference looks like has to write a line that looks exactly like one.

#chunk("package: what a reference looks like", ````typst
#let ref-re = regex("^(\\s*)<<([^<>]+)>>\\s*$")
````)

#chunk("package: the escape", ````typst
#let esc-re = regex("^(\\s*)@<<([^<>]+)>>\\s*$")
````)

#chunk("package: the indentation a reference contributes", ````typst
#let ref-indent(line) = {
  let m = line.match(ref-re)
  if m == none { "" } else { m.captures.at(0) }
}
````)

== The show rule, and the one thing it must not do

Marking references is cosmetics, and the comment in the file says so in as many words. What the
rule must not do is *consume* anything: it walks the lines of a raw block and rebuilds them, so
the element it was handed stays where it was for anyone who queries it later.

#chunk("package: the show rule", ````typst
#let show-rule(body) = {
  show raw.where(block: true): it => {
    let out = none
    for line in it.lines {
      let escaped = line.text.match(esc-re)
      let m = line.text.match(ref-re)
      let piece = if escaped != none {
        raw(escaped.captures.at(0) + "<<" + escaped.captures.at(1) + ">>")
      } else if m == none {
        line.body
      } else {
        (
          raw(ref-indent(line.text))
            + text(fill: rgb("#0a6"))[⟪#m.captures.at(1)⟫]
        )
      }
      out = if out == none { piece + linebreak() } else {
        out + piece + linebreak()
      }
    }
    out
  }
  body
}
````)

#chunk("package: how a chunk is rendered", ````typst
#let tile(name, lang, code) = block(
  breakable: true,
  width: 100%,
  inset: 8pt,
  radius: 3pt,
  fill: luma(238),
)[
  #text(size: 0.85em, weight: "bold", fill: luma(60))[⟪#name⟫]
  #h(0.6em)
  #text(size: 0.7em, fill: luma(120))[#if lang != none { lang }]
  #v(4pt)
  #code
]
````)

== A tag that may be missing

A fence without an info string has no `lang` field at all in Typst, which is why the field is read
with a default. The tag is data rather than a promise (D18), so a missing one means "not
declared" and the tool records nothing.

#chunk("package: a fence without a language", ````typst
#let lang-of(code) = code.at("lang", default: none)
````)

== The manifest

A local package is a directory with a manifest and an entry point, so the manifest is part of
what this document produces: name, version, and the file Typst should read. Its name and version
are the other half of the import at the top of this file — `@local/lp:0.1.0` — and the only
thing tying the two together is that a wrong pair fails loudly, with Typst saying it cannot find
the package.

#chunk("package: the manifest", ````toml
[package]
name = "lp"
version = "0.1.0"
entrypoint = "lib.typ"
````)

== The two declarations

Two nearly identical functions, and the whole difference is the record's first field. They are
written out rather than generated from a parameter because the metadata's shape is the interface
between the document and the tool: it should be readable in one place, not assembled from an
argument.

#chunk("package: a fragment", ````typst
#let chunk(name, code) = {
  [#metadata((
    lp: "chunk",
    name: name,
    lang: lang-of(code),
    text: code.text,
  ))<lp-decl>]
  tile(name, lang-of(code), code)
}
````)

#chunk("package: a root", ````typst
#let file(path, code) = {
  [#metadata((
    lp: "file",
    name: path,
    lang: lang-of(code),
    text: code.text,
  ))<lp-decl>]
  tile(path, lang-of(code), code)
}
````)

== Settings, and why they are a dict

Not everything a document says is a chunk. Some of it is about the tangling itself — where the book is
carried, which of its files travel with the tree — and it belongs in the document rather than on the
command line: the output is the book's, not the invocation's, and a tree whose contents depend on how
someone called the tool is a tree nobody can check.

So there is one function for settings, and it takes a dict. A dict because the set of settings will
change: adding one should add a key, not another name to the syntax. Unknown keys are refused where they
are written, which is the only place the mistake is still fresh.

#chunk("package: options", ````typst
#let tangle-options(options) = {
  let known = ("book-directory", "book-files")
  for key in options.keys() {
    if not known.contains(key) {
      panic(
        "unknown tangle option: " + key + " (known: " + known.join(", ") + ")",
      )
    }
  }
  [#metadata((lp: "options", options: options))<lp-decl>]
}
````)

#include "chapters/errors.typ"

= Asking the document what it declares

This is the one thing `lp` cannot work out for itself. Typst is Turing-complete: a chunk can
come from a loop, a branch, a function, or a file that was `#include`d, so the only authority
on what a document declares is evaluating it. Rather than parse the document — which would
mean being wrong exactly where the document is clever — the tool asks Typst a question and
reads the answer.

The question is one `query`, and the package is what makes it possible: `chunk` and `file`
attach a metadata record to every declaration they are called with, carrying the name, the
language and the text. Everything else in this program works from that stream. Nothing is
recovered from the source afterwards, which is why the sources are never read.

== The shape of the file

#file("src/metadata.rs", ````rust
<<metadata: the imports>>

<<metadata: the one query>>

<<metadata: what a declaration says>>

<<metadata: the two kinds>>

impl Decl {
    <<metadata: a kind we do not know>>
}

<<metadata: finding typst>>

pub fn declarations(typst: &Path, docs: &[PathBuf]) -> Result<Vec<Decl>, LpError> {
    <<metadata: absolute documents, and where we are>>

    <<metadata: where the wrapper goes>>
    <<metadata: ask typst, and let the wrapper go>>

    <<metadata: when the document does not evaluate>>

    <<metadata: read the answer>>
    <<metadata: every kind is checked here>>
    Ok(declarations)
}

<<metadata: the wrapper document>>

impl Wrapper {
    <<metadata: writing the wrapper>>
}

<<metadata: removing it, whatever happens>>

<<metadata: the deepest directory that contains every document>>

<<metadata: the wrapper's directory, pinned>>
````)

== The query, which is the contract with the package

The record's field names are written twice: once in the package that emits them, and once in
the struct below that reads them. Nothing checks that the two agree — a mismatch shows up as
a serde error at runtime, reported with the raw output that Typst actually printed. That is
the weakest joint in the program, and it is a joint by construction: two languages, two
files, one agreement.

#chunk("metadata: the imports", ````rust
use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use crate::diag::LpError;
````)

#chunk("metadata: the one query", ````rust
const QUERY: &str = "query(<lp-decl>).map(declaration => declaration.value)";
````)

== What a declaration says, and the two kinds it can be

A declaration is data: which of the two functions produced it, the name, the language from
the fence, and the text. The kind is not free-form — the package emits `"chunk"` or
`"file"` — so anything else is a mistake in the package or in whatever produced the
metadata, and it is an error rather than a default. A third kind would mean the package grew
a feature the tool has not learned yet, which is not something to guess at.

#chunk("metadata: what a declaration says", ````rust
#[derive(Debug, Clone, Deserialize)]
pub struct Decl {
    pub lp: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub lang: Option<String>,
    #[serde(default)]
    pub text: String,
    #[serde(default)]
    pub options: Option<serde_json::Value>,
}
````)

#chunk("metadata: the two kinds", ````rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Chunk,
    File,
    Options,
}
````)

#chunk("metadata: a kind we do not know", ````rust
pub fn kind(&self) -> Result<Kind, LpError> {
    match self.lp.as_str() {
        "chunk" => Ok(Kind::Chunk),
        "file" => Ok(Kind::File),
        "options" => Ok(Kind::Options),
        other => Err(LpError::plain(format!(
            "{}: unknown declaration kind {other:?}",
            self.name
        ))
        .with_help("the package emits `lp: \"chunk\"`, `lp: \"file\"` or `lp: \"options\"`")),
    }
}
````)

== Finding typst

The binary is a hard dependency: without it there are no declarations to read. An explicit
override first, then `PATH`, and if neither works the error says what to do rather than
failing later with a confusing message.

#chunk("metadata: finding typst", ````rust
const PACKAGE_MANIFEST: &str = include_str!("../typst/typst.toml");
const PACKAGE_ENTRY: &str = include_str!("../typst/lp.typ");

pub const PACKAGE_ROOT: &str = ".lp";

const PACKAGE_DIR: &str = "packages";

const PACKAGE_NAMESPACE: &str = "local/lp/0.1.0";

pub fn unpack_package(root: &Path) -> Result<PathBuf, LpError> {
    let packages = root.join(PACKAGE_ROOT).join(PACKAGE_DIR);
    let dir = packages.join(PACKAGE_NAMESPACE);
    std::fs::create_dir_all(&dir).map_err(|err| LpError::io(&dir, err))?;
    for (name, text) in [("typst.toml", PACKAGE_MANIFEST), ("lib.typ", PACKAGE_ENTRY)] {
        let path = dir.join(name);
        if std::fs::read_to_string(&path).ok().as_deref() != Some(text) {
            std::fs::write(&path, text).map_err(|err| LpError::io(&path, err))?;
        }
    }
    Ok(packages)
}

pub fn binary() -> Result<PathBuf, LpError> {
    if let Some(path) = std::env::var_os("LP_TYPST") {
        return Ok(PathBuf::from(path));
    }
    let name = if cfg!(windows) { "typst.exe" } else { "typst" };
    std::env::var_os("PATH")
        .and_then(|paths| std::env::split_paths(&paths).map(|dir| dir.join(name)).find(|candidate| candidate.is_file()))
        .ok_or_else(|| {
            LpError::plain("no `typst` binary found").with_help(
                "tangling asks the document for its declarations, so typst has to be available (set LP_TYPST or put it on PATH)",
            )
        })
}
````)

== Asking the question

Four fragments, and together they are the whole interaction with the outside world: make the
paths absolute, decide where the wrapper lives, run Typst, and report what came back.

#chunk("metadata: absolute documents, and where we are", ````rust
let cwd = std::env::current_dir()
    .map_err(|err| LpError::plain(format!("cannot read the working directory: {err}")))?;
let docs: Vec<PathBuf> = docs
    .iter()
    .map(|doc| std::path::absolute(doc).unwrap_or_else(|_| cwd.join(doc)))
    .collect();
````)

#chunk("metadata: where the wrapper goes", ````rust
let root = common_ancestor(
    &docs
        .iter()
        .cloned()
        .chain([cwd.clone()])
        .collect::<Vec<_>>(),
);
````)

Two constraints meet here. Typst refuses to read outside its project root, and a document may
import a package from outside its own directory — so the root has to cover the working
directory *and* every document, and the wrapper has to live inside that root to be readable
at all. Hence a wrapper next to the documents, including them relatively, with the root
computed as the deepest directory that contains everything involved.

#chunk("metadata: ask typst, and let the wrapper go", ````rust
let packages = unpack_package(&common_ancestor(&docs))?;
let wrapper = Wrapper::write(&common_ancestor(&docs), &docs)?;
let output = Command::new(typst)
    .arg("eval")
    .arg(QUERY)
    .arg("--in")
    .arg(&wrapper.path)
    .arg("--root")
    .arg(&root)
    .arg("--package-path")
    .arg(&packages)
    .current_dir(&cwd)
    .output();
drop(wrapper);
````)

#chunk("metadata: when the document does not evaluate", ````rust
let output =
    output.map_err(|err| LpError::plain(format!("cannot run {}: {err}", typst.display())))?;
if !output.status.success() {
    let message = String::from_utf8_lossy(&output.stderr);
    return Err(LpError::plain(format!(
        "the document did not evaluate, so there are no chunks to tangle:\n{}",
        message.trim_end()
    )));
}
````)

The failure is reported with Typst's own message, because that is the message the person who
wrote the document needs to see — a missing bracket in a chunk is a document error, not a
tool error.

#chunk("metadata: read the answer", ````rust
let declarations: Vec<Decl> = serde_json::from_slice(&output.stdout).map_err(|err| {
    LpError::plain(format!("cannot read the document's declarations: {err}"))
        .with_help(String::from_utf8_lossy(&output.stdout).to_string())
})?;
````)

#chunk("metadata: every kind is checked here", ````rust
for declaration in &declarations {
    declaration.kind()?;
}
````)

== A file that exists for one command

The wrapper is a temporary document holding one `#include` per document named on the command
line. It is removed when it goes out of scope, and that includes the failing and panicking paths.

It lives under `.lp` because of what it is not: a file beside a document is a name taken from whoever
works there, and one reserved name is enough. Inside `.lp` a leftover — a run that was killed before it
could clean up — is invisible rather than reported, because no pass reads that directory at all.

#chunk("metadata: the wrapper document", ````rust
struct Wrapper {
    path: PathBuf,
}
````)

#chunk("metadata: writing the wrapper", ````rust
fn write(root: &Path, docs: &[PathBuf]) -> Result<Self, LpError> {
    let path = root
        .join(PACKAGE_ROOT)
        .join(format!("entry-{}.typ", std::process::id()));
    let mut text = String::new();
    for doc in docs {
        let relative = doc.strip_prefix(root).unwrap_or(doc);
        let quoted = relative
            .to_string_lossy()
            .replace('\\', "/")
            .replace('"', "\\\"");
        text.push_str(&format!("#include \"../{quoted}\"\n"));
    }
    std::fs::write(&path, text).map_err(|err| LpError::io(&path, err))?;
    Ok(Self { path })
}
````)

The paths are quoted and their backslashes and quotes escaped: a file name must not be able to
break the wrapper open, and on some systems a file name may contain a quote.

#chunk("metadata: removing it, whatever happens", ````rust
impl Drop for Wrapper {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}
````)

== The directory the wrapper lives in

The deepest directory containing every document. The wrapper goes into `.lp` under it, which is what lets
it say `#include "../…"` and reach every one of them; the deepest directory is what the `..` is relative to.
The unit test is here rather than in `tests/` because this arithmetic — walk up until every path fits — is
easy to get subtly wrong, and the failure mode is quiet: a wrapper written outside the root is simply
refused by Typst, with a message about a path, not about this function.

#chunk("metadata: the deepest directory that contains every document", ````rust
pub fn common_ancestor(docs: &[PathBuf]) -> PathBuf {
    let mut root = docs
        .first()
        .and_then(|doc| doc.parent())
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("/"));

    for doc in docs.iter().skip(1) {
        while !doc.starts_with(&root) {
            match root.parent() {
                Some(parent) => root = parent.to_path_buf(),
                None => return root,
            }
        }
    }
    root
}
````)

#chunk("metadata: the wrapper's directory, pinned", ````rust
#[cfg(test)]
mod tests {
    use super::common_ancestor;
    use std::path::{Path, PathBuf};

    #[test]
    fn the_wrapper_goes_where_every_document_lives() {
        assert_eq!(
            common_ancestor(&[
                PathBuf::from("/a/b/book.typ"),
                PathBuf::from("/a/b/chapter.typ")
            ]),
            Path::new("/a/b")
        );
        assert_eq!(
            common_ancestor(&[
                PathBuf::from("/a/book.typ"),
                PathBuf::from("/a/c/chapter.typ")
            ]),
            Path::new("/a")
        );
        assert_eq!(
            common_ancestor(&[PathBuf::from("/a/book.typ")]),
            Path::new("/a")
        );
    }
}
````)
= What a pass does with the declarations

Everything up to here has been reading: the document declares chunks, and two other pieces
look things up in the result. This chapter is the writing half, and it is where the rules
live.

The shape of a pass is the shape of any careful build: *decide what would be written, then
write only what changed, then judge the result*. Those are `plan`, the write loop and the
ownership check, and keeping them apart is what makes `--check` a dry run rather than a
special case of writing.

== Expansion is one idea, applied recursively

A line that is exactly `<<name>>`, with any indentation, is replaced by the text of that
chunk, with the reference's indentation added to every line of it. That is the whole
mechanism, and it is textual: nothing here knows what language the text is, or that files
have syntax at all.

Two consequences explain most of the code below. A chunk may be referenced before it is
declared — the document is expanded, not interpreted — so the pass cannot work in one
linear sweep. And the same chunk may be referenced from several places, so its text is
assembled per reference rather than written once.

Three things can be wrong, and each has its own check: a reference to a name nobody
declared, a cycle of references, and a declaration with no body. All three report the chunk
and the line inside it, never a source position — there are no source positions (ADR D14),
which is why the quoted line is what tells the reader where to look.

== The shape of the file

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

A `Block` is the record the previous chapter described, after the metadata layer has normalised
it — plus the one thing that layer had already resolved and this one needs: whether the
declaration is a root. The one method on it exists because errors here cannot point at a place:
an error about a chunk line quotes that line and says which line of which chunk it was.

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

== What a reference is

This predicate is the whole syntax of references: a line whose trimmed text starts with
`<<` and ends with `>>` around a non-empty name that contains no angle brackets. Anything
else is literal, which is what keeps `a << b` and `assert_eq!(x, "<<y>>")` out of trouble.

#chunk("tangle: what counts as a reference", ````rust
fn ref_target(line: &str) -> Option<(&str, &str)> {
    let trimmed = line.trim();
    let inner = trimmed.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some((inner, &line[..line.len() - line.trim_start().len()]))
}
````)

== And how to write one without it being one

`@<<name>>` stays literal — the escape's reason is with the pattern that recognises it — and
it is not a reference for the purposes of the unused-chunk warning either (D17).

#chunk("tangle: how to write one without it being one", ````rust
fn escaped_ref(line: &str) -> Option<String> {
    let indent = &line[..line.len() - line.trim_start().len()];
    let rest = line.trim().strip_prefix('@')?;
    let inner = rest.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some(format!("{indent}<<{inner}>>"))
}
````)

== What an expansion produces

The result of expanding a root is text and a list of runs. Keeping the runs here, rather
than deriving them later, is the reason provenance costs nothing: the line numbers are
known at the moment the line is written.

#chunk("tangle: what comes out of an expansion", ````rust
pub struct Tangled {
    pub text: String,
    pub runs: Vec<Run>,
    lines: usize,
}
````)

#chunk("tangle: one line, with its indentation", ````rust
fn push(&mut self, chunk: &str, indent: &str, line: &str) {
    if !line.trim().is_empty() {
        self.text.push_str(indent);
        self.text.push_str(line);
    }
    self.text.push('\n');
    self.lines += 1;
    match self.runs.last_mut() {
        Some(run) if run.chunk == chunk && run.last + 1 == self.lines => run.last = self.lines,
        _ => self.runs.push(Run {
            chunk: chunk.to_string(),
            first: self.lines,
            last: self.lines,
        }),
    }
}
````)

== Expanding a root, and the three ways it can fail

Three fragments: the entry point, the cycle check that turns a loop into a named chain, and the
inner loop that does the substitution.

#chunk("tangle: expanding a root", ````rust
pub fn expand(set: &ChunkSet, root: &str) -> Result<Tangled, LpError> {
    let mut out = Tangled {
        text: String::new(),
        runs: Vec::new(),
        lines: 0,
    };
    let mut stack = Vec::new();
    expand_chunk(set, root, "", &mut stack, &mut out)?;
    Ok(out)
}
````)

The recursion carries the indentation of the reference that pulled each chunk in, and a
stack of the names currently being expanded so that a cycle can be reported as the chain it
is. The stack is what makes the error message useful — "a -> b -> a" says where to look,
"cycle detected" does not.

Two consequences of that rule are worth knowing before writing a chunk. A fragment must not
contain the brace that closes the frame it is referenced in, because the indentation would move
it; and a fence has to be longer than the longest run of backticks inside the text it wraps
(which is why some blocks in this document open with five).

#chunk("tangle: a cycle, named", ````rust
if let Some(start) = stack.iter().position(|entry| entry == name) {
    let mut chain: Vec<String> = stack[start..].to_vec();
    chain.push(name.to_string());
    let message = format!("cycle in chunks: {}", chain.join(" -> "));
    let block = set.get(name).and_then(|blocks| blocks.first()).copied();
    return Err(match block {
        Some(block) => block.error(0, message),
        None => LpError::plain(message),
    });
}
````)

#chunk("tangle: an empty chunk", ````rust
if block.text.trim().is_empty() {
    stack.pop();
    return Err(LpError::plain(format!("chunk ⟪{name}⟫ is empty"))
        .with_help("delete the declaration, or give it a code block with a body"));
}
````)

The inner loop is the mechanism, and it is four lines of decision: an escaped reference is
written out with the `@` removed, an ordinary reference is looked up (missing names are an
error that lists what does exist) and expanded with the combined indentation, and anything
else is written as it stands.

#chunk("tangle: one line at a time", ````rust
for (index, line) in block.text.lines().enumerate() {
    if let Some(literal) = escaped_ref(line) {
        out.push(name, indent, &literal);
        continue;
    }
    match ref_target(line) {
        None => out.push(name, indent, line),
        Some((target, local_indent)) => {
            if set.get(target).is_none() {
                return Err(block
                    .error(index, format!("chunk ⟪{target}⟫ is not defined"))
                    .with_help(format!(
                        "referenced from ⟪{name}⟫; known chunks: {}",
                        set.names().collect::<Vec<_>>().join(", ")
                    )));
            }
            let nested = format!("{indent}{local_indent}");
            expand_chunk(set, target, &nested, stack, out)?;
        }
    }
}
````)

== What a pass reports, and what it plans

`Output` is what one file looked like to a pass, `Outcome` is the pass's whole answer —
changed, unchanged, drifted, unaccounted, warnings — and `Plan` is what a pass would do if
it were allowed to. The separation is what lets `--check` be a plan plus a comparison, with
no second implementation of anything.

#chunk("tangle: what a pass reports", ````rust
#[derive(Debug)]
pub struct Output {
    pub root: String,
    pub lines: usize,
    pub lang: Option<String>,
}
````)

#chunk("tangle: what a pass is", ````rust
#[derive(Debug, Default)]
pub struct Outcome {
    pub changed: Vec<Output>,
    pub unchanged: Vec<Output>,
    pub stale: Vec<String>,
    pub unaccounted: Vec<crate::status::Unaccounted>,
    pub warnings: Vec<String>,
}
````)

#chunk("tangle: the plan", ````rust
pub struct Plan {
    pub maps: BTreeMap<PathBuf, LpMap>,
    pub texts: BTreeMap<String, String>,
    pub warnings: Vec<String>,
    pub blocks: Vec<Block>,
    pub book: Option<Book>,
    pub book_copies: Vec<crate::book::Copy>,
}

fn settings(declaration: &metadata::Decl) -> Result<Book, LpError> {
    let value = declaration
        .options
        .clone()
        .unwrap_or(serde_json::Value::Null);
    let table = value
        .as_object()
        .ok_or_else(|| LpError::plain("tangle-options was given something that is not a dict"))?;
    for key in table.keys() {
        if key != "book-directory" && key != "book-files" {
            return Err(LpError::plain(format!("unknown tangle option {key:?}"))
                .with_help("known options: `book-directory`, `book-files`"));
        }
    }
    let directory = table
        .get("book-directory")
        .and_then(|value| value.as_str())
        .ok_or_else(|| {
            LpError::plain("tangle-options needs a `book-directory`")
                .with_help("a string: the directory inside the output that the book is copied into")
        })?
        .to_string();
    let mut files = Vec::new();
    if let Some(value) = table.get("book-files") {
        let list = value
            .as_array()
            .ok_or_else(|| LpError::plain("`book-files` is a list of file names"))?;
        for entry in list {
            let name = entry
                .as_str()
                .ok_or_else(|| LpError::plain("`book-files` is a list of file names"))?;
            if name.starts_with('/') || name.split('/').any(|part| part == "..") {
                return Err(
                    LpError::plain(format!("book-files: {name} leaves the source tree")).with_help(
                        "names are relative to the document, and a book stays inside it",
                    ),
                );
            }
            files.push(name.to_string());
        }
    }
    Ok(Book { directory, files })
}

fn book_relative(docs: &[PathBuf]) -> Vec<String> {
    let absolute: Vec<PathBuf> = docs
        .iter()
        .map(|doc| doc.canonicalize().unwrap_or_else(|_| doc.clone()))
        .collect();
    let root = metadata::common_ancestor(&absolute);
    absolute
        .iter()
        .map(|doc| {
            doc.strip_prefix(&root)
                .unwrap_or(doc)
                .to_string_lossy()
                .replace('\\', "/")
        })
        .collect()
}
````)

== Planning a pass

Planning begins by asking for the declarations — the one thing this tool cannot work out for
itself — and turning them into blocks.

#chunk("tangle: ask typst what the document declares", ````rust
let typst = metadata::binary()?;
let mut blocks: Vec<Block> = Vec::new();
let mut book: Option<Book> = None;
let declared = metadata::declarations(&typst, docs)?;
if declared.is_empty() {
    return Err(LpError::plain("the document declares no chunks").with_help(
    "import the package and declare them: `#import \"lp.typ\": chunk, file`, then `#chunk(\"name\", ```…```)` or `#file(\"src/main.rs\", ```…```)`",
));
}
for declaration in declared {
    match declaration.kind()? {
        metadata::Kind::Options => {
            if book.is_some() {
                return Err(LpError::plain("the document declares tangle options twice")
                    .with_help("one `#tangle-options(…)` call, with one dict"));
            }
            book = Some(settings(&declaration)?);
        }
        kind => blocks.push(Block {
            root: kind == metadata::Kind::File,
            name: declaration.name,
            lang: declaration.lang,
            text: declaration.text,
        }),
    }
}
````)

#chunk("tangle: a document with no files", ````rust
let set = ChunkSet::new(&blocks);
if set.roots().is_empty() {
    let listed = docs
        .iter()
        .map(|doc| doc.display().to_string())
        .collect::<Vec<_>>()
        .join(", ");
    return Err(LpError::plain(format!("no file declarations in {listed}"))
        .with_help("declare one: `#file(\"src/main.rs\", ```…```)`"));
}
````)

Fragments nobody references are a warning rather than an error, because a document may
legitimately hold a fragment for a chapter that is still being written — but a fragment that
was declared and then renamed away is almost always a mistake, and this is what catches it.
A declaration with no language tag is warned about for the same kind of reason: the tag is data
that downstream tools read and that this program refuses to guess from a file name, so a gap is
reported rather than quietly filled. The two checks are separate fragments for a reason this project kept
running into: a blank line inside a fragment referenced from an indented place used to turn into a line of
spaces, which is not layout. That is fixed where it belonged — the line writer leaves a blank line blank —
so the split is now only a question of what each warning is about.

#chunk("tangle: fragments nobody uses", ````rust
let mut warnings = Vec::new();
let referenced: BTreeSet<String> = blocks.iter().flat_map(refs_of).collect();
let file_names: BTreeSet<&str> = blocks
    .iter()
    .filter(|block| block.root)
    .map(|block| block.name.as_str())
    .collect();
for name in set.names() {
    if !file_names.contains(name) && !referenced.contains(name) {
        warnings.push(format!("chunk ⟪{name}⟫ is never referenced"));
    }
}
````)

#chunk("tangle: declarations with no language", ````rust
for name in set.names() {
    let missing = set
        .get(name)
        .is_some_and(|blocks| blocks.iter().any(|block| block.lang.is_none()));
    if missing {
        warnings.push(format!("chunk ⟪{name}⟫ is declared without a language"));
    }
}
````)

#chunk("tangle: check it, and expand it", ````rust
check_output_path(root)?;
let lang = set
    .get(root)
    .and_then(|blocks| blocks.first())
    .and_then(|block| block.lang.clone());
let tangled = expand(&set, root)?;
````)

#chunk("tangle: the same path twice", ````rust
if !produced.insert(root.to_string()) {
    return Err(LpError::plain(format!("output {root} is produced twice")));
}
````)

#chunk("tangle: record where each line came from", ````rust
let entry = FileMap {
    lang,
    runs: tangled.runs,
};
let (dir, name) = split(root);
maps.entry(PathBuf::from(dir))
    .or_default()
    .files
    .insert(name.to_string(), entry);
texts.insert(root.to_string(), tangled.text);
````)

== Judging the result

`produced` answers the question the ownership check asks: which files, per directory, did
this pass account for? It is derived from the maps rather than kept alongside them, so there
is exactly one answer to that question and no chance of the two disagreeing.

#chunk("tangle: what the documents produce, per directory", ````rust
pub fn produced(plan: &Plan) -> BTreeMap<String, BTreeSet<String>> {
    let mut produced: BTreeMap<String, BTreeSet<String>> = plan
        .maps
        .iter()
        .map(|(dir, map)| {
            (
                dir.to_string_lossy().replace('\\', "/"),
                map.files.keys().cloned().collect(),
            )
        })
        .collect();
    for copy in &plan.book_copies {
        let (dir, name) = split(&copy.to);
        produced
            .entry(dir.to_string())
            .or_default()
            .insert(name.to_string());
    }
    produced
}
````)

== Writing the pass

`run` is the three steps in order. First the plan.

#chunk("tangle: plan, then an empty outcome", ````rust
let plan = plan(docs)?;
let documented = book_relative(docs);
let book = plan.book.clone();
let mut outcome = Outcome {
    warnings: plan.warnings.clone(),
    ..Outcome::default()
};
````)

Then the loop that compares each planned file with what is on disk: identical bytes are left
alone — mtime included, so build tools do not rebuild — and a difference is either written,
or, in check mode, reported as drift.

#chunk("tangle: write what changed", ````rust
let (dir, name) = split(root);
let entry = &plan.maps[Path::new(dir)].files[name];
let dest = out.join(root);
let existing = std::fs::read_to_string(&dest).ok();
let output = Output {
    root: root.clone(),
    lines: text.lines().count(),
    lang: entry.lang.clone(),
};
````)

#chunk("tangle: or say what drifted", ````rust
if existing.as_deref() == Some(text.as_str()) {
    outcome.unchanged.push(output);
} else if check {
    outcome
        .stale
        .push(drift_report(root, existing.as_deref(), &entry.runs, text));
} else {
    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent).map_err(|err| LpError::io(parent, err))?;
    }
    std::fs::write(&dest, text).map_err(|err| LpError::io(&dest, err))?;
    outcome.changed.push(output);
}
````)

Then the ownership check, after the write, for the reason recorded in D20: a `.lpignore` can
itself be something the document produces, so a fresh tree has no control file until this
pass writes one, and checking first would refuse to bootstrap.

#chunk("tangle: everything must be accounted for", ````rust
if let Some(book) = &plan.book {
    let carried = crate::book::place(out, &plan.book_copies, check)?;
    if carried > 0 {
        let plural = if carried == 1 { "" } else { "s" };
        println!("carried {carried} book file{plural}");
    }
    let removed = crate::book::sweep(out, &book.directory, &plan.book_copies, check)?;
    if removed > 0 {
        let plural = if removed == 1 { "" } else { "s" };
        println!("removed {removed} stale book file{plural}");
    }
}
outcome.unaccounted = crate::status::unaccounted(out, &produced(&plan))?;
if !outcome.unaccounted.is_empty() {
    let listed = outcome
        .unaccounted
        .iter()
        .flat_map(|group| {
            let label = if group.dir.is_empty() {
                ".".to_string()
            } else {
                group.dir.clone()
            };
            group
                .entries
                .iter()
                .map(move |entry| format!("  {label}/{entry}"))
        })
        .collect::<Vec<_>>()
        .join("\n");
    return Err(LpError::plain(format!("nothing accounts for these files:\n{listed}")).with_help(
        "declare each one in the .lpignore of its directory, or delete it with `lp unaccounted --delete`",
    ));
}
````)

And last the maps: written only when they changed, and removed when the directory they
describe stopped producing anything, along with the directories themselves. A map is not a
log of what once existed; it describes what is there now.

#chunk("tangle: the maps, and the ones that stopped applying", ````rust
let mut live: BTreeSet<String> = BTreeSet::new();
for (dir, mut map) in plan.maps {
    if map.is_empty() {
        continue;
    }
    let dir = dir.to_string_lossy().replace('\\', "/");
    if dir.is_empty() {
        map.set_docs(documented.clone());
        map.book = book.clone();
    }
    map.write_if_changed(&out.join(&dir))?;
    live.insert(dir);
}
for (dir, _) in LpMap::read_all(out) {
    if live.contains(&dir) {
        continue;
    }
    let stale = out.join(&dir).join(MAP_FILE);
    if std::fs::remove_file(&stale).is_ok() {
        crate::status::prune_empty_dirs(stale.parent().unwrap_or(out), out);
    }
}
````)

== Saying what drifted

The drift report is deliberately one line per file: where the first difference is, and which
chunk produced the line on the *document's* side. Anything more is a diff, and a diff is not
what the reader needs — the reader needs the name of the thing to edit.

#chunk("tangle: every name a block references", ````rust
pub fn refs_of(block: &Block) -> Vec<String> {
    let mut names = Vec::new();
    for line in block.text.lines() {
        if let Some((target, _)) = ref_target(line) {
            names.push(target.to_string());
        }
    }
    names
}
````)

#chunk("tangle: where two texts first differ", ````rust
fn first_difference(old: Option<&str>, new: &str) -> Option<usize> {
    let old = old?;
    let old_lines: Vec<&str> = old.lines().collect();
    let new_lines: Vec<&str> = new.lines().collect();
    (0..old_lines.len().max(new_lines.len()))
        .find(|&index| old_lines.get(index) != new_lines.get(index))
        .map(|index| index + 1)
}
````)

#chunk("tangle: the drift report", ````rust
fn drift_report(root: &str, existing: Option<&str>, runs: &[Run], text: &str) -> String {
    match first_difference(existing, text) {
        Some(line) => {
            let origin = runs.iter().rev().find(|run| run.first <= line);
            match origin {
                Some(run) => format!("STALE  {root} (line {line}, in chunk ⟪{}⟫)", run.chunk),
                None => format!("STALE  {root} (line {line})"),
            }
        }
        None => format!("STALE  {root} (file missing)"),
    }
}
````)

== The two predicates, pinned

Two unit tests, and they exist because everything else in this chapter depends on them: what
counts as a reference, and what the escape does. Both are pure functions of a line, which is
why they can be tested here rather than by tangling a document.

#chunk("tangle: the two shapes, pinned", ````rust
#[cfg(test)]
mod tests {
    use super::{escaped_ref, ref_target};

    #[test]
    fn only_a_whole_line_reference_counts() {
        assert_eq!(ref_target("<<body>>"), Some(("body", "")));
        assert_eq!(ref_target("    <<body>>  "), Some(("body", "    ")));
        assert_eq!(ref_target("std::cout << x << std::endl;"), None);
        assert_eq!(ref_target("<<a>><<b>>"), None);
        assert_eq!(ref_target("auto y = <<x>>;"), None);
    }

    #[test]
    fn an_escaped_reference_comes_out_without_the_escape() {
        assert_eq!(escaped_ref("@<<body>>").as_deref(), Some("<<body>>"));
        assert_eq!(escaped_ref("  @<<body>>").as_deref(), Some("  <<body>>"));
        assert_eq!(escaped_ref("<<body>>"), None);
        assert_eq!(escaped_ref("@<<a>><<b>>"), None);
        assert_eq!(escaped_ref("@@<<body>>"), None);
    }
}
````)
== Carrying the book into what it produced

A tree that cannot be read on its own is a build artifact; a tree that carries the document which
produced it is a program with its source of truth beside it. So a document may ask for the copy:

```typst
#tangle-options((book-directory: "book", book-files: ("lp.typ", "README.md", ".gitignore")))
```

Each name is a file, relative to the document, and each one is copied into the output directory under
`book-directory` with the name it had. The list is explicit and not a pattern: it is what the book *is*, it
is what a rendering carries, and a list is something a reader can hold against the directory. The first
version matched globs the way a `.gitignore` matches, walking the source tree to find them — more machinery
than three names deserve, and a package could not have read a pattern anyway, since Typst has no `glob`.

The copy is output like everything else: written only when its bytes differ, part of what `--check`
compares, and accounted for by the ownership check rather than reported as a stray. The directory is the
list, in both directions: a copy the list no longer names is stale, removed by the next tangle and refused
by `--check`. That is the one report a `.lpignore` could not have answered — the file was never unaccounted
for, it was simply old — so the book stops producing it rather than explaining it.

#file("src/embedded.rs", ````rust
<<self: the imports>>

<<self: the book, carried>>

<<self: reading it>>

<<self: proving it>>
````)

#file("src/book.rs", ````rust
<<book: the imports>>

<<book: what the settings ask for>>

<<book: carrying it over>>
````)

#chunk("book: the imports", ````rust
use std::path::{Path, PathBuf};

use lopdf::{Dictionary, Document, Object, Stream};

use crate::diag::LpError;
use crate::map::Book;
````)

#chunk("book: what the settings ask for", ````rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Copy {
    pub from: PathBuf,
    pub to: String,
}

impl Copy {
    pub fn name<'a>(&'a self, directory: &str) -> &'a str {
        self.to
            .strip_prefix(&format!("{}/", directory.trim_end_matches('/')))
            .unwrap_or(&self.to)
    }
}

pub fn plan(settings: &Book, anchor: &Path) -> Result<Vec<Copy>, LpError> {
    let mut copies = Vec::new();
    for name in &settings.files {
        let from = anchor.join(name);
        if !from.is_file() {
            return Err(LpError::plain(format!("book-files: {name} is not a file"))
                .with_help("names are relative to the document, and the book is a list of them"));
        }
        copies.push(Copy {
            from,
            to: format!("{}/{}", settings.directory.trim_end_matches('/'), name),
        });
    }
    copies.sort_by(|a, b| a.to.cmp(&b.to));
    Ok(copies)
}
````)

#chunk("book: carrying it over", ````rust
const SOURCE_ID: &str = "lp-source";

const MARKER: &str = "the book this document declares";

fn pdf_err(page: &Path) -> impl Fn(lopdf::Error) -> LpError + '_ {
    move |err| LpError::plain(format!("{}: {err}", page.display()))
}

pub fn attach(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), LpError> {
    match page.extension().and_then(|ext| ext.to_str()) {
        Some("html") => attach_html(page, directory, copies),
        Some("pdf") => attach_pdf(page, directory, copies),
        _ => Ok(()),
    }
}

fn attach_html(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), LpError> {
    let mut files = serde_json::Map::new();
    for copy in copies {
        let bytes = std::fs::read(&copy.from).map_err(|err| LpError::io(&copy.from, err))?;
        let text = String::from_utf8(bytes).map_err(|_| {
            LpError::plain(format!(
                "{} is not text, so it cannot ride in a page",
                copy.to
            ))
            .with_help("the book is carried as JSON strings; binary files would need an encoding")
        })?;
        files.insert(
            copy.name(directory).to_string(),
            serde_json::Value::String(text),
        );
    }
    let payload = serde_json::json!({ "version": 1, "files": files }).to_string();

    let block = format!(
        "<script type=\"application/json\" id=\"{SOURCE_ID}\" data-lp=\"1\">\n{}\n</script>\n",
        payload.replace('<', "\\u003c")
    );

    let mut html = std::fs::read_to_string(page).map_err(|err| LpError::io(page, err))?;
    match html.rfind("</body>") {
        Some(at) => html.insert_str(at, &block),
        None => html.push_str(&block),
    }
    std::fs::write(page, html).map_err(|err| LpError::io(page, err))
}

fn attach_pdf(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), LpError> {
    let mut document = Document::load(page).map_err(pdf_err(page))?;
    let mut listed = Vec::new();
    for copy in copies {
        let bytes = std::fs::read(&copy.from).map_err(|err| LpError::io(&copy.from, err))?;
        let name = copy.name(directory).to_string();

        let mut file = Dictionary::new();
        file.set("Type", Object::Name(b"EmbeddedFile".to_vec()));
        let stream_id = document.add_object(Stream::new(file, bytes));

        let mut ef = Dictionary::new();
        ef.set("F", Object::Reference(stream_id));
        let mut spec = Dictionary::new();
        spec.set("Type", Object::Name(b"Filespec".to_vec()));
        spec.set("F", Object::string_literal(name.as_str()));
        spec.set("UF", Object::string_literal(name.as_str()));
        spec.set("EF", Object::Dictionary(ef));
        spec.set("Desc", Object::string_literal(MARKER));
        listed.push(Object::string_literal(name.as_str()));
        listed.push(Object::Reference(document.add_object(spec)));
    }

    let mut tree = Dictionary::new();
    tree.set("Names", Object::Array(listed));
    let tree_id = document.add_object(tree);
    let mut names = Dictionary::new();
    names.set("EmbeddedFiles", Object::Reference(tree_id));
    document
        .catalog_mut()
        .map_err(pdf_err(page))?
        .set("Names", Object::Dictionary(names));
    document
        .save(page)
        .map(|_| ())
        .map_err(|err| LpError::io(page, err))
}

pub fn extract(page: &Path, format: &str, out: &Path) -> Result<usize, LpError> {
    match format {
        "html" => extract_html(page, out),
        "pdf" => extract_pdf(page, out),
        other => Err(
            LpError::plain(format!("there is no book to read out of {other}"))
                .with_help("the book rides in an HTML page and in a PDF"),
        ),
    }
}

fn extract_html(page: &Path, out: &Path) -> Result<usize, LpError> {
    let bytes = std::fs::read(page).map_err(|err| LpError::io(page, err))?;
    let html = String::from_utf8(bytes).map_err(|_| {
        LpError::plain(format!(
            "{} is not text, so it is not a page",
            page.display()
        ))
        .with_help("the book rides in an HTML rendering, which is text")
    })?;
    let tag = format!("<script type=\"application/json\" id=\"{SOURCE_ID}\"");
    let open = html.rfind(&tag).ok_or_else(|| {
        LpError::plain(format!(
            "{} carries no book: no {tag}> block",
            page.display()
        ))
        .with_help("only a page this tool wrote carries one")
    })?;
    let body = html[open..]
        .find('>')
        .ok_or_else(|| LpError::plain(format!("{}: the block never opens", page.display())))?
        + open
        + 1;
    let end = html[body..]
        .find("</script>")
        .ok_or_else(|| LpError::plain(format!("{}: the block never closes", page.display())))?
        + body;

    let value: serde_json::Value = serde_json::from_str(&html[body..end]).map_err(|err| {
        LpError::plain(format!(
            "{}: the book is not readable: {err}",
            page.display()
        ))
    })?;
    let files = value
        .get("files")
        .and_then(|files| files.as_object())
        .ok_or_else(|| LpError::plain(format!("{}: the book has no files", page.display())))?;
    for name in files.keys() {
        if name.starts_with('/') || name.split('/').any(|part| part == "..") {
            return Err(LpError::plain(format!(
                "{}: {name} would be written outside the output directory",
                page.display()
            )));
        }
    }

    let mut written = 0;
    for (name, text) in files {
        let text = text
            .as_str()
            .ok_or_else(|| LpError::plain(format!("{name} is not text in this book")))?;
        let path = out.join(name);
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|err| LpError::io(parent, err))?;
        }
        std::fs::write(&path, text).map_err(|err| LpError::io(&path, err))?;
        written += 1;
    }
    Ok(written)
}

fn extract_pdf(page: &Path, out: &Path) -> Result<usize, LpError> {
    let document = Document::load(page).map_err(pdf_err(page))?;
    let mut attached = Vec::new();
    let embedded = document
        .catalog()
        .map_err(pdf_err(page))?
        .get(b"Names")
        .and_then(|names| names.as_dict()?.get(b"EmbeddedFiles")?.as_reference());
    if let Ok(root) = embedded {
        collect_attached(&document, root, &mut attached).map_err(pdf_err(page))?;
    }
    write_names(page, out, attached)
}

fn collect_attached(
    document: &Document,
    node: lopdf::ObjectId,
    out: &mut Vec<(String, Vec<u8>)>,
) -> Result<(), lopdf::Error> {
    let tree = document.get_dictionary(node)?;
    if let Ok(kids) = tree.get(b"Kids") {
        for kid in kids.as_array()? {
            collect_attached(document, kid.as_reference()?, out)?;
        }
    }
    let Ok(entries) = tree.get(b"Names") else {
        return Ok(());
    };
    for pair in entries.as_array()?.chunks(2) {
        let Some(name) = pair.first().and_then(|name| name.as_str().ok()) else {
            continue;
        };
        let Ok(spec) = document.get_dictionary(pair[1].as_reference()?) else {
            continue;
        };
        let marked = spec
            .get(b"Desc")
            .ok()
            .and_then(|value| value.as_str().ok())
            .is_some_and(|value| value == MARKER.as_bytes());
        if !marked {
            continue;
        }
        let stream = spec.get(b"EF")?.as_dict()?.get(b"F")?.as_reference()?;
        let bytes = document
            .get_object(stream)?
            .as_stream()?
            .decompressed_content()?;
        out.push((String::from_utf8_lossy(name).to_string(), bytes));
    }
    Ok(())
}

fn write_names(
    page: &Path,
    out: &Path,
    attached: Vec<(String, Vec<u8>)>,
) -> Result<usize, LpError> {
    for (name, _) in &attached {
        if name.starts_with('/') || name.split('/').any(|part| part == "..") {
            return Err(LpError::plain(format!(
                "{}: {name} would be written outside the output directory",
                page.display()
            )));
        }
    }
    let mut written = 0;
    for (name, bytes) in attached {
        let path = out.join(&name);
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|err| LpError::io(parent, err))?;
        }
        std::fs::write(&path, bytes).map_err(|err| LpError::io(&path, err))?;
        written += 1;
    }
    Ok(written)
}

pub fn sweep(out: &Path, directory: &str, copies: &[Copy], check: bool) -> Result<usize, LpError> {
    let root = out.join(directory.trim_end_matches('/'));
    let listed: Vec<&str> = copies.iter().map(|copy| copy.name(directory)).collect();
    let mut removed = 0;
    let mut parents = Vec::new();
    for (path, relative) in files_under(&root)? {
        if listed.contains(&relative.as_str()) {
            continue;
        }
        if check {
            return Err(LpError::plain(format!(
                "{} is a copy the book no longer names",
                path.display()
            ))
            .with_help(
                "the book is the list in `tangle-options`; `lp tangle` without `--check` removes it",
            ));
        }
        std::fs::remove_file(&path).map_err(|err| LpError::io(&path, err))?;
        removed += 1;
        if let Some(parent) = path.parent() {
            parents.push(parent.to_path_buf());
        }
    }
    parents.sort_by_key(|dir| std::cmp::Reverse(dir.components().count()));
    for parent in parents {
        if parent != root {
            let _ = std::fs::remove_dir(&parent);
        }
    }
    Ok(removed)
}

fn files_under(root: &Path) -> Result<Vec<(PathBuf, String)>, LpError> {
    let mut found = Vec::new();
    let mut stack = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path
                .components()
                .any(|part| part.as_os_str() == crate::metadata::PACKAGE_ROOT)
            {
                continue;
            }
            if path.is_dir() {
                stack.push(path);
                continue;
            }
            let relative = path
                .strip_prefix(root)
                .unwrap_or(&path)
                .to_string_lossy()
                .replace('\\', "/");
            found.push((path, relative));
        }
    }
    Ok(found)
}

pub fn place(out: &Path, copies: &[Copy], check: bool) -> Result<usize, LpError> {
    let mut written = 0;
    for copy in copies {
        let path = out.join(&copy.to);
        let bytes = std::fs::read(&copy.from).map_err(|err| LpError::io(&copy.from, err))?;
        if std::fs::read(&path).ok().as_deref() == Some(bytes.as_slice()) {
            continue;
        }
        if check {
            return Err(LpError::plain(format!("{} is out of date", path.display()))
                .with_help("run `lp tangle` without `--check` to carry the book again"));
        }
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|err| LpError::io(parent, err))?;
        }
        std::fs::write(&path, &bytes).map_err(|err| LpError::io(&path, err))?;
        written += 1;
    }
    Ok(written)
}
````)

== What the binary carries

A tool that can only work inside its own repository is not finished. This one carries three things: the
program (it is the program), the package it declares chunks with, and — through the settings further on —
the book that produced the tree it was built from. `include_dir!` puts that directory in the binary at
compile time, so `lp self` needs nothing beside it.

*Three subcommands, three things it can do with what it carries:*

- `lp self book --out <dir>` writes the book out, entire: the document, the pointer, the ignore rules.
- `lp self read --format (pdf|html)` weaves the document *it carries* into a temporary directory and hands
  the result to the desktop. Weaving reuses `lp weave`, because there is one way to render a document and
  it should not be written twice; opening is best effort — a machine with no desktop still gets the file
  and its path. Either rendering carries the book with it — the block in a page, the attached files in a
  PDF — so what opens is something that can give its own source back.
- `lp self prove <dir>` unpacks that book into `<dir>`, tangles it with *this* binary, and runs the
  tree's own checks in it: the whole bootstrap in one command, with nothing outside the binary but the
  toolchain it borrows. The lock file is part of the book, so nix is asked not to resolve one — writing
  one there would be drift.

*And what it still needs, which is the other half of the same sentence:*

- `lp self book` needs nothing. The book is bytes in the binary.
- `lp self read` needs Typst: rendering is not this tool's work, so it borrows the compiler.
- `lp self prove` needs Typst and nix, and the second one is the point rather than an accident. The tree
  checks *itself* — `nix flake check` is the tree's own decision about itself, and it now renders this
  document and reads the book back out of both carriers, so the round trip is a condition of the package
  existing at all. A tool that ran those checks by hand would be claiming a guarantee it did not have.

`include_dir` is the one dependency this adds, and the line D7 asks for: embedding a directory tree is
`include_bytes!` at scale — one macro, no runtime dependency, and `Dir::extract` writes the tree back out
in a single call. It also embeds in *every* profile, which matters more than it sounds: a crate that reads
from the file system in debug builds would make the test below pass without embedding anything.

#chunk("self: the imports", ````rust
use std::path::{Path, PathBuf};
use std::process::Command;

use include_dir::{Dir, include_dir};

use crate::diag::LpError;

static BOOK: Dir = include_dir!("$CARGO_MANIFEST_DIR/book");
````)

#chunk("self: the book, carried", ````rust
pub fn book(out: &Path) -> Result<usize, LpError> {
    std::fs::create_dir_all(out).map_err(|err| LpError::io(out, err))?;
    BOOK.extract(out).map_err(|err| {
        LpError::plain(format!(
            "cannot write the book into {}: {err}",
            out.display()
        ))
    })?;
    Ok(BOOK.files().count())
}
````)

#chunk("self: proving it", ````rust
pub fn prove(dir: &Path) -> Result<i32, LpError> {
    let files = book(dir)?;

    let mut documents: Vec<PathBuf> = Vec::new();
    let entries = std::fs::read_dir(dir).map_err(|err| LpError::io(dir, err))?;
    for entry in entries {
        let path = entry.map_err(|err| LpError::io(dir, err))?.path();
        if path.extension().is_some_and(|kind| kind == "typ") {
            documents.push(path);
        }
    }
    if documents.len() != 1 {
        return Err(LpError::plain(format!(
            "the book carries {} .typ documents, not one",
            documents.len()
        ))
        .with_help("`lp self prove` expects the book to be a single document"));
    }

    let tree = dir.join("tangled");
    println!("wrote {files} files of the book to {}", dir.display());
    crate::tangle::run(&documents, &tree, false)?;

    let status = Command::new("nix")
        .args(["flake", "check", "--no-update-lock-file"])
        .current_dir(&tree)
        .status()
        .map_err(|err| LpError::plain(format!("cannot run nix: {err}")))?;
    Ok(status.code().unwrap_or(1))
}
````)

#chunk("self: reading it", ````rust
pub fn read(format: &str) -> Result<PathBuf, LpError> {
    let (name, flags): (&str, &[&str]) = match format {
        "pdf" => ("lp.pdf", &[]),
        "html" => ("lp.html", &["--features", "html"]),
        other => {
            return Err(LpError::plain(format!("unknown format {other:?}"))
                .with_help("`lp self read --format pdf`, or `--format html`"));
        }
    };

    let dir = std::env::temp_dir().join(format!("lp-self-{}", std::process::id()));
    std::fs::create_dir_all(&dir).map_err(|err| LpError::io(&dir, err))?;
    book(&dir)?;

    let document = dir.join("lp.typ");
    let output = dir.join(name);
    let flags: Vec<String> = flags.iter().map(|flag| flag.to_string()).collect();
    let status = crate::weave::run(&document, Some(&output), &flags)?;
    if status != 0 {
        return Err(LpError::plain(format!(
            "weaving {} failed with status {status}",
            document.display()
        )));
    }

    let _ = Command::new("xdg-open").arg(&output).spawn();
    Ok(output)
}
````)

= Weaving the document

Tangling writes the program; weaving renders the document you are reading. The second is Typst's job,
and it is already done — `typst compile` renders a document. A second renderer inside this tool would be
a second thing to keep in step with the compiler, which is the kind of duplication this document keeps
refusing.

What the tool does have, and a writer should not have to remember, is where the package went. The
document imports `@local/lp:0.1.0`, and Typst resolves that through a package path: the directory the
tangle unpacked next to the document. `lp weave` is `typst compile` with that path filled in, a root
that covers the document, and every other argument passed through untouched:

```sh
lp weave lp.typ lp.pdf                          # the book, as Typst renders it
lp weave report.typ report.pdf --input who=me   # ... with Typst's own flags
```

Typst's experimental exports arrive the same way, as flags: `lp weave lp.typ lp.html --features html`
writes an HTML rendering, and Typst warns while doing it that the format is still under development. That
the tool has no list of which flags are allowed is the point of the trailing arguments.

An HTML rendering also carries the book the document declares — the files `lp tangle` copies beside the
tree — as a *data block*: a `<script>` whose type is not JavaScript is data, not code, so the page stays a
valid page and a browser that ignores the block has lost nothing. The payload is the book as JSON, keyed by
the names the tree uses, with a version inside, because a format that cannot say which format it is cannot
be improved. `lp extract --format html|pdf <file> --out <dir>` is the inverse: it finds the book — the block in a page,
the attached files in a PDF — and writes it into `<dir>` under the book's own names, the same names
`lp self book` writes, because where the *tree* puts a book is a placement, not a property of the book.

What marks the block is the whole opening tag, not the text of the id. This document says "lp-source" in
prose — here, in this paragraph — and the first version, which searched for the id as a substring, found
this sentence instead and failed on it. A marker has to be something a page cannot mention by accident.

A PDF rendering carries the book as well, and there the carrying is the tool's work too, for reasons that
took a wrong turn each to find. The tempting shape was to let the package attach its own book: `pdf.attach`
is one line and Typst does the rest. It cannot. A package cannot name the document's files, because Typst
resolves a path relative to the file the call is written in — so `lp.typ` inside a package means the
package's own directory, and there is no way to ask for the document's — and it cannot expand a pattern
either, because Typst has no `glob`. An HTML page is the other way round: the package *can* read the whole
book, and cannot place a marked block, because its HTML export takes no attributes and the marker is an
attribute. So both carriers are written by the tool, on the file the compiler has just left behind, where
what to do with a rendering is at least ours to decide.

Neither format is guessed. `extract` demands `--format` because a wrong guess would produce silence rather
than an error, and each carrier is read back by what wrote it: the block by the same text handling, and the
attached files by the mobile PDF library that wrote them.

The package is the copy embedded in this binary, unpacked fresh, so weaving needs no tangle before it:
the document is the source of both. And the document stays a normal Typst file — an editor rendering it
without the tool sets `TYPST_PACKAGE_PATH` itself, to the same path this command passes: `.lp/packages`
under the documents' directory. That path is the whole editor story, and it works because nothing about it
is ours to invent: the layout below is `namespace/name/version`, which is what every Typst package looks
like, and the namespace is `local`, which is the one Typst recommends for a package that is not published.
A language server that follows Typst's conventions therefore needs that one variable and no configuration
of its own. An editor willing to touch the machine instead can link the same directory into Typst's data
directory, and then no project needs the variable at all.

#file("src/weave.rs", ````rust
<<weave: the imports>>

<<weave: the command>>

<<weave: the status>>
````)

== What the tool has to say, and what it does not

Two facts, and both are things the tool already knows from tangling:

- the package path, because it unpacked the package itself;
- a root that covers the document *and* the working directory, because Typst refuses to read outside
  its root and an import that resolves through a relative path has to stay inside it.

Everything else is Typst's, and is passed on as it came. That is why the arguments are trailing: after
the document and the output, nothing is ours to interpret.

#chunk("weave: the imports", ````rust
use std::path::Path;
use std::process::Command;

use crate::diag::LpError;
use crate::metadata::{binary, common_ancestor, unpack_package};
````)

#chunk("weave: the command", ````rust
pub fn run(doc: &Path, output: Option<&Path>, extra: &[String]) -> Result<i32, LpError> {
    let typst = binary()?;
    let cwd = std::env::current_dir()
        .map_err(|err| LpError::plain(format!("cannot read the working directory: {err}")))?;
    let anchor = doc.canonicalize().map_err(|err| LpError::io(doc, err))?;
    let docs = vec![anchor.clone()];
    let packages = unpack_package(&common_ancestor(&docs))?;
    let mut root = docs;
    root.push(cwd);

    let mut command = Command::new(typst);
    command
        .arg("compile")
        .arg(doc)
        .arg("--root")
        .arg(common_ancestor(&root))
        .arg("--package-path")
        .arg(&packages);
    if let Some(output) = output {
        command.arg(output);
    }
    command.args(extra);
````)

#chunk("weave: the status", ````rust
    let status = command
        .status()
        .map_err(|err| LpError::plain(format!("cannot run Typst: {err}")))?;
    if status.success() {
        carry_the_book(&anchor, output)?;
    }
    Ok(status.code().unwrap_or(1))
}

fn carry_the_book(anchor: &Path, output: Option<&Path>) -> Result<(), LpError> {
    let Some(page) = output.filter(|out| {
        out.extension()
            .is_some_and(|ext| ext == "html" || ext == "pdf")
    }) else {
        return Ok(());
    };
    let Some(directory) = anchor.parent() else {
        return Ok(());
    };
    let docs = vec![anchor.to_path_buf()];
    let Some(book) = crate::tangle::declared_book(&docs)? else {
        return Ok(());
    };
    let copies = crate::book::plan(&book, directory)?;
    crate::book::attach(page, &book.directory, &copies)
}
````)

= Reading a diagnostic back to the declaration

The compiler knows nothing about this document. It knows `src/main.rs`, and it will report
`src/main.rs:6:38: cannot find function 'ad' in module 'math'` for a line that exists here
only as part of a chunk. The question that follows is the one this chapter answers: which
declaration do I edit?

The tempting answer is to make the compiler say it — inject `#line` directives, or
whatever the target language uses, so the toolchain's own positions point into this
document. That was rejected, and not on taste. The generated file has to stay
byte-for-byte what a person would have written, or `--check` can no longer compare it and
every language needs a special case for a directive it may not even have; and the
positions we could inject would be `.typ` line numbers, which do not exist, because Typst
does not expose them (ADR D14, with the measurements behind it).

So the mapping is built on the side, while tangling: every generated line is recorded
together with the declaration it came from. What is left for `lp explain` is a filter with
no opinion about any language at all — it echoes what it reads, and for each line shaped
like `file:line:col:` it adds one note about where that line came from.

== The shape of the filter

Every line of this file is a name; the details come in the sections after it.

#file("src/explain.rs", ````rust
<<explain: the imports>>

pub fn run(out: &Path, input: &str) -> Result<usize, LpError> {
    <<the diagnostic pattern>>

    let maps = LpMap::read_all(out);
    let mut mapped = 0;

    for line in input.lines() {
        println!("{line}");

        <<one line, annotated>>
    }

    Ok(mapped)
}
````)

The count it returns is not decoration: the caller uses it to warn that no diagnostic line
matched anything, which is the difference between "the build is clean" and "the filter
never recognised a single line".

== A note in the file, and the reason here

Someone who opens the generated `src/explain.rs` should be able to orient themselves
without this document, so the file keeps a short note. It is orientation only: the
reasoning is this chapter's job. That split is deliberate — a comment inside a generated
file is a pointer, and a pointer does not drift, while a second copy of the argument
would.

== What the filter needs

The regex engine, the path type, this crate's error type, and the map reader with its two
helpers. `resolve_all` is the interesting one: a diagnostic names a file, and the set of
directory maps that could explain it is searched rather than guessed (`map.rs`, next).

#chunk("explain: the imports", ````rust
use std::path::Path;

use regex::Regex;

use crate::diag::LpError;
use crate::map::{LpMap, join, resolve_all};
````)

== One pattern, and it is not language knowledge

The pattern recognises a shape that compilers and linters have printed for decades:
`path:line:column:` followed by a message. That is deliberately the whole of this
program's idea of a diagnostic. A toolchain that prints something else — a Python
traceback, or cargo's JSON — wants another pattern beside this one, not another
algorithm (ADR D5).

#chunk("the diagnostic pattern", ````rust
let pattern = Regex::new(r"^(?P<file>[^\s:]+\.\w+):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
    .map_err(|err| LpError::plain(format!("internal: bad diagnostic pattern: {err}")))?;
````)

== Give up quietly, or say where the line came from

Three chances to give up quietly: the line is not a diagnostic, no map knows that file, or
the map does not cover that line. When the line *can* be placed, note which stream carries
which half: the input is echoed unchanged on stdout, so the filter can sit in the middle of
a pipeline, and the note goes to stderr, where nothing will mistake it for compiler
output.

#chunk("one line, annotated", ````rust
let Some(caps) = pattern.captures(line) else {
    continue;
};
let (file, out_line) = (&caps["file"], caps["line"].parse::<usize>().unwrap_or(0));
let Ok((dir, name, entry)) = resolve_all(&maps, file) else {
    continue;
};
let Some((run, offset)) = entry.locate(out_line) else {
    continue;
};
let rel = join(dir, name);
eprintln!(
    "  ↳ chunk ⟪{}⟫, line {offset} of it  ({rel}:{out_line})",
    run.chunk
);
mapped += 1;
````)

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
by an older `lp`, and reading one has to be able to say "not mine" instead of guessing.

== The shape of the record

The names in the skeleton carry a file prefix, `map:`, for a reason worth knowing early:
chunk names are global to the whole document. Two chapters that both called a fragment
`the module note` would concatenate their bodies into whichever file referenced that name
— which is how this chapter was first written, and how it announced the mistake.

#file("src/map.rs", ````rust
<<map: the imports>>

<<map: the two constants>>

<<map: what a map holds>>

<<map: a fresh map>>

impl LpMap {
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

use crate::diag::LpError;
````)

== Two names the rest of the program shares

The file name is a constant because three other places care about it: this module writes
it, the ownership check in `status.rs` exempts it, and `explain.rs` walks the tree looking
for exactly this name. The version is a constant for the same reason — it is a fact about
the format, and facts about the format belong in one place.

#chunk("map: the two constants", ````rust
pub const MAP_FILE: &str = ".lpmap.json";
const VERSION: u32 = 6;
````)

== What a map holds

Three structures, all serde-shaped, because the file's format is the interface: a map, the
entry for one file, and one run of lines.

#chunk("map: what a map holds", ````rust
#[derive(Debug, Serialize, Deserialize)]
pub struct LpMap {
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
impl Default for LpMap {
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
pub fn write_if_changed(&self, dir: &Path) -> Result<bool, LpError> {
    let (path, json) = self.serialize(dir)?;
    if std::fs::read_to_string(&path).ok().as_deref() == Some(json.as_str()) {
        return Ok(false);
    }
    std::fs::write(&path, json).map_err(|err| LpError::io(&path, err))?;
    Ok(true)
}
````)

#chunk("map: read one map", ````rust
pub fn read(dir: &Path) -> Result<Self, LpError> {
    let path = dir.join(MAP_FILE);
    let text = std::fs::read_to_string(&path).map_err(|err| LpError::io(&path, err))?;
    serde_json::from_str(&text)
        .map_err(|err| LpError::plain(format!("{}: {err}", path.display())))
}
````)

The search is two fragments rather than one: the guard for an output directory that does not exist yet, and
the walk. The split used to be forced by the blank line between the two thoughts, because a fragment that
carried one added its indentation to it; the line writer leaves a blank line blank now, so this is a choice
about what each fragment is about rather than a workaround.

#chunk("map: when there is no output directory", ````rust
pub fn read_all(out: &Path) -> Vec<(String, LpMap)> {
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
fn serialize(&self, dir: &Path) -> Result<(PathBuf, String), LpError> {
    let path = dir.join(MAP_FILE);
    let json = serde_json::to_string_pretty(self)
        .map_err(|err| LpError::plain(format!("{}: {err}", path.display())))?;
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
        return Err(LpError::plain(format!("{file}: no map knows this file"))
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
            LpError::plain(format!("{file}: which map?")).with_help(format!("candidates: {all}"))
        );
    }
    Ok(*best)
}
````)
= Who owns the output directory

Tangling writes into a directory that already holds things it did not write: a compiler's
build directory, a lock file, the PDF the weave produced, notes the user keeps there. A
tool that deleted or overwrote by guessing would be worse than useless in that position, so
this part of `lp` is a rule instead of a heuristic — and it is the reason `--check` can be
trusted.

== The rule

Point `--out` at a directory and that whole directory is `lp`'s, at any depth. Every file
under it falls into exactly one of three groups: produced by a `#file` declaration,
declared in the `.lpignore` of its directory, or neither. The third group is the only one
worth reporting, and it is reported as an error that names every entry.

Two halves of that rule are easy to get backwards, so they are worth saying plainly. The
declaration file is a list of what `lp` does *not* manage: matching means the file is
protected, which is the opposite of what the word "ignore" suggests. And `lp` never deletes
as a side effect of a pass — stale output is either declared, or removed by an explicit
`lp unaccounted --delete`.

Why report at all, rather than tidy up? Because the answer is unknowable from the inside. A
file that no chunk produces may be one a chunk *should* produce, a file the user put there,
or the output of a chunk that was deleted; only the user can tell which. So the tool lists
what it finds and stops.

== The shape of that rule

#file("src/status.rs", ````rust
<<status: the imports>>

<<status: the file that says what lp does not manage>>

<<status: what a directory of strays looks like>>

pub fn unaccounted(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<Unaccounted>, LpError> {
    <<status: nothing to report>>

    <<status: ask the walker>>

    <<status: what survives the walk>>

    <<status: group them by directory>>
    <<status: sorted, and stable>>
}

<<status: what the tool writes is not content>>

<<status: when a subtree is too big to list>>

<<status: compressing a subtree>>

<<status: finding the subdirectories>>

<<status: delete, on request>>

<<status: cleaning up directories that emptied>>

pub fn run(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
    delete_unaccounted: bool,
) -> Result<i32, LpError> {
    <<status: nothing was declared>>

    <<status: everything is accounted for>>

    <<status: delete, when that is what was asked>>

    <<status: list them, and say what to do>>
}

<<status: the rules, pinned by four cases>>
````)

== Three groups, and the file's own opening

The module note states the model in the file itself, which is where a reader who opens
`src/status.rs` needs it; the rest of this chapter is why each piece is shaped that way.

#chunk("status: the imports", ````rust
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use ignore::WalkBuilder;

use crate::diag::LpError;
use crate::map::{MAP_FILE, relative};
````)

== One name is the contract

A constant, because the name is part of the interface: a directory declares what `lp` does
not manage in exactly this file, and the walker below is told to look for this name instead
of git's default.

#chunk("status: the file that says what lp does not manage", ````rust
pub const IGNORE_FILE: &str = ".lpignore";
````)

== What a directory of strays looks like

The report is grouped by directory, because the fix is per directory: each group is one
directory and the entries nothing accounts for inside it. An entry that ends in a slash
means a whole subtree was compressed into one line — which is why entries are strings and
not paths.

#chunk("status: what a directory of strays looks like", ````rust
#[derive(Debug)]
pub struct Unaccounted {
    pub dir: String,
    pub entries: Vec<String>,
}
````)

== Walking the tree, and what survives it

The walk and the filter are separate fragments because they answer different questions: what is
under the output directory, and which of those files nothing accounts for.

#chunk("status: nothing to report", ````rust
if produced.is_empty() || !out.exists() {
    return Ok(Vec::new());
}
````)

#chunk("status: ask the walker", ````rust
let mut builder = WalkBuilder::new(out);
builder
    .standard_filters(false)
    .hidden(false)
    .parents(false)
    .add_custom_ignore_filename(IGNORE_FILE);
````)

The walker is the crate git itself uses, with its default filters switched off — this is not
a git question — and `.lpignore` registered as *the* ignore file name. That choice is the
whole reason there is no second implementation of ignore rules here: nesting, deepest-wins,
whitelists and the `!` operator are the library's job, and a directory that declares
something is simply never visited.

#chunk("status: what survives the walk", ````rust
let mut files: BTreeSet<String> = BTreeSet::new();
for entry in builder.build() {
    let entry =
        entry.map_err(|err| LpError::plain(format!("cannot scan {}: {err}", out.display())))?;
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
````)

#chunk("status: group them by directory", ````rust
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
````)

#chunk("status: sorted, and stable", ````rust
Ok(found
    .into_iter()
    .map(|(dir, mut entries)| {
        entries.sort();
        Unaccounted { dir, entries }
    })
    .collect())
````)

== What the tool itself writes

Three names, and only two of them are the tool's. The map records which declaration produced
each line; the directory the package is unpacked into holds two of the document's own `#file`
declarations in the form Typst wants to read them. Both are written by a pass of this program
under names nothing else uses, so both are accounted for by name: a map left behind in a
directory that stopped producing anything is that pass's to delete, and the package beside a
book is unpacked again every time the book is woven. Making a project declare its own tool's
scratch would be asking it to describe `lp` to `lp`.

The ignore file is not one of these. It is a *decision* — which files under the output
directory belong to somebody else — and a decision is either declared by the document, like any
other file, or written by a person, who then says so inside it. Exempting it by name is how a
`.lpignore` whose declaration went away stayed in the tree for good: nothing produced it,
nothing matched it, and nothing removed it, because the report had never seen it.

#chunk("status: what the tool writes is not content", ````rust
fn is_own_output(path: &Path) -> bool {
    path.file_name().is_some_and(|name| name == MAP_FILE)
}
````)

== A build directory is one line

One constant, and its value is a judgement: eight entries is where a list stops being readable
and naming the directory starts being more useful.

#chunk("status: when a subtree is too big to list", ````rust
const COMPRESS_ABOVE: usize = 8;
````)

#chunk("status: compressing a subtree", ````rust
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
````)

The threshold is applied at the directory that actually overflows, and never to the output
directory itself: reporting `./` as one entry would tell the user nothing at all about
where to look.

#chunk("status: finding the subdirectories", ````rust
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
````)

== Removing, when the user asks for it

The only code in the program that removes anything, and the walk that tidies up the directories
it leaves empty behind it.

#chunk("status: delete, on request", ````rust
pub fn delete(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<String>, LpError> {
    let mut removed = Vec::new();
    for group in unaccounted(out, produced)? {
        for entry in group.entries {
            let whole_directory = entry.ends_with('/');
            let name = entry.trim_end_matches('/');
            let relative = crate::map::join(&group.dir, name);
            let path = out.join(&relative);
            if whole_directory {
                std::fs::remove_dir_all(&path).map_err(|err| LpError::io(&path, err))?;
            } else {
                std::fs::remove_file(&path).map_err(|err| LpError::io(&path, err))?;
            }
            prune_empty_dirs(path.parent().unwrap_or(out), out);
            removed.push(relative);
        }
    }
    Ok(removed)
}
````)

#chunk("status: cleaning up directories that emptied", ````rust
pub fn prune_empty_dirs(start: &Path, stop: &Path) {
    let mut dir = Some(start);
    while let Some(current) = dir {
        if current == stop || !current.starts_with(stop) {
            break;
        }
        let empty = std::fs::read_dir(current).is_ok_and(|mut entries| entries.next().is_none());
        if !empty || std::fs::remove_dir(current).is_err() {
            break;
        }
        dir = current.parent();
    }
}
````)

The upward walk stops at the output directory — never above it, and never removing the
output directory itself, which is the one thing a pass is allowed to consider its own
without asking.

== The report a person or a script reads

Four exits, one of them an error. Two of the four are a run that found nothing to complain
about, and saying so is not noise: the sentence is what makes silence from `--check`
meaningful, and the count of produced files is what makes it checkable at a glance.

#chunk("status: nothing was declared", ````rust
if produced.is_empty() {
    println!(
        "{}: the document declares no files, so lp writes nothing here and owns nothing",
        out.display()
    );
    return Ok(0);
}
````)

#chunk("status: everything is accounted for", ````rust
let unaccounted = unaccounted(out, produced)?;
if unaccounted.is_empty() {
    let accounted: usize = produced.values().map(BTreeSet::len).sum();
    println!(
        "{}: every file under the output directory is accounted for ({accounted} produced by chunks, the rest declared)",
        out.display()
    );
    return Ok(0);
}
````)

#chunk("status: delete, when that is what was asked", ````rust
if delete_unaccounted {
    for relative in delete(out, produced)? {
        println!("deleted {relative}");
    }
    return Ok(0);
}
````)

#chunk("status: list them, and say what to do", ````rust
for group in &unaccounted {
    let label = if group.dir.is_empty() {
        "."
    } else {
        group.dir.as_str()
    };
    println!("{label}/ — {} nothing accounts for:", group.entries.len());
    for entry in &group.entries {
        println!("  {}", crate::map::join(&group.dir, entry));
    }
}
println!();
println!(
    "Everything else under there is either produced by a chunk or declared in a .lpignore."
);
println!(
    "Each line above is one of: something a chunk should produce, something to declare in"
);
println!("that directory's .lpignore, or stale output to delete.");
println!("Nothing is removed on its own: declare it, or run `lp unaccounted --delete`.");
Ok(1)
````)

The exit status is 1 for the listing, so a caller — a CI step, a script, an agent — can tell
that case from a clean run without reading the text, and 0 for the two quiet outcomes and
for a deletion that succeeded.

== The rules, pinned in the file

Five unit tests, in the file they test rather than in `tests/`, because they are about one
function and need no binary: produced files are accounted for however deep they are,
declared files are accounted for even in a nested directory, a subtree that overflows is
named once at the directory that overflows, everything under the output directory is ours at
any depth — and nothing is accounted for by its name, so a `.lpignore` that neither the
document declared nor a rule protects is a stray, while the two names the tool writes are not.

#chunk("status: the rules, pinned by four cases", ````rust
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
        write(&out.join(".lpignore"), "declared.txt\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("declared.txt"), "mine, not lp's");
        write(&out.join("stray.txt"), "who put this here");
        write(&out.join("stray-dir/inside.txt"), "and this");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt", ".lpignore"])]
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
        write(&out.join(".lpignore"), "**/*.log\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("deep/nested/app.log"), "declared");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt", ".lpignore"])]
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
        write(&out.join(".lpignore"), "theirs.txt\n");
        write(&out.join("theirs.txt"), "protected");
        write(
            &out.join(".lp/packages/local/lp/0.1.0/lib.typ"),
            "the package",
        );
        write(&out.join("src/.lpmap.json"), "the map");

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
            vec![".lpignore".to_string()],
            "the ignore file is reported; the tool's own two names are not"
        );
    }
}
````)
= Keeping the files in step while the document is edited

`lp watch` is what makes the document usable as a source: save, and the generated files
follow. It is possible at all because of a property of the design that has been measured —
expanding a two-thousand-line document takes about a millisecond — and it exists because of a
failure that is easy to underestimate: a tool that rebuilds the world on every keystroke
teaches its user to stop saving, and that is the end of the loop the whole thing depends on.

Three properties matter more than speed, and they are the three the file states in its own
note. Only real changes are written, so a file that did not change keeps its mtime and cargo
and rust-analyzer stay asleep. A half-written document is not tangled: a syntax error is
printed and the pass is skipped, which leaves the last good output in place while the editor
is mid-keystroke. And editor events are coalesced — a debouncer plus draining the events our
own writes produced — so a burst of edits is one pass.

The cost is recorded in the file rather than hidden: every pass re-reads and re-evaluates the
whole document and re-expands every root. That is a deliberate ceiling, with the measurement
next to it, and the note says what would have to change if a book-sized document ever makes it
hurt.

== The shape of the file

#file("src/watch.rs", ````rust
<<watch: the imports>>

<<watch: what the command line passes in>>

pub fn run(options: Options) -> Result<(), LpError> {
    <<watch: one debouncer, one channel>>

    <<watch: the directories, not the files>>

    <<watch: say what is being watched>>

    <<watch: pass once, then wait>>
    Ok(())
}

fn pass(options: &Options, initial: bool, events: &mpsc::Receiver<()>) -> bool {
    let started = Instant::now();

    <<watch: the events our own writes caused>>

    <<watch: one pass, through tangle>>

    <<watch: the warnings, and how long it took>>

    <<watch: nothing to do>>

    <<watch: say what happened, then check>>
    true
}

fn check(options: &Options) {
    <<watch: no check command, no check>>

    <<watch: run the command, whatever it is>>

    <<watch: its output, both streams>>

    <<watch: the same translation as lp explain>>
}

<<watch: the last resort>>
````)

== What the command line passes in

The watched documents, the output directory, the debounce window, and an optional command to
run after a pass that changed something. Nothing here knows about `lp` itself; this is the
part of the program that touches the outside world.

#chunk("watch: the imports", ````rust
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::time::{Duration, Instant};

use notify_debouncer_full::notify::RecursiveMode;
use notify_debouncer_full::{DebounceEventResult, new_debouncer};

use crate::diag::LpError;
use crate::tangle;
````)

#chunk("watch: what the command line passes in", ````rust
pub struct Options {
    pub docs: Vec<PathBuf>,
    pub out: PathBuf,
    pub debounce: Duration,
    pub check_cmd: Option<String>,
}
````)

== Starting up, and what to watch

Three fragments: the debouncer and its channel, the directories to watch, and the line that says
what is being watched.

#chunk("watch: one debouncer, one channel", ````rust
let (tx, rx) = mpsc::channel();
let mut debouncer = new_debouncer(
    options.debounce,
    None,
    move |result: DebounceEventResult| {
        if result.is_ok() {
            let _ = tx.send(());
        }
    },
)
.map_err(|err| LpError::plain(format!("cannot start the file watcher: {err}")))?;
````)

#chunk("watch: the directories, not the files", ````rust
let mut watched: Vec<PathBuf> = Vec::new();
for doc in &options.docs {
    let dir = doc
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."))
        .to_path_buf();
    if watched.contains(&dir) {
        continue;
    }
    debouncer
        .watch(&dir, RecursiveMode::NonRecursive)
        .map_err(|err| LpError::plain(format!("cannot watch {}: {err}", dir.display())))?;
    watched.push(dir);
}
````)

The directories are watched rather than the files, and that is not a detail: editors save by
writing a temporary file and renaming it over the target, which silently kills a watch on the
file itself. Watching the directory is also why the first pass matters — the loop has to be
correct *before* the first event arrives, since the document may already be out of step.

#chunk("watch: say what is being watched", ````rust
eprintln!(
    "watching {} -> {}",
    options
        .docs
        .iter()
        .map(|doc| doc.display().to_string())
        .collect::<Vec<_>>()
        .join(", "),
    options.out.display()
);
````)

#chunk("watch: pass once, then wait", ````rust
pass(&options, true, &rx);
while rx.recv().is_ok() {
    pass(&options, false, &rx);
}
````)

== One pass

A pass is four decisions in a row: drop the events our own writes caused, tangle, decide what to
report, and run the check command only if something actually moved.

#chunk("watch: the events our own writes caused", ````rust
while events.try_recv().is_ok() {}
````)

The drain is the part that is easy to miss: a pass writes files, the watcher sees those
writes, and without emptying the queue first every pass would trigger one more. This is also
where the design's honesty shows: the tool's own output is nobody's edit.

#chunk("watch: one pass, through tangle", ````rust
let outcome = match tangle::run(&options.docs, &options.out, false) {
    Ok(outcome) => outcome,
    Err(err) => {
        report(err);
        return false;
    }
};
````)

A failed pass does not end the loop — the error is printed and the pass returns without
writing anything, which is the half-written document case. The alternative, exiting, would
turn a moment of typing into a dead process.

#chunk("watch: the warnings, and how long it took", ````rust
for warning in &outcome.warnings {
    eprintln!("warning: {warning}");
}
let ms = started.elapsed().as_secs_f64() * 1000.0;
let dormant = outcome.changed.is_empty();
````)

#chunk("watch: nothing to do", ````rust
if dormant {
    if initial {
        eprintln!(
            "sync   up to date ({} files, {ms:.1}ms)",
            outcome.unchanged.len()
        );
    }
    return false;
}
````)

#chunk("watch: say what happened, then check", ````rust
eprintln!(
    "sync   {} rewritten, {} untouched ({ms:.1}ms): {}",
    outcome.changed.len(),
    outcome.unchanged.len(),
    outcome
        .changed
        .iter()
        .map(|output| output.root.as_str())
        .collect::<Vec<_>>()
        .join(", ")
);
if !dormant {
    check(options);
}
````)

== The check command

Running the check only when something was rewritten is the fusion that makes `--check-cmd`
worth having: a compiler invoked on every save would spend the user's morning rebuilding
nothing, and a warning printed on every save is a warning nobody reads.

#chunk("watch: no check command, no check", ````rust
let Some(command) = &options.check_cmd else {
    return;
};
````)

#chunk("watch: run the command, whatever it is", ````rust
let output = match std::process::Command::new("sh")
    .arg("-c")
    .arg(command)
    .output()
{
    Ok(output) => output,
    Err(err) => {
        eprintln!("check  cannot run {command:?}: {err}");
        return;
    }
};
````)

#chunk("watch: its output, both streams", ````rust
let text = format!(
    "{}{}",
    String::from_utf8_lossy(&output.stdout),
    String::from_utf8_lossy(&output.stderr)
);
````)

Both streams, because compilers are not consistent about which one carries the diagnostic —
cargo writes errors to stderr and notes to stdout, and a filter that reads one of them is
wrong half the time.

#chunk("watch: the same translation as lp explain", ````rust
let _ = crate::explain::run(&options.out, &text);
````)

== The last resort

Three lines, and the point of them is that they are not a special case: printing an error with
the renderer installed in `main` and staying alive is what a watcher has to do with every failure
that is not the user's syntax error.

#chunk("watch: the last resort", ````rust
fn report(err: LpError) {
    eprintln!("{:?}", miette::Report::new(err));
}
````)
= The command line, and what each command is for

This is the file that turns the library into a program. It has two jobs and no third:
describe the surface, so that `lp --help` is the contract and clap writes it; and translate a
command into calls on the modules the earlier chapters described, printing what happened and
choosing an exit status.

Nothing here decides anything about tangling, mapping or ownership. That is the point — the
surface is a table, and the table is small enough to read in one sitting, which is how a
reader finds out what the tool can do without reading the tool.

== The shape of the file

#file("src/main.rs", ````rust
<<main: self, what it can do>>

<<main: the modules, and what they are called>>

<<main: the surface, as clap sees it>>

#[derive(Subcommand)]
enum Command {
    <<main: weave>>
    <<main: extract>>
    <<main: self>>
    <<main: tangle>>
    <<main: map>>
    <<main: explain>>
    <<main: watch>>
    <<main: list>>
    <<main: metadata>>
    <<main: unaccounted>>
}

fn main() {
    <<main: how an error is printed>>
    <<main: the exit status>>
}

fn out_dir(given: Option<PathBuf>, docs: &[PathBuf]) -> PathBuf {
    if let Some(path) = given {
        return path;
    }
    match docs.first().and_then(|doc| doc.parent()) {
        Some(dir) if !dir.as_os_str().is_empty() => dir.join("tangled"),
        _ => PathBuf::from("tangled"),
    }
}

fn run() -> Result<i32, LpError> {
    match Cli::parse().command {
        <<main: tangle, and what it reports>>
        <<main: watch, and its options>>
        <<main: the map arm>>

        <<main: map, in reverse>>

        <<main: map, forward>>

        <<main: map, the answer>>
        }
        <<main: explain, a filter on stdin>>
        <<main: list, one document>>
        <<main: metadata, the stream itself>>
        <<main: unaccounted, which needs a plan>>
    }
}

fn list(docs: &[PathBuf]) -> Result<(), LpError> {
    <<main: plan, and who is referenced>>

    <<main: one row per declaration>>

    <<main: the outputs at the end>>
    Ok(())
}
````)

== The surface

The declarations are the contract, so they are also where the help text lives: the comments
in this file are `lp --help`. Each command gets its own fragment, because each one is a
promise about what the tool does.

#chunk("main: the modules, and what they are called", ````rust
mod book;
mod diag;
mod embedded;
mod explain;
mod map;
mod metadata;
mod status;
mod tangle;
mod watch;
mod weave;

use std::collections::BTreeSet;
use std::io::Read;
use std::path::PathBuf;

use clap::{Parser, Subcommand};

use diag::LpError;
````)

#chunk("main: the surface, as clap sees it", ````rust
#[derive(Parser)]
#[command(name = "lp", version, about = "Typst-based literate programming")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}
````)

#chunk("main: extract", ````rust
#[command(about = "Take the book back out of a page this tool rendered")]
Extract {
    #[arg(long)]
    #[arg(help = "Which rendering to read")]
    format: String,
    #[arg(help = "The rendered page")]
    file: PathBuf,
    #[arg(long)]
    #[arg(help = "Directory to write the book into")]
    out: PathBuf,
},
````)

#chunk("main: self", ````rust
#[command(name = "self")]
Itself {
    #[command(subcommand)]
    method: SelfMethod,
},
````)

#chunk("main: self, what it can do", ````rust
#[derive(Subcommand)]
enum SelfMethod {
    #[command(about = "Write the book out, entire")]
    Book {
        #[arg(long)]
        #[arg(help = "Directory to write it into")]
        out: PathBuf,
    },
    #[command(about = "Weave the document this binary carries, then open it")]
    Read {
        #[arg(long, default_value = "pdf")]
        #[arg(help = "Which rendering to make")]
        format: String,
    },
    #[command(about = "Unpack the book, tangle it with this binary, and run the tree's own checks")]
    Prove {
        #[arg(help = "Directory to build the book in")]
        dir: PathBuf,
    },
}
````)

#chunk("main: weave", ````rust
Weave {
    doc: PathBuf,
    output: Option<PathBuf>,
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    extra: Vec<String>,
},
````)

#chunk("main: tangle", ````rust
#[command(about = "Expand a .typ document into its source files")]
Tangle {
    #[arg(required = true)]
    #[arg(help = "Documents to tangle, e.g. book/lp.typ")]
    docs: Vec<PathBuf>,
    #[arg(long)]
    #[arg(
        help = "Directory the root chunk names resolve into (default: tangled/ next to the documents, or in the working directory for commands that take none)"
    )]
    out: Option<PathBuf>,
    #[arg(long)]
    #[arg(help = "Write nothing; fail if the generated files are out of date")]
    check: bool,
},
````)

#chunk("main: map", ````rust
Map {
    #[arg(long, conflicts_with = "typ")]
    file: Option<String>,
    #[arg(long, conflicts_with = "file")]
    typ: Option<String>,
    #[arg(long)]
    line: Option<usize>,
    #[arg(long)]
    out: Option<PathBuf>,
},
````)

#chunk("main: explain", ````rust
#[command(about = "Rewrite diagnostics so they name the chunk that produced the line")]
Explain {
    #[arg(long)]
    out: Option<PathBuf>,
},
````)

#chunk("main: watch", ````rust
Watch {
    #[arg(required = true)]
    docs: Vec<PathBuf>,
    #[arg(long)]
    out: Option<PathBuf>,
    #[arg(long, default_value_t = 200)]
    debounce: u64,
    #[arg(long)]
    check_cmd: Option<String>,
},
````)

#chunk("main: list", ````rust
#[command(about = "List the chunks a document declares")]
List { doc: PathBuf },
````)

`list` and `metadata` are the two commands that exist for the person debugging a document
rather than for the build. They answer the questions a reader of this document asks all the
time — which chunks exist, in what order, and what does Typst actually hand over — and they do
it without writing anything.

#chunk("main: metadata", ````rust
Metadata {
    #[arg(required = true)]
    docs: Vec<PathBuf>,
},
````)

#chunk("main: unaccounted", ````rust
#[command(
    about = "List (or delete) files under the output directory that nothing accounts for"
)]
Unaccounted {
    #[arg(required = true)]
    #[arg(help = "Documents that decide what counts as produced")]
    docs: Vec<PathBuf>,
    #[arg(long)]
    out: Option<PathBuf>,
    #[arg(long)]
    #[arg(help = "Delete them: the explicit alternative to declaring them")]
    delete: bool,
},
````)

== How errors leave the program

Every error in this program is an `LpError`, and this is the only place it becomes text. The
report handler is installed once, so no module has to think about rendering; and the exit
status is 1 for every failure, which is all a shell needs to know.

#chunk("main: how an error is printed", ````rust
let _ = miette::set_hook(Box::new(|_| {
    Box::new(miette::GraphicalReportHandler::new_themed(
        miette::GraphicalTheme::unicode(),
    ))
}));
````)

#chunk("main: the exit status", ````rust
match run() {
    Ok(code) => std::process::exit(code),
    Err(err) => {
        eprintln!("{:?}", miette::Report::new(err));
        std::process::exit(1);
    }
}
````)

== Dispatch, one arm per promise

Each arm is short on purpose: parse the arguments, call the module, print. Where an arm grows
a decision, that decision belongs in the module it calls, and the arm gets thinner or the
module gets a new function.

#chunk("main: tangle, and what it reports", ````rust
Command::Weave { doc, output, extra } => weave::run(&doc, output.as_deref(), &extra),
Command::Extract { format, file, out } => {
    let files = crate::book::extract(&file, &format, &out)?;
    println!("wrote {files} files of the book to {}", out.display());
    Ok(0)
}
Command::Itself { method } => match method {
    SelfMethod::Book { out } => {
        let files = embedded::book(&out)?;
        println!("wrote {files} files of the book to {}", out.display());
        Ok(0)
    }
    SelfMethod::Read { format } => {
        let path = embedded::read(&format)?;
        println!("{}", path.display());
        Ok(0)
    }
    SelfMethod::Prove { dir } => embedded::prove(&dir),
},
Command::Tangle { docs, out, check } => {
    let out = out_dir(out, &docs);
    let outcome = tangle::run(&docs, &out, check)?;
    for output in &outcome.changed {
        println!(
            "wrote  {}  ({} lines, {})",
            output.root,
            output.lines,
            output.lang.as_deref().unwrap_or("-")
        );
    }
    for output in &outcome.unchanged {
        println!("ok     {}", output.root);
    }
    for line in &outcome.stale {
        eprintln!("{line}");
    }
    for warning in &outcome.warnings {
        eprintln!("warning: {warning}");
    }
    for group in &outcome.unaccounted {
        let label = if group.dir.is_empty() {
            "."
        } else {
            group.dir.as_str()
        };
        eprintln!(
            "note: {} entr{} in {label}/ that nothing accounts for (run `lp unaccounted`)",
            group.entries.len(),
            if group.entries.len() == 1 { "y" } else { "ies" }
        );
    }
    Ok(i32::from(!outcome.stale.is_empty()))
}
````)

Tangling is the one command with a *report* rather than a result: what was written, what was
already right, what drifted, what was warned about, and what nothing accounts for. The exit
status is 1 when there is drift and 0 otherwise, so `--check` is usable from a script without
parsing anything.

#chunk("main: watch, and its options", ````rust
Command::Watch {
    docs,
    out,
    debounce,
    check_cmd,
} => {
    let out = out_dir(out, &docs);
    watch::run(watch::Options {
        docs,
        out,
        debounce: std::time::Duration::from_millis(debounce),
        check_cmd,
    })?;
    Ok(0)
}
````)

#chunk("main: the map arm", ````rust
Command::Map {
    file,
    typ,
    line,
    out,
} => {
    let out = out_dir(out, &[]);
    let maps = map::LpMap::read_all(&out);
````)

`map` has two directions, and they are different enough to be separate fragments. In reverse
it scans every run in every file, which is a linear search — acceptable because it runs when
a person asks, not in a loop.

#chunk("main: map, in reverse", ````rust
    if let Some(chunk) = typ {
        let mut hits = 0;
        for (dir, map) in &maps {
            for (name, file) in &map.files {
                for run in &file.runs {
                    if run.chunk == chunk {
                        for line in run.first..=run.last {
                            println!("{}:{}", map::join(dir, name), line);
                            hits += 1;
                        }
                    }
                }
            }
        }
        if hits == 0 {
            eprintln!("note: nothing in the generated files came from chunk ⟪{chunk}⟫");
        }
        return Ok(0);
    }
````)

Forward, it resolves the file to one map (the search from the map chapter, including its
refusal to guess) and then asks that map for the run covering the line.

#chunk("main: map, forward", ````rust
    let (Some(file), Some(line)) = (file, line) else {
        return Err(LpError::plain("lp map --file needs a --line").with_help(
            "use `lp map --file src/main.rs --line 42` for a generated line, or `lp map --typ <chunk>` the other way",
        ));
    };
    let (dir, name, entry) = map::resolve_all(&maps, &file)?;
    let rel = map::join(dir, name);
    let Some((run, offset)) = entry.locate(line) else {
        return Err(LpError::plain(format!(
            "{rel}:{line}: no map knows this file"
        )));
    };
````)

#chunk("main: map, the answer", ````rust
    println!("chunk ⟪{}⟫, line {offset} of it", run.chunk);
    println!("    find it with: rg '#chunk(\"{}\")'", run.chunk);
    Ok(0)
````)

#chunk("main: explain, a filter on stdin", ````rust
Command::Explain { out } => {
    let out = out_dir(out, &[]);
    let mut input = String::new();
    std::io::stdin()
        .read_to_string(&mut input)
        .map_err(|e| LpError::plain(e.to_string()))?;
    let mapped = explain::run(&out, &input)?;
    if mapped == 0 {
        eprintln!("note: no diagnostic line matched any map");
    }
    Ok(0)
}
````)

Reading standard input rather than taking a file means the command composes: anything that
prints diagnostics can be piped in, and the note about nothing matching goes to stderr so the
pipeline's stdout stays exactly what it was.

#chunk("main: list, one document", ````rust
Command::List { doc } => {
    list(std::slice::from_ref(&doc))?;
    Ok(0)
}
````)

#chunk("main: metadata, the stream itself", ````rust
Command::Metadata { docs } => {
    let typst = metadata::binary()?;
    for declaration in metadata::declarations(&typst, &docs)? {
        println!(
            "{:<6} {:<28} {:<8} {}",
            declaration.lp,
            declaration.name,
            declaration.lang.as_deref().unwrap_or("-"),
            declaration.text.lines().next().unwrap_or("")
        );
    }
    Ok(0)
}
````)

#chunk("main: unaccounted, which needs a plan", ````rust
Command::Unaccounted { docs, out, delete } => {
    let out = out_dir(out, &docs);
    let plan = tangle::plan(&docs)?;
    status::run(&out, &tangle::produced(&plan), delete)
}
````)

== The one command with a view of its own

`list` is a debug view, and it is the one place in this file where the program looks at the
plan's contents rather than handing them to a module: it needs the set of names that are
referenced, which `plan` computes internally and does not expose. Widening `Plan` for a
debug command seemed the worse trade, so the three lines are repeated here — a wart, kept
deliberately, and this is where it is recorded.

#chunk("main: plan, and who is referenced", ````rust
let plan = tangle::plan(docs)?;
let set = tangle::ChunkSet::new(&plan.blocks);
let referenced: BTreeSet<String> = plan.blocks.iter().flat_map(tangle::refs_of).collect();
````)

#chunk("main: one row per declaration", ````rust
for doc in docs {
    println!("{}", doc.display());
}
for block in &plan.blocks {
    let kind = if block.root { "file" } else { "frag" };
    let used = if referenced.contains(&block.name) || block.root {
        String::new()
    } else {
        "unreferenced".to_string()
    };
    println!(
        "  {kind}  {:<28} {:<8} {}",
        format!("⟪{}⟫", block.name),
        block.lang.as_deref().unwrap_or("-"),
        used
    );
}
````)

#chunk("main: the outputs at the end", ````rust
let roots = set.roots();
println!(
    "\noutputs: {}",
    if roots.is_empty() {
        "(none)".to_string()
    } else {
        roots
            .iter()
            .map(|root| format!("<{root}>"))
            .collect::<Vec<_>>()
            .join(", ")
    }
);
````)
= How the tests are written

The chapters above make claims about behaviour; this is where the claims are pinned. The suite
runs the real binary against throwaway documents in temporary directories, because every
failure worth catching is at a seam — a document that does not evaluate, a file nothing
accounts for, a diagnostic that has to find its way back — and a unit test with a mock in the
middle would test the mock.

The shape is the same in every file: copy the package next to the fixture, write a document,
run `lp` with `current_dir` set to the temporary project, and assert on what came out. There is
no test framework beyond `#[test]`, and the assertions read as sentences because the names of
the cases do.

== The five files

Each file is a skeleton of its cases: the fixtures and helpers first, then one fragment per
case. That makes the file's shape the suite's table of contents, and it means a reader who is
looking for "where is that pinned?" can read the list of names instead of the whole file.

=== tests/flow.rs — what tangling does

The largest file, and the one that pins the mechanism: a fragment shared by two files, a name
declared twice, indentation at the reference site, the map, the three failures, and the two
commands that read the result back. Most of the cases share one fixture, because the point is
what the *same* document produces in different situations.

#file("tests/flow.rs", ````rust
<<flow: the fixtures and helpers>>

<<flow: tangle_writes_files_with_concat_and_indentation>>

<<flow: tangle_records_which_chunk_every_line_came_from>>

<<flow: indentation_follows_the_reference_site>>

<<flow: a_chunk_written_indented_in_the_document_is_still_dedented>>

<<flow: a_chapter_can_hold_the_fragment_another_file_references>>

<<flow: maps_live_next_to_the_files_they_explain>>

<<flow: an_ambiguous_file_name_is_an_error_not_a_guess>>

<<flow: check_names_the_chunk_of_the_first_difference>>

<<flow: the_map_follows_the_document_even_when_no_output_byte_changes>>

<<flow: dangling_reference_quotes_the_line>>

<<flow: cycle_is_reported>>

<<flow: an_empty_chunk_is_an_error>>
<<flow: a_declaration_without_a_language_warns>>

<<flow: a_file_declaration_can_name_a_nested_path>>

<<flow: unsafe_paths_are_rejected>>

<<flow: weave_renders_a_document_that_imports_the_package>>

<<flow: a_blank_line_in_an_indented_fragment_stays_blank>>

<<flow: tangling_leaves_only_dot_lp_beside_the_document>>

<<flow: a_pdf_gives_the_book_back>>

<<flow: weaving_a_document_with_no_book_carries_none>>

<<flow: a_page_gives_the_book_back>>

<<flow: reading_weaves_what_the_binary_carries>>

<<flow: the_book_comes_back_out_whole>>

<<flow: the_book_is_carried_into_the_tree>>

<<flow: an_unknown_tangle_option_is_refused>>

<<flow: a_stale_book_copy_is_removed_and_check_refuses_it>>

<<flow: a_book_name_may_not_leave_the_tree>>

<<flow: a_book_without_a_directory_is_an_error>>

<<flow: a_book_may_not_overwrite_an_output>>

<<flow: map_names_the_chunk_a_generated_line_came_from>>

<<flow: explain_rewrites_diagnostics_to_the_chunk>>

<<flow: list_reports_declarations>>

<<flow: a_chunk_built_by_code_is_attributed_to_itself>>

<<flow: the_declaration_is_where_the_line_lives>>
````)

The cases, in the order they appear:

- `tangle_writes_files_with_concat_and_indentation` — a shared fragment and a name declared twice land in one file, with the reference's indentation
- `tangle_records_which_chunk_every_line_came_from` — the map names a chunk and a run for every output line, and records no source positions
- `indentation_follows_the_reference_site` — the same chunk indents differently at two reference sites
- `a_chunk_written_indented_in_the_document_is_still_dedented` — a declaration written inside a list item contributes flush-left text
- `a_chapter_can_hold_the_fragment_another_file_references` — a fragment declared in a second document is visible to the first
- `maps_live_next_to_the_files_they_explain` — one map per directory, not one at the top
- `an_ambiguous_file_name_is_an_error_not_a_guess` — a bare name that two maps could explain is refused, with the candidates listed
- `check_names_the_chunk_of_the_first_difference` — drift is reported as the first differing line and the chunk responsible for it
- `the_map_follows_the_document_even_when_no_output_byte_changes` — moving prose rewrites the map even when no output byte moves
- `dangling_reference_quotes_the_line` — an undefined name is an error that quotes the line and names the chunk it was in
- `cycle_is_reported` — the error is the chain, not a bare `cycle detected`
- `an_empty_chunk_is_an_error` — a declaration with no body is refused rather than tangled away
- `a_declaration_without_a_language_warns` — a fence with no language tag is reported, and the pass still succeeds
- `a_file_declaration_can_name_a_nested_path` — `src/main.rs` is created under the output directory, directories and all
- `unsafe_paths_are_rejected` — `../escape.txt` and its relatives cannot leave the output directory
- `map_names_the_chunk_a_generated_line_came_from` — `lp map --file --line` answers with the chunk and how far into it the line is
- `explain_rewrites_diagnostics_to_the_chunk` — a `file:line:col:` line is echoed unchanged and annotated on stderr
- `list_reports_declarations` — `lp list` prints every declaration, marks the unreferenced ones, and lists the outputs; a code block in prose is not one
- `weave_renders_a_document_that_imports_the_package` — `lp weave` renders a document whose import resolves only through the package this tool unpacks
- `the_book_is_carried_into_the_tree` — the settings put the book beside its output, under the names it lists, and nothing else
- `a_book_name_may_not_leave_the_tree` — a name in `book-files` that climbs out of the source tree is refused
- `a_stale_book_copy_is_removed_and_check_refuses_it` — the book directory is the list: a copy it no longer names is removed by a tangle and refused by `--check`
- `the_book_comes_back_out_whole` — `lp self book --out` writes exactly the book the binary carries, byte for byte
- `reading_weaves_what_the_binary_carries` — `lp self read --format html` weaves the embedded document and leaves a rendering behind
- `a_page_gives_the_book_back` — `lp weave` puts the book the document declares into the HTML it renders, and `lp extract` gets it back byte for byte
- `weaving_a_document_with_no_book_carries_none` — a document that declares nothing still weaves: no block, and no complaint either
- `a_pdf_gives_the_book_back` — the PDF carries the book as attached files, and `lp extract --format pdf` gets it back byte for byte
- `tangling_leaves_only_dot_lp_beside_the_document` — everything the tool writes beside a document is under `.lp`: the package, the wrapper, all of it
- `a_blank_line_in_an_indented_fragment_stays_blank` — an indented fragment's blank line is written blank, not as a line of spaces
- `an_unknown_tangle_option_is_refused` — the package refuses a key it does not know, at the line that wrote it
- `a_book_without_a_directory_is_an_error` — asking for a book without saying where it goes is refused by the tool
- `a_book_may_not_overwrite_an_output` — a book that would land on a declared file is refused while planning
- `a_chunk_built_by_code_is_attributed_to_itself` — roots declared by a loop are attributed to the declarations the loop produced
- `the_declaration_is_where_the_line_lives` — the answer includes the `rg` command that finds the declaration

#chunk("flow: the fixtures and helpers", ````rust
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../typst/lp.typ");

fn document(body: &str) -> String {
    format!("#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}")
}

const DOC: &str = concat!(
    "\
= Demo

#file(\"main.py\", ```py
",
    "<<imports>>\n",
    "<<body>>\n",
    "\
```)

#chunk(\"imports\", ```py
import sys
```)

#chunk(\"body\", ```py
print('one')
```)

#chunk(\"body\", ```py
print('two')
```)

```text
not a chunk
```
",
);

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = document(body);
    std::fs::write(dir.join(name), &text).expect("doc");
    text
}

fn project(body: &str) -> (TempDir, std::path::PathBuf, String) {
    let dir = TempDir::new().expect("temp dir");
    let text = write_doc(dir.path(), "demo.typ", body);
    let path = dir.path().to_path_buf();
    (dir, path, text)
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn line_of(text: &str, needle: &str) -> usize {
    text.lines()
        .position(|line| line.contains(needle))
        .expect("needle")
        + 1
}
````)

#chunk("flow: tangle_writes_files_with_concat_and_indentation", ````rust
#[test]
fn tangle_writes_files_with_concat_and_indentation() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "import sys\nprint('one')\nprint('two')\n"
    );
}
````)

#chunk("flow: tangle_records_which_chunk_every_line_came_from", ````rust
#[test]
fn tangle_records_which_chunk_every_line_came_from() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let map: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(dir.join("out/.lpmap.json")).expect("map"))
            .expect("json");
    let entry = &map["files"]["main.py"];
    assert_eq!(
        entry["runs"],
        serde_json::json!([
            { "chunk": "imports", "first": 1, "last": 1 },
            { "chunk": "body", "first": 2, "last": 3 },
        ])
    );
    assert!(entry.get("lines").is_none(), "no line numbers are recorded");
    assert!(entry.get("sources").is_none(), "nor source files");
}
````)

#chunk("flow: indentation_follows_the_reference_site", ````rust
#[test]
fn indentation_follows_the_reference_site() {
    let body = "#file(\"main.py\", ```py\nif True:\n    <<body>>\n```)\n\n#chunk(\"body\", ```py\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "if True:\n    print(1)\n"
    );
}
````)

#chunk(
  "flow: a_chunk_written_indented_in_the_document_is_still_dedented",
  ````rust
  #[test]
  fn a_chunk_written_indented_in_the_document_is_still_dedented() {
      let body = "#file(\"main.py\", ```py\nif x:\n    <<body>>\n```)\n\n- step one:\n\n  #chunk(\"body\", ```py\n  print(1)\n  print(2)\n  ```)\n";
      let (_guard, dir, _) = project(body);
      let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
      assert!(output.status.success(), "{}", stderr(&output));
      assert_eq!(
          std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
          "if x:\n    print(1)\n    print(2)\n"
      );
  }
  ````,
)

#chunk("flow: a_chapter_can_hold_the_fragment_another_file_references", ````rust
#[test]
fn a_chapter_can_hold_the_fragment_another_file_references() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write_doc(
        dir.path(),
        "chapter.typ",
        "= Chapter one\n\n#chunk(\"greeting\", ```py\nprint('hi')\n```)\n",
    );
    write_doc(
        dir.path(),
        "book.typ",
        "= The program\n\n#file(\"src/main.py\", ```py\n<<greeting>>\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(
        &path,
        &["tangle", "book.typ", "chapter.typ", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("main"),
        "print('hi')\n"
    );

    let mapped = lp(
        &path,
        &[
            "map",
            "--file",
            "src/main.py",
            "--line",
            "1",
            "--out",
            "out",
        ],
    );
    assert!(
        stdout(&mapped).starts_with("chunk ⟪greeting⟫, line 1 of it"),
        "{}",
        stdout(&mapped)
    );

    let no_files = lp(&path, &["tangle", "chapter.typ", "--out", "out2"]);
    assert!(!no_files.status.success());
    assert!(
        stderr(&no_files).contains("no file declarations"),
        "{}",
        stderr(&no_files)
    );
}
````)

#chunk("flow: maps_live_next_to_the_files_they_explain", ````rust
#[test]
fn maps_live_next_to_the_files_they_explain() {
    let body =
        "#file(\"a.py\", ```py\nprint('a')\n```)\n\n#file(\"src/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let root: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/.lpmap.json")).expect("root map"),
    )
    .expect("json");
    let nested: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/src/.lpmap.json")).expect("nested map"),
    )
    .expect("json");
    assert!(root["files"].get("a.py").is_some(), "{root}");
    assert!(
        root["files"].get("src/b.py").is_none(),
        "the root map must not index the subtree: {root}"
    );
    assert!(nested["files"].get("b.py").is_some(), "{nested}");

    for file in ["src/b.py", "b.py"] {
        let output = lp(
            &dir,
            &["map", "--file", file, "--line", "1", "--out", "out"],
        );
        assert!(output.status.success(), "{file}: {}", stderr(&output));
        assert!(
            stdout(&output).starts_with("chunk ⟪src/b.py⟫"),
            "{file}: {}",
            stdout(&output)
        );
    }
}
````)

#chunk("flow: an_ambiguous_file_name_is_an_error_not_a_guess", ````rust
#[test]
fn an_ambiguous_file_name_is_an_error_not_a_guess() {
    let body = "#file(\"one/b.py\", ```py\nprint('a')\n```)\n\n#file(\"two/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = lp(
        &dir,
        &["map", "--file", "b.py", "--line", "1", "--out", "out"],
    );
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("which map?"),
        "{}",
        stderr(&output)
    );

    let explicit = lp(
        &dir,
        &["map", "--file", "two/b.py", "--line", "1", "--out", "out"],
    );
    assert!(explicit.status.success(), "{}", stderr(&explicit));
}
````)

#chunk("flow: check_names_the_chunk_of_the_first_difference", ````rust
#[test]
fn check_names_the_chunk_of_the_first_difference() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"])
            .status
            .success()
    );

    std::fs::write(dir.join("out/main.py"), "hand edited\n").expect("write");
    let drift = lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"]);
    assert!(!drift.status.success(), "drift must fail");
    let message = stderr(&drift);
    assert!(
        message.contains("STALE  main.py (line 1, in chunk ⟪imports⟫)"),
        "{message}"
    );

    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"])
            .status
            .success()
    );
}
````)

#chunk(
  "flow: the_map_follows_the_document_even_when_no_output_byte_changes",
  ````rust
  #[test]
  fn the_map_follows_the_document_even_when_no_output_byte_changes() {
      let (_guard, dir, _) = project(DOC);
      assert!(
          lp(&dir, &["tangle", "demo.typ", "--out", "out"])
              .status
              .success()
      );

      let moved = format!(
          "{}\n{}",
          "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule", DOC
      );
      std::fs::write(dir.join("demo.typ"), &moved).expect("rewrite");

      let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
      assert!(output.status.success(), "{}", stderr(&output));
      assert!(
          !stdout(&output).contains("wrote"),
          "outputs are unchanged: {}",
          stdout(&output)
      );

      let forward = lp(
          &dir,
          &["map", "--file", "main.py", "--line", "3", "--out", "out"],
      );
      assert!(
          stdout(&forward).starts_with("chunk ⟪body⟫, line 2 of it"),
          "{}",
          stdout(&forward)
      );
  }
  ````,
)

#chunk("flow: dangling_reference_quotes_the_line", ````rust
#[test]
fn dangling_reference_quotes_the_line() {
    let body = "#file(\"main.py\", ```py\n<<missing>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(
        message.contains("chunk ⟪missing⟫ is not defined"),
        "{message}"
    );
    assert!(
        message.contains("<<missing>>"),
        "the line is quoted: {message}"
    );
    assert!(
        message.contains("in chunk ⟪main.py⟫, line 1 of it"),
        "{message}"
    );
}
````)

#chunk("flow: cycle_is_reported", ````rust
#[test]
fn cycle_is_reported() {
    let body = "#file(\"main.py\", ```py\n<<a>>\n```)\n\n#chunk(\"a\", ```py\n<<b>>\n```)\n\n#chunk(\"b\", ```py\n<<a>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("cycle in chunks"),
        "{}",
        stderr(&output)
    );
}
````)

#chunk("flow: a_declaration_without_a_language_warns", ````rust
#[test]
fn a_declaration_without_a_language_warns() {
    let body = "#file(\"main.py\", ```\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪main.py⟫ is declared without a language"),
        "{}",
        stderr(&output)
    );
}
````)

#chunk("flow: an_empty_chunk_is_an_error", ````rust
#[test]
fn an_empty_chunk_is_an_error() {
    let body = "#file(\"main.py\", ```py\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("is empty"), "{}", stderr(&output));
}
````)

#chunk("flow: a_file_declaration_can_name_a_nested_path", ````rust
#[test]
fn a_file_declaration_can_name_a_nested_path() {
    let body = "#file(\"src/main.rs\", ```rust\nfn main() {}\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/src/main.rs")).expect("nested"),
        "fn main() {}\n"
    );
}
````)

#chunk("flow: unsafe_paths_are_rejected", ````rust
#[test]
fn unsafe_paths_are_rejected() {
    let body = "#file(\"../escape.txt\", ```text\nx\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("unsafe chunk name"),
        "{}",
        stderr(&output)
    );
}
````)

#chunk("flow: map_names_the_chunk_a_generated_line_came_from", ````rust
#[test]
fn map_names_the_chunk_a_generated_line_came_from() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        stdout(&output).lines().next(),
        Some("chunk ⟪body⟫, line 2 of it")
    );

    let reverse = lp(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("main.py:2"),
        "{}",
        stdout(&reverse)
    );
    assert!(
        stdout(&reverse).contains("main.py:3"),
        "{}",
        stdout(&reverse)
    );
}
````)

#chunk("flow: explain_rewrites_diagnostics_to_the_chunk", ````rust
#[test]
fn explain_rewrites_diagnostics_to_the_chunk() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let mut child = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["explain", "--out", "out"])
        .current_dir(&dir)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .expect("spawn");

    use std::io::Write;
    child
        .stdin
        .as_mut()
        .expect("stdin")
        .write_all(b"out/main.py:3:1: boom\n")
        .expect("write");
    let output = child.wait_with_output().expect("wait");

    assert!(stdout(&output).contains("out/main.py:3:1: boom"));
    let message = stderr(&output);
    assert!(message.contains("chunk ⟪body⟫, line 2 of it"), "{message}");
}
````)

#chunk("flow: weave_renders_a_document_that_imports_the_package", ````rust
#[test]
fn weave_renders_a_document_that_imports_the_package() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("doc.typ"),
        "#import \"@local/lp:0.1.0\": show-rule\n#show: show-rule\n= Woven\n",
    )
    .expect("doc");

    let output = lp(dir.path(), &["weave", "doc.typ", "doc.pdf"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        dir.path().join("doc.pdf").exists(),
        "no document was written"
    );
}
````)

#chunk("flow: the_book_comes_back_out_whole", ````rust
#[test]
fn the_book_comes_back_out_whole() {
    let dir = TempDir::new().expect("temp dir");
    let output = lp(dir.path(), &["self", "book", "--out", "unpacked"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let beside = Path::new(env!("CARGO_MANIFEST_DIR")).join("book");
    for name in ["lp.typ", "README.md", ".gitignore"] {
        let embedded = std::fs::read(dir.path().join("unpacked").join(name)).expect(name);
        let carried = std::fs::read(beside.join(name)).expect(name);
        assert_eq!(embedded, carried, "{name} came back different");
    }
}
````)

#chunk("flow: reading_weaves_what_the_binary_carries", ````rust
#[test]
fn reading_weaves_what_the_binary_carries() {
    let dir = TempDir::new().expect("temp dir");
    let output = lp(dir.path(), &["self", "read", "--format", "html"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let path = PathBuf::from(stdout(&output).trim());
    let size = std::fs::metadata(&path)
        .expect("the rendering is there")
        .len();
    assert!(
        size > 10_000,
        "{} looks empty: {size} bytes",
        path.display()
    );
}
````)

#chunk("flow: a_blank_line_in_an_indented_fragment_stays_blank", ````rust
#[test]
fn a_blank_line_in_an_indented_fragment_stays_blank() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#file(\"src/main.rs\", ```rust\nfn outer() {\n    <<inner>>\n}\n```)\n\n#chunk(\"inner\", ```rust\nlet a = 1;\n\nlet b = 2;\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let written = std::fs::read_to_string(dir.path().join("tangled/src/main.rs")).expect("file");

    assert!(
        written.contains("    let a = 1;\n\n    let b = 2;\n"),
        "{written:?}"
    );
    assert!(
        written.lines().all(|line| line == line.trim_end()),
        "an indented fragment left trailing whitespace: {written:?}"
    );
}
````)

#chunk("flow: tangling_leaves_only_dot_lp_beside_the_document", ````rust
#[test]
fn tangling_leaves_only_dot_lp_beside_the_document() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document("#file(\"main.py\", ```py\nprint('x')\n```)\n"),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let mut unexpected: Vec<String> = std::fs::read_dir(dir.path())
        .expect("the source directory")
        .flatten()
        .map(|entry| entry.file_name().to_string_lossy().to_string())
        .filter(|name| !["lp.typ", "demo.typ", "tangled", ".lp"].contains(&name.as_str()))
        .collect();
    unexpected.sort();
    assert!(unexpected.is_empty(), "the tool left {unexpected:?} behind");
}
````)

#chunk("flow: a_pdf_gives_the_book_back", ````rust
#[test]
fn a_pdf_gives_the_book_back() {
    let dir = TempDir::new().expect("temp dir");
    let document = Path::new(env!("CARGO_MANIFEST_DIR")).join("book/lp.typ");
    let woven = lp(
        dir.path(),
        &["weave", document.to_str().expect("path"), "page.pdf"],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));

    let taken = lp(
        dir.path(),
        &["extract", "--format", "pdf", "page.pdf", "--out", "back"],
    );
    assert!(taken.status.success(), "{}", stderr(&taken));

    let carried = Path::new(env!("CARGO_MANIFEST_DIR")).join("book");
    for name in ["lp.typ", "README.md", ".gitignore"] {
        let back = std::fs::read(dir.path().join("back").join(name)).expect(name);
        let beside = std::fs::read(carried.join(name)).expect(name);
        assert_eq!(back, beside, "{name} did not survive the PDF");
    }
}
````)

#chunk("flow: weaving_a_document_with_no_book_carries_none", ````rust
#[test]
fn weaving_a_document_with_no_book_carries_none() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("plain.typ"), "= Plain\n\nJust words.\n").expect("doc");

    let woven = lp(
        dir.path(),
        &["weave", "plain.typ", "plain.html", "--features", "html"],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));
    let page = std::fs::read_to_string(dir.path().join("plain.html")).expect("page");
    assert!(
        !page.contains("lp-source"),
        "a document with no book got one"
    );
}
````)

#chunk("flow: a_page_gives_the_book_back", ````rust
#[test]
fn a_page_gives_the_book_back() {
    let dir = TempDir::new().expect("temp dir");
    let document = Path::new(env!("CARGO_MANIFEST_DIR")).join("book/lp.typ");
    let woven = lp(
        dir.path(),
        &[
            "weave",
            document.to_str().expect("path"),
            "page.html",
            "--features",
            "html",
        ],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));

    let taken = lp(
        dir.path(),
        &["extract", "--format", "html", "page.html", "--out", "back"],
    );
    assert!(taken.status.success(), "{}", stderr(&taken));

    let carried = Path::new(env!("CARGO_MANIFEST_DIR")).join("book");
    for name in ["lp.typ", "README.md", ".gitignore"] {
        let back = std::fs::read(dir.path().join("back").join(name)).expect(name);
        let beside = std::fs::read(carried.join(name)).expect(name);
        assert_eq!(back, beside, "{name} did not survive the page");
    }
}
````)

#chunk("flow: the_book_is_carried_into_the_tree", ````rust
#[test]
fn the_book_is_carried_into_the_tree() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the book\n").expect("readme");
    std::fs::create_dir(dir.path().join("chapters")).expect("dir");
    std::fs::write(dir.path().join("chapters/one.typ"), "= One\n").expect("chapter");
    std::fs::write(dir.path().join("ignored.txt"), "not part of it\n").expect("ignored");
    std::fs::write(dir.path().join(".gitignore"), "ignored.txt\n").expect("gitignore");
    std::fs::create_dir_all(dir.path().join(".lp/local/lp/0.1.0")).expect("dir");
    std::fs::write(
        dir.path().join(".lp/local/lp/0.1.0/lib.typ"),
        "the tool's own state\n",
    )
    .expect("state");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", book-files: (\"demo.typ\", \"chapters/one.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        dir.path().join("tangled/book/demo.typ").exists(),
        "a named file is copied under its own name"
    );
    assert!(
        dir.path().join("tangled/book/chapters/one.typ").exists(),
        "a name with a directory in it keeps its shape"
    );
    assert!(
        dir.path().join("tangled/book/README.md").exists(),
        "and so does a name with no directory at all"
    );
    assert!(
        !dir.path().join("tangled/book/ignored.txt").exists(),
        "a file the list does not name is not part of the book, whatever the source's .gitignore says"
    );
    assert!(
        !dir.path().join("tangled/book/.lp").exists(),
        "and neither is the state the tool keeps for itself"
    );
}
````)

#chunk("flow: an_unknown_tangle_option_is_refused", ````rust
#[test]
fn an_unknown_tangle_option_is_refused() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", nonsense: 1))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(!output.status.success(), "an unknown key is not ignored");
    assert!(
        stderr(&output).contains("unknown tangle option"),
        "the package refuses it where it was written: {}",
        stderr(&output)
    );
}
````)

#chunk("flow: a_stale_book_copy_is_removed_and_check_refuses_it", ````rust
#[test]
fn a_stale_book_copy_is_removed_and_check_refuses_it() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the pointer\n").expect("book file");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", book-files: (\"demo.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");
    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let stale = dir.path().join("tangled/book/old.txt");
    std::fs::write(&stale, "from a generation ago\n").expect("stale");
    let checked = lp(dir.path(), &["tangle", "demo.typ", "--check"]);
    assert!(
        !checked.status.success(),
        "check refuses a tree with a stale copy"
    );
    assert!(
        stderr(&checked).contains("no longer names"),
        "and says why: {}",
        stderr(&checked)
    );

    let again = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(again.status.success(), "{}", stderr(&again));
    assert!(
        !stale.exists(),
        "a plain tangle removes what the list stopped naming"
    );
}
````)

#chunk("flow: a_book_name_may_not_leave_the_tree", ````rust
#[test]
fn a_book_name_may_not_leave_the_tree() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", book-files: (\"../outside.txt\",)))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(
        !output.status.success(),
        "a name outside the tree is refused"
    );
    assert!(
        stderr(&output).contains("leaves the source tree"),
        "and it says why: {}",
        stderr(&output)
    );
}
````)

#chunk("flow: a_book_without_a_directory_is_an_error", ````rust
#[test]
fn a_book_without_a_directory_is_an_error() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-files: (\"main.py\",)))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("book-directory"),
        "the tool says which key is missing: {}",
        stderr(&output)
    );
}
````)

#chunk("flow: a_book_may_not_overwrite_an_output", ````rust
#[test]
fn a_book_may_not_overwrite_an_output() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("main.py"),
        "a source file the book would carry\n",
    )
    .expect("source");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"src\", book-files: (\"main.py\",)))\n\n#file(\"src/main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(
        !output.status.success(),
        "two writers for one path is refused"
    );
    assert!(
        stderr(&output).contains("would overwrite"),
        "and it says which path: {}",
        stderr(&output)
    );
}
````)

#chunk("flow: list_reports_declarations", ````rust
#[test]
fn list_reports_declarations() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["list", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let listed = stdout(&output);
    assert!(listed.contains("file  ⟪main.py⟫"), "{listed}");
    assert!(listed.contains("frag  ⟪body⟫"), "{listed}");
    assert!(listed.contains("outputs: <main.py>"), "{listed}");
    assert!(
        !listed.contains("not a chunk"),
        "an undeclared block is not a chunk: {listed}"
    );
}
````)

#chunk("flow: a_chunk_built_by_code_is_attributed_to_itself", ````rust
#[test]
fn a_chunk_built_by_code_is_attributed_to_itself() {
    let body = "#for i in range(2) [\n  #file(\"gen-\" + str(i) + \".py\", ```py\n  print(#i)\n  ```)\n]\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/gen-0.py").exists());
    assert!(dir.join("out/gen-1.py").exists());

    let mapped = lp(
        &dir,
        &["map", "--file", "gen-0.py", "--line", "1", "--out", "out"],
    );
    assert!(
        stdout(&mapped).starts_with("chunk ⟪gen-0.py⟫, line 1 of it"),
        "{}",
        stdout(&mapped)
    );
}
````)

#chunk("flow: the_declaration_is_where_the_line_lives", ````rust
#[test]
fn the_declaration_is_where_the_line_lives() {
    let (_guard, _dir, text) = project(DOC);
    assert!(line_of(&text, "#chunk(\"imports\"") > 0);
    assert!(line_of(&text, "print('two')") > 0);
}
````)

=== tests/lazy.rs — what a pass touches

The contract of `lp watch`, tested without a watcher: a pass is a function, and what matters is
which bytes it writes and which it leaves alone. The mtime assertions are the reason the file
exists — cargo wakes on an mtime, not on a diff.

#file("tests/lazy.rs", ````rust
<<lazy: the fixtures and helpers>>

<<lazy: a_pass_does_not_touch_files_that_did_not_change>>

<<lazy: only_the_affected_output_is_rewritten>>

<<lazy: a_half_written_document_is_not_tangled>>

<<lazy: map_works_in_both_directions>>

<<lazy: unused_fragment_warns_without_failing>>
````)

The cases, in the order they appear:

- `a_pass_does_not_touch_files_that_did_not_change` — the first pass writes, the second rewrites nothing at all
- `only_the_affected_output_is_rewritten` — editing one document rewrites only the files that changed
- `a_half_written_document_is_not_tangled` — a document that does not evaluate leaves the previous output in place
- `map_works_in_both_directions` — `lp map` answers forwards and backwards
- `unused_fragment_warns_without_failing` — a fragment nobody references is a warning, not a failure

#chunk("lazy: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../typst/lp.typ");

const DOC: &str = concat!(
    "\
= Demo

#file(\"main.py\", ```py
",
    "<<imports>>\n",
    "<<body>>\n",
    "\
```)

#chunk(\"imports\", ```py
import sys
```)

#chunk(\"body\", ```py
print('one')
```)

#chunk(\"body\", ```py
print('two')
```)
",
);

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn write_doc(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = format!(
        "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
    );
    std::fs::write(dir.join(name), text).expect("doc");
}

fn project() -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "demo.typ", DOC);
    write_doc(
        dir.path(),
        "second.typ",
        "#file(\"other.py\", ```py\nprint('second')\n```)\n",
    );
    let path = dir.path().to_path_buf();
    (dir, path)
}

fn modified(path: &Path) -> std::time::SystemTime {
    std::fs::metadata(path)
        .expect("metadata")
        .modified()
        .expect("mtime")
}
````)

#chunk("lazy: a_pass_does_not_touch_files_that_did_not_change", ````rust
#[test]
fn a_pass_does_not_touch_files_that_did_not_change() {
    let (_guard, dir) = project();
    let first = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(first.status.success(), "{}", stderr(&first));
    assert!(stdout(&first).contains("wrote  main.py"));
    assert!(stdout(&first).contains("wrote  other.py"));

    let before = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.lpmap.json")),
    );
    std::thread::sleep(std::time::Duration::from_millis(30));

    let second = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(second.status.success(), "{}", stderr(&second));
    assert!(
        !stdout(&second).contains("wrote"),
        "nothing should be rewritten: {}",
        stdout(&second)
    );

    let after = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.lpmap.json")),
    );
    assert_eq!(before, after, "a no-op pass must not touch mtimes");
}
````)

#chunk("lazy: only_the_affected_output_is_rewritten", ````rust
#[test]
fn only_the_affected_output_is_rewritten() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"])
            .status
            .success()
    );

    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("print('two')", "print('three')"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("wrote  main.py"), "{report}");
    assert!(
        !report.contains("wrote  other.py"),
        "the untouched document must not be rewritten: {report}"
    );
    assert!(
        std::fs::read_to_string(dir.join("out/main.py"))
            .expect("main")
            .contains("print('three')")
    );
}
````)

#chunk("lazy: a_half_written_document_is_not_tangled", ````rust
#[test]
fn a_half_written_document_is_not_tangled() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    let good = std::fs::read_to_string(dir.join("out/main.py")).expect("main");

    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("#file(\"main.py\", ```py", "#file(\"main.py\", `"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(
        !output.status.success(),
        "a document that does not evaluate must not be tangled"
    );
    let message = stderr(&output);
    assert!(message.contains("did not evaluate"), "{message}");
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
        good
    );
}
````)

#chunk("lazy: map_works_in_both_directions", ````rust
#[test]
fn map_works_in_both_directions() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let forward = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(forward.status.success(), "{}", stderr(&forward));
    assert!(
        stdout(&forward).starts_with("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stdout(&forward)
    );

    let reverse = lp(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("main.py:3"),
        "{}",
        stdout(&reverse)
    );
}
````)

#chunk("lazy: unused_fragment_warns_without_failing", ````rust
#[test]
fn unused_fragment_warns_without_failing() {
    let (_guard, dir) = project();
    write_doc(
        dir.as_path(),
        "demo.typ",
        &format!("{DOC}\n#chunk(\"never-used\", ```py\nprint('dead')\n```)\n"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪never-used⟫ is never referenced"),
        "{}",
        stderr(&output)
    );
}
````)

=== tests/metadata.rs — what the document declares

The tests for the one thing the tool cannot work out for itself — and for what the tool has to
bring with it while asking. Most of them pin the consequences of asking Typst rather than parsing
the source: a chunk can come from a loop, from
an `#include`d chapter, or from a document whose show rule styles raw blocks away — and all of
those still declare themselves.

#file("tests/metadata.rs", ````rust
<<metadata: the fixtures and helpers>>

<<metadata: a_styling_show_rule_does_not_hide_a_chunk>>

<<metadata: a_chapter_is_tangled_without_being_listed>>

<<metadata: the_document_reports_chunks_no_parser_could_find>>

<<metadata: a_document_that_does_not_evaluate_says_so>>

<<metadata: a_document_outside_the_working_directory_can_be_tangled>>

<<metadata: a_declaration_of_an_unknown_kind_is_an_error>>

<<metadata: a_document_without_declarations_says_what_to_do>>
<<metadata: a_document_needs_nothing_but_itself>>
````)

The cases, in the order they appear:

- `a_styling_show_rule_does_not_hide_a_chunk` — a document whose show rule styles raw blocks away still declares its chunks
- `a_chapter_is_tangled_without_being_listed` — an `#include`d chapter's roots are tangled, and its fragment is visible to its parent
- `the_document_reports_chunks_no_parser_could_find` — chunks built by a loop are reported and tangled — the case no parser could find
- `a_document_that_does_not_evaluate_says_so` — a Typst error is reported as `did not evaluate`, with Typst's own message
- `a_document_outside_the_working_directory_can_be_tangled` — a document outside the working directory works, and no wrapper file is left behind
- `a_declaration_of_an_unknown_kind_is_an_error` — a metadata record with an unknown kind is refused instead of defaulting
- `a_document_without_declarations_says_what_to_do` — a document with no declarations is told to import the package
- `a_document_needs_nothing_but_itself` — a document that imports the package by name tangles in a directory holding nothing else (D21)

#chunk("metadata: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../typst/lp.typ");

fn typst_available() -> bool {
    Command::new("typst")
        .arg("--version")
        .output()
        .is_ok_and(|output| output.status.success())
}

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn write(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.join(name),
        format!(
            "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
        ),
    )
    .expect("doc");
}
````)

#chunk("metadata: a_styling_show_rule_does_not_hide_a_chunk", ````rust
#[test]
fn a_styling_show_rule_does_not_hide_a_chunk() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    write(
        dir.path(),
        "styled.typ",
        "#show raw.where(block: true): it => [styled away]\n\n#chunk(\"styled\", ```py\nprint('styled')\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "styled.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("styled"), "{report}");
    assert!(report.contains("print('styled')"), "{report}");
}
````)

#chunk("metadata: a_chapter_is_tangled_without_being_listed", ````rust
#[test]
fn a_chapter_is_tangled_without_being_listed() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write(dir.path(), "book.typ", "= Book\n#include \"chapter.typ\"\n");
    write(
        dir.path(),
        "chapter.typ",
        "= Chapter\n\n#file(\"src/main.py\", ```py\nprint('from a chapter')\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "book.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print('from a chapter')\n"
    );

    let mapped = lp(
        &path,
        &[
            "map",
            "--file",
            "src/main.py",
            "--line",
            "1",
            "--out",
            "out",
        ],
    );
    assert!(
        stdout(&mapped).starts_with("chunk ⟪src/main.py⟫, line 1 of it"),
        "{}",
        stdout(&mapped)
    );
}
````)

#chunk("metadata: the_document_reports_chunks_no_parser_could_find", ````rust
#[test]
fn the_document_reports_chunks_no_parser_could_find() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write(
        dir.path(),
        "dynamic.typ",
        "#file(\"src/main.py\", ```py\n<<part-0>>\n```)\n\n#for i in range(2) [\n  #chunk(\"part-\" + str(i), ```py\n  print(#i)\n  ```)\n]\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "dynamic.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(
        report.contains("part-0") && report.contains("part-1"),
        "{report}"
    );

    let tangled = lp(&path, &["tangle", "dynamic.typ", "--out", "out"]);
    assert!(tangled.status.success(), "{}", stderr(&tangled));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print(#i)\n"
    );
}
````)

#chunk("metadata: a_document_that_does_not_evaluate_says_so", ````rust
#[test]
fn a_document_that_does_not_evaluate_says_so() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("broken.typ"),
        "= Broken\n\n#undefined-thing(1)\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "broken.typ"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("did not evaluate"), "{message}");
    assert!(
        message.contains("undefined-thing"),
        "typst's own diagnostic: {message}"
    );
}
````)

#chunk(
  "metadata: a_document_outside_the_working_directory_can_be_tangled",
  ````rust
  #[test]
  fn a_document_outside_the_working_directory_can_be_tangled() {
      if !typst_available() {
          eprintln!("skipping: typst is not on PATH");
          return;
      }

      let documents = TempDir::new().expect("documents");
      write(
          documents.path(),
          "book.typ",
          "#file(\"src/main.py\", ```py\nprint('elsewhere')\n```)\n",
      );

      let workdir = TempDir::new().expect("workdir");
      let doc = documents.path().join("book.typ");
      let out = workdir.path().join("out");
      let output = lp(
          workdir.path(),
          &[
              "tangle",
              doc.to_str().expect("utf8"),
              "--out",
              out.to_str().expect("utf8"),
          ],
      );
      assert!(output.status.success(), "{}", stderr(&output));
      assert_eq!(
          std::fs::read_to_string(out.join("src/main.py")).expect("output"),
          "print('elsewhere')\n"
      );

      let leftovers: Vec<String> = std::fs::read_dir(documents.path())
          .expect("read_dir")
          .flatten()
          .map(|entry| entry.file_name().to_string_lossy().to_string())
          .filter(|name| name.starts_with(".lp-decl-"))
          .collect();
      assert!(
          leftovers.is_empty(),
          "wrapper files left behind: {leftovers:?}"
      );
  }
  ````,
)

#chunk("metadata: a_declaration_of_an_unknown_kind_is_an_error", ````rust
#[test]
fn a_declaration_of_an_unknown_kind_is_an_error() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("odd.typ"),
        "= Odd\n\n#metadata((lp: \"sideways\", name: \"x\", text: \"y\"))<lp-decl>\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "odd.typ"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("unknown declaration kind"),
        "{}",
        stderr(&output)
    );
}
````)

#chunk("metadata: a_document_needs_nothing_but_itself", ````rust
#[test]
fn a_document_needs_nothing_but_itself() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("alone.typ"),
        "#import \"@local/lp:0.1.0\": chunk, file, show-rule\n#show: show-rule\n\n#file(\"main.py\", ```py\n<<body>>\n```)\n\n#chunk(\"body\", ```py\nprint('alone')\n```)\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "alone.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/main.py")).expect("output"),
        "print('alone')\n"
    );
}
````)

#chunk("metadata: a_document_without_declarations_says_what_to_do", ````rust
#[test]
fn a_document_without_declarations_says_what_to_do() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("plain.typ"),
        "= Just prose\n\n```py\nprint('not a chunk')\n```\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "plain.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stdout(&output).trim().is_empty(),
        "nothing is still an answer"
    );
}
````)

=== tests/owned.rs — who owns the output directory

Ownership is the part of the tool that can destroy a user's work if it is wrong, so it has the
most cases per line of code: what is accounted for, what is not, which ignore rules count, and
what `--check` and `--delete` each do.

#file("tests/owned.rs", ````rust
<<owned: the fixtures and helpers>>

<<owned: a_dropped_declaration_is_an_error_until_it_is_resolved>>

<<owned: declared_files_are_accounted_for>>

<<owned: the_pattern_language_is_gitignores>>

<<owned: a_deeper_ignore_file_can_take_a_file_back>>

<<owned: the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray>>

<<owned: a_git_directory_is_ordinary_content>>

<<owned: check_reports_a_stray_without_removing_it>>

<<owned: deleting_a_foreign_subtree_takes_one_line_and_one_command>>

<<owned: without_a_declaration_a_stray_is_still_an_error>>

<<owned: a_missing_output_directory_is_not_an_io_error>>
<<owned: the_unpacked_package_is_not_content>>
````)

The cases, in the order they appear:

- `a_dropped_declaration_is_an_error_until_it_is_resolved` — deleting a root strands its file as an unaccounted error, with `--delete` as the way out
- `declared_files_are_accounted_for` — files and directories listed in `.lpignore` are left alone
- `the_pattern_language_is_gitignores` — `build/` and `**/*.log` behave exactly as they do in git
- `a_deeper_ignore_file_can_take_a_file_back` — a nested ignore file decides for its own directory, deepest winning
- `the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray` — the map is the tool's own output and the ignore file protects itself, but every other dotfile is
- `a_git_directory_is_ordinary_content` — `.git/` is not special-cased, so it has to be declared like anything else
- `check_reports_a_stray_without_removing_it` — `--check` lists a stray and changes nothing
- `deleting_a_foreign_subtree_takes_one_line_and_one_command` — one compressed entry, one `--delete`, and a subtree is gone
- `without_a_declaration_a_stray_is_still_an_error` — with no `.lpignore` at all, strays are still errors
- `a_missing_output_directory_is_not_an_io_error` — a missing output file is drift, not an I/O failure
- `the_unpacked_package_is_not_content` — the directory the tool unpacks its package into is never reported

#chunk("owned: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../typst/lp.typ");

const DOC: &str = "\
= Demo

#file(\"a.py\", ```py
print('a')
```)

#file(\"src/b.py\", ```py
print('b')
```)
";

const IGNORES: &str = "\
# files lp must not touch
handwritten.txt
build/
*.lock
# and the rules themselves: a hand-written ignore file is a file like any other, and a report that
# never saw it is how one survived the declaration that produced it. A document says this by
# declaring the file instead, which is what this repository's does.
.lpignore
";

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = format!(
        "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
    );
    std::fs::write(dir.join(name), &text).expect("doc");
    text
}

fn tangled(declaration: &str, extra: &[(&str, &str)]) -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    if !declaration.is_empty() {
        std::fs::create_dir_all(dir.path().join("out")).expect("out");
        let declaration = format!("{declaration}\n.lpignore\n");
        std::fs::write(dir.path().join("out/.lpignore"), declaration).expect("ignore file");
    }
    for (relative, contents) in extra {
        let path = dir.path().join("out").join(relative);
        std::fs::create_dir_all(path.parent().expect("parent")).expect("dir");
        std::fs::write(&path, contents).expect("file");
    }
    let path = dir.path().to_path_buf();
    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    (dir, path)
}

fn without_b() -> String {
    DOC.replace("\n#file(\"src/b.py\", ```py\nprint('b')\n```)\n", "")
}
````)

#chunk("owned: a_dropped_declaration_is_an_error_until_it_is_resolved", ````rust
#[test]
fn a_dropped_declaration_is_an_error_until_it_is_resolved() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    write_doc(&dir, "doc.typ", &without_b());
    assert!(dir.join("out/src/b.py").exists());

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("nothing accounts for"), "{message}");
    assert!(message.contains("src/b.py"), "{message}");
    assert!(
        message.contains("lp unaccounted --delete"),
        "the remedy belongs there: {message}"
    );
    assert!(
        dir.join("out/src/b.py").exists(),
        "nothing is removed for you"
    );

    let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(report.status.code(), Some(1));
    assert!(stdout(&report).contains("src/b.py"), "{}", stdout(&report));

    let mut declaration = std::fs::read_to_string(dir.join("out/.lpignore")).expect("ignore");
    declaration.push_str("src/b.py\n");
    std::fs::write(dir.join("out/.lpignore"), &declaration).expect("ignore");
    let declared = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(declared.status.success(), "{}", stderr(&declared));
    assert!(dir.join("out/src/b.py").exists(), "declared, so kept");

    std::fs::write(dir.join("out/.lpignore"), IGNORES).expect("ignore");
    let deleted = lp(
        &dir,
        &["unaccounted", "doc.typ", "--out", "out", "--delete"],
    );
    assert!(deleted.status.success(), "{}", stderr(&deleted));
    assert!(
        stdout(&deleted).contains("deleted src/b.py"),
        "{}",
        stdout(&deleted)
    );
    assert!(!dir.join("out/src/b.py").exists());
    assert!(
        !dir.join("out/src").exists(),
        "the emptied directory goes too"
    );

    let clean = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(clean.status.success(), "{}", stderr(&clean));
    assert!(
        !dir.join("out/src/.lpmap.json").exists(),
        "the stale map is gone"
    );
    assert!(
        lp(&dir, &["tangle", "doc.typ", "--out", "out", "--check"])
            .status
            .success()
    );
}
````)

#chunk("owned: declared_files_are_accounted_for", ````rust
#[test]
fn declared_files_are_accounted_for() {
    let (_guard, dir) = tangled(
        IGNORES,
        &[
            ("handwritten.txt", "kept by hand"),
            ("build/art.txt", "not ours"),
            ("Cargo.lock", "foreign"),
        ],
    );
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !stderr(&output).contains("nothing accounts for"),
        "{}",
        stderr(&output)
    );
    for kept in [
        "out/handwritten.txt",
        "out/build/art.txt",
        "out/Cargo.lock",
        "out/.lpignore",
    ] {
        assert!(dir.join(kept).exists(), "{kept} must survive");
    }
}
````)

#chunk("owned: the_pattern_language_is_gitignores", ````rust
#[test]
fn the_pattern_language_is_gitignores() {
    let (_guard, dir) = tangled(
        "build/\n**/*.log\n",
        &[
            ("build/art.txt", "not ours"),
            ("deep/nested/app.log", "log"),
        ],
    );
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/build/art.txt").exists(), "directory pattern");
    assert!(dir.join("out/deep/nested/app.log").exists(), "** pattern");
}
````)

#chunk("owned: a_deeper_ignore_file_can_take_a_file_back", ````rust
#[test]
fn a_deeper_ignore_file_can_take_a_file_back() {
    let (_guard, dir) = tangled(
        "src/*\n",
        &[
            ("src/stale.py", "ours after all"),
            ("src/other.py", "protected"),
        ],
    );
    std::fs::write(dir.join("out/src/.lpignore"), "!stale.py\n").expect("ignore");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("src/stale.py"),
        "{}",
        stderr(&output)
    );
    assert!(dir.join("out/src/other.py").exists(), "still protected");
}
````)

#chunk(
  "owned: the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray",
  ````rust
  #[test]
  fn the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray() {
      let (_guard, dir) = tangled("kept.dot\n", &[("kept.dot", "x")]);
      std::fs::write(dir.join("out/stray.cache"), "not listed").expect("file");

      let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
      assert!(
          !output.status.success(),
          "an unlisted dotfile is a stray like any other"
      );
      assert!(
          stderr(&output).contains("stray.cache"),
          "{}",
          stderr(&output)
      );
      assert!(
          dir.join("out/.lpmap.json").exists(),
          "the map is the tool's own output, so it is accounted for by name"
      );
      assert!(
          dir.join("out/.lpignore").exists(),
          "and the ignore file is accounted for by the rule inside it"
      );
      assert!(dir.join("out/kept.dot").exists(), "listed, so kept");
  }
  ````,
)

#chunk("owned: a_git_directory_is_ordinary_content", ````rust
#[test]
fn a_git_directory_is_ordinary_content() {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    std::fs::create_dir_all(dir.path().join("out/.git")).expect("out");
    std::fs::write(dir.path().join("out/.lpignore"), IGNORES).expect("ignore");
    std::fs::write(dir.path().join("out/.git/config"), "[core]\n").expect("file");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success(), "not special-cased");
    assert!(
        stderr(&output).contains(".git/config"),
        "{}",
        stderr(&output)
    );

    let (_guard, declared) = tangled(".git/\n", &[(".git/config", "[core]\n")]);
    assert!(declared.join("out/.git/config").exists());
}
````)

#chunk("owned: check_reports_a_stray_without_removing_it", ````rust
#[test]
fn check_reports_a_stray_without_removing_it() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::write(dir.join("out/leftover.py"), "stale").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out", "--check"]);
    assert!(!output.status.success(), "drift");
    assert!(
        stderr(&output).contains("leftover.py"),
        "{}",
        stderr(&output)
    );
    assert!(
        dir.join("out/leftover.py").exists(),
        "--check changes nothing"
    );
}
````)

#chunk(
  "owned: deleting_a_foreign_subtree_takes_one_line_and_one_command",
  ````rust
  #[test]
  fn deleting_a_foreign_subtree_takes_one_line_and_one_command() {
      let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
      std::fs::create_dir_all(dir.join("out/vendor/nested")).expect("dir");
      std::fs::write(dir.join("out/vendor/a.txt"), "x").expect("file");
      std::fs::write(dir.join("out/vendor/nested/b.txt"), "x").expect("file");

      let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
      assert_eq!(report.status.code(), Some(1));
      assert!(
          stdout(&report).contains("vendor/a.txt"),
          "{}",
          stdout(&report)
      );

      let deleted = lp(
          &dir,
          &["unaccounted", "doc.typ", "--out", "out", "--delete"],
      );
      assert!(deleted.status.success(), "{}", stderr(&deleted));
      assert!(!dir.join("out/vendor").exists());
      assert!(dir.join("out/handwritten.txt").exists());
  }
  ````,
)

#chunk("owned: without_a_declaration_a_stray_is_still_an_error", ````rust
#[test]
fn without_a_declaration_a_stray_is_still_an_error() {
    let (_guard, dir) = tangled("", &[]);
    std::fs::write(dir.join("out/stray.txt"), "who put this here").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("stray.txt"), "{}", stderr(&output));
    assert!(dir.join("out/stray.txt").exists(), "and nothing removes it");
}
````)

#chunk("owned: the_unpacked_package_is_not_content", ````rust
#[test]
fn the_unpacked_package_is_not_content() {
    let (_guard, dir) = tangled("", &[(".lp/local/lp/0.1.0/lib.typ", "the package")]);
    assert!(dir.join("out/.lp/local/lp/0.1.0/lib.typ").exists());
}
````)

#chunk("owned: a_missing_output_directory_is_not_an_io_error", ````rust
#[test]
fn a_missing_output_directory_is_not_an_io_error() {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out", "--check"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("STALE  a.py (file missing)"),
        "{}",
        stderr(&output)
    );
    assert!(!path.join("out").exists(), "--check writes nothing at all");
}
````)

=== tests/self.rs — the invariant that makes self-hosting real

One case, and it is the one that keeps the rest honest: the binary re-tangles this document
into the working tree and insists on finding no difference. Every case above is about some
other document; this one is about this one, and it is what makes editing `src/` by hand
impossible.

#file("tests/self.rs", ````rust
<<self: the fixtures and helpers>>

<<self: the_document_regenerates_the_sources_we_are_running>>
````)

The cases, in the order they appear:

- `the_document_regenerates_the_sources_we_are_running` — the binary reproduces the sources it was built from, byte for byte

#chunk("self: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::Command;
````)

#chunk("self: the_document_regenerates_the_sources_we_are_running", ````rust
#[test]
fn the_document_regenerates_the_sources_we_are_running() {
    let crate_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let map: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(crate_dir.join(".lpmap.json")).expect("the map beside the crate"),
    )
    .expect("the map is json");
    let document = match (
        map["book"]["directory"].as_str(),
        map["docs"]
            .as_array()
            .and_then(|docs| docs.first())
            .and_then(|doc| doc.as_str()),
    ) {
        (Some(book), Some(doc)) => format!("{book}/{doc}"),
        _ => panic!("the map names neither a book nor a document: {map}"),
    };

    let output = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["tangle", &document, "--out", ".", "--check"])
        .current_dir(crate_dir)
        .output()
        .expect("run lp");

    assert!(
        output.status.success(),
        "--check reported drift between lp.typ and the sources it generated:\n{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}
````)

= The build environment

The toolchain is a prerequisite rather than an output: without typst there are no declarations to
read, and without cargo there is no binary, but a document cannot ship the tools that read it. So
this chapter is about what the crate *needs* — its name, its dependencies, the versions — and
about the one thing a person has to have before any of it runs.

What that is, concretely: `typst`, and a Rust toolchain complete enough to link — `cargo`, `rustc`
and a C linker. On a machine with a system Rust that is all there is to it; where the tools are not
installed, they can be borrowed for one command:

```sh
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo test
```

A repository that carried its own environment would need a tracked file the document could not
produce (nix will not evaluate a flake whose files are not in git), so the environment lives
outside this document: it is what the person reading has, not something the document hands over.

#file("Cargo.toml", ````toml
<<env: what the package is>>

<<env: the runtime dependencies>>

<<env: what only the tests need>>
````)

The dependencies are a decision like any other, and the policy (D7) is that a mature crate
beats a hand-written wheel: clap for the command line, ignore for the ignore rules, miette for
the error rendering, notify and its debouncer for the watcher, regex for the diagnostic shapes,
serde for the maps. `tempfile` is the only one the tests need, which is why it is in its own
table.

#chunk("env: what the package is", ````toml
[package]
name = "lp"
version = "0.1.0"
edition = "2024"
publish = false
description = "Typst-based literate programming: tangle source files out of a .typ document"
````)

#chunk("env: the runtime dependencies", ````toml
[dependencies]
include_dir = "0.7"
lopdf = { version = "0.45", default-features = false }
clap = { version = "4", features = ["derive"] }
ignore = "0.4.33"
miette = { version = "7", features = ["fancy"] }
notify = "8.2.0"
notify-debouncer-full = "0.7.0"
regex = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"
````)

#chunk("env: what only the tests need", ````toml
[dev-dependencies]
serde_json = "1"
tempfile = "3"
````)

= The program's own pipeline

Everything above is about this repository: one document, its tree, and the seed that makes the first
build possible. The program that comes out is a program, though, and it has a pipeline of its own —
written where it belongs, which is in the program rather than in the repository that produces it.

So these four files are output too. They are declared here, tangled with everything else, and carried
onto the seed branch, which is where they take effect: the branch that holds a generation is the branch
whose copy of a workflow file GitHub reads.

#file("lp.nix", ````nix
<<nix: the package>>
````)

#file("flake.nix", ````nix
<<nix: the flake>>
````)

#file(".github/workflows/check.yml", ````yaml
<<nix: the workflow>>
````)

#file("zizmor.yml", ````yaml
<<nix: the zizmor policy>>
````)

#file("typos.toml", ````toml
<<nix: the words typos should leave alone>>
````)

== The package, the way crane would write it

`crane` builds it, and what that buys is one thing said three ways: the dependency graph is compiled once
and every later step reuses it. A `typst`-sized graph rebuilt for each of lint, test and build would make
the checks below too expensive to keep, which is the same as not having them.

Four things here are this tool's own, and every one of them was found by a failure:

- *Typst is a runtime dependency and a test dependency.* Tangling asks the document for its declarations,
  so both the binary and the tests that tangle have to find `typst` — the wrapper for the first, an input
  for the second. A package that works only when the user happens to have the right thing on their `PATH`
  is not a package.
- *`src` is the whole tree.* Not cargo's idea of a source: `src/metadata.rs` reads the package with
  `include_str!`, `src/embedded.rs` reads the book with `include_dir!`, and
  `the_document_regenerates_the_sources_we_are_running` re-tangles the book against the tree it is running
  in. That last one is why the filtering below is applied to the *dependencies* and not to the crate: the
  test is an assertion about the tree, so the tree has to be the input. It runs in a build of the tree as
  much as in the repository, which is what D15 made true when it rewrote the test to read the map beside
  the crate instead of a path above it.
- *`CARGO_HOME` is moved out of the source.* Crane puts it in `$PWD/.cargo-home`, and the same test asks
  whether the output directory holds anything the document does not account for. A build tool writing into
  the directory under test makes that question unanswerable, so it writes elsewhere. It has to be set from a
  *hook* rather than as a derivation attribute, and that is where a platform constant hides: the first
  version wrote `/build`, which is where Linux puts its temporary build directory and a read-only,
  non-existent one on Darwin. The six matrix entries that had never been built before are what found that —
  on macOS only.
- *The round trip is a check rather than a condition of the build.* Rendering the document and reading the
  book back out of both carriers is a thing to assert, not a thing to make someone pay for by installing
  `lp`.
- *The package does not run the tests.* `doCheck = false` there and a `test` check beside it, because a
  package that ran them as well would fail before a reader could see *which* test broke.

#chunk("nix: the package", ````nix
{ inputs }:
{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      craneLib = inputs.crane.mkLib pkgs;

      cargoSources = craneLib.fileset.commonCargoSources ./.;

      src = ./.;

      cargoArtifacts = craneLib.buildDepsOnly {
        src = lib.fileset.toSource {
          root = ./.;
          fileset = cargoSources;
        };
      };

      cargoEnv = {
        prePatch = ''export CARGO_HOME="$TMPDIR/cargo-home"'';
      };

      lp = craneLib.buildPackage (
        cargoEnv
        // {
          inherit src cargoArtifacts;

          doCheck = false;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postInstall = ''
            wrapProgram $out/bin/lp --prefix PATH : ${lib.makeBinPath [ pkgs.typst ]}
          '';
        }
      );

      roundtrip = pkgs.runCommand "lp-roundtrip" { nativeBuildInputs = [ pkgs.typst ]; } ''
        work=$PWD/work
        mkdir -p "$work/src" "$work/run"

        for file in lp.typ README.md .gitignore; do
          cp "${./book}/$file" "$work/src/$file"
          cp "${./book}/$file" "$work/run/$file"
        done

        ( cd "$work/run" && ${lp}/bin/lp weave lp.typ ../lp.pdf && ${lp}/bin/lp weave lp.typ ../lp.html --features html )

        for format in pdf html; do
          ${lp}/bin/lp extract --format "$format" "$work/lp.$format" --out "$work/back-$format"
          diff -r "$work/src" "$work/back-$format"
        done
        touch "$out"
      '';

      gates = {
        package = lp;

        test = craneLib.cargoTest (
          cargoEnv
          // {
            inherit src cargoArtifacts;

            nativeBuildInputs = [ pkgs.typst ];
          }
        );

        clippy = craneLib.cargoClippy (
          cargoEnv
          // {
            inherit src cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          }
        );

        inherit roundtrip;
      };
    in
    {
      packages = {
        inherit lp;
        default = lp;
      };

      checks = gates // {
        devShell = config.devShells.default;
      };

      treefmt = {
        projectRootFile = "flake.nix";

        programs = {
          nixfmt.enable = true;
          taplo.enable = true;
          rustfmt.enable = true;
          typstyle.enable = true;
          mdformat.enable = true;
          jsonfmt.enable = true;

          # Spelling, with a list of words rather than a list of files: see the paragraph above.
          typos = {
            enable = true;
            configFile = "typos.toml";
          };

          yamlfmt = {
            enable = true;
            settings.formatter.retain_line_breaks = true;
          };
          shfmt = {
            enable = true;
            indent_size = 4;
          };

          actionlint.enable = true;
          zizmor.enable = true;
          shellcheck.enable = true;
          deadnix.enable = true;
          statix.enable = true;
        };

        settings.formatter.shfmt.options = [
          "-sr"
          "-kp"
        ];

        settings.formatter.zizmor.options = [
          "--min-severity"
          "high"
        ];
      };

      devShells.default = craneLib.devShell {
        checks = gates;
        packages = [
          config.treefmt.build.wrapper
          pkgs.typst
        ];
      };
    };
}
````)

== The flake, and the systems it is for

Three systems, named once, and `flake-parts` is the skeleton that makes naming them once enough. Five
inputs, and each of them is told to follow ours rather than fetch a copy of nixpkgs of its own; crane
brings no inputs at all, which is how a library that does this much costs one line here. That flatness is
not decoration — a second nixpkgs in the graph is a second `rustc`, and the one place where versions
really matter is the compiler.

The checks are the point of the flake. One per promise, so CI fails on the promise and not on "the build":

- `package` — it builds.
- `test` — it passes its own tests, including the one about the document regenerating this tree.
- `clippy` — it is lint-clean, with warnings denied.
- `treefmt` — every file a formatter has an opinion about is formatted, and the formatters own the
  document's own code as much as the crate's. (No `cargoFmt`: two tools disagreeing about rustfmt's
  options is worse than either one alone.)
- `roundtrip` — the book survives both carriers.
- `devShell` — the shell can be constructed, because a shell that cannot be built is a shell nobody uses.

`nix flake check` builds every one of those for the machine it runs on and evaluates the rest, so a typo in
the Darwin branch of anything is caught on Linux. And because the list *is* an attribute of the flake, the
workflow never repeats it: `githubActions` renders it into a build matrix, which is how the three systems
stop being a claim and become something that ran.

#chunk("nix: the flake", ````nix
{
  description = "lp: literate programming for Typst documents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";

    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        imports = [
          (import ./lp.nix { inherit inputs; })
          inputs.treefmt-nix.flakeModule
        ];

        flake.githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
          inherit (config.flake) checks;
        };
      }
    );
}
````)

== The workflow

Three jobs. `matrix` asks the flake which checks exist, so the list of them lives in one place and adding
one is an edit to `lp.nix`. `check` builds each of them on the runner its system calls for — the matrix
knows that `aarch64-linux` means an arm runner and `aarch64-darwin` means a Mac, so the three systems are
three native builds rather than one build and two guesses. It also does not stop at the first failure,
because one failing check should not hide the other seventeen. `prove` runs the other direction: it unpacks
the book the binary carries, tangles it, and runs this tree's own checks in what comes out, which is what
catches a document that no longer reproduces its tree.

The cache is where a pipeline like this earns its keep — a Rust build with Nix is hundreds of derivations,
and the second run should download them instead of building them. The name is the Cachix cache this
repository pushes to; the token comes from a secret, because a signing key in a workflow file is a signing
key given away.

The workflow asks for `contents: read` and nothing more, because neither job writes; it hands the matrix
attribute in through the environment rather than into the shell; it passes `--no-update-lock-file`, because
the lock is part of the book the tree carries and a lock that does not match is drift to fail on rather than
one to quietly resolve; and it keeps a policy file beside it. Each
of those is a finding from the linter, and the linter runs here — in `treefmt`, on every build — rather than
in a script someone remembers to call.

#chunk("nix: the workflow", ````yaml
name: check

permissions:
  contents: read

on:
  push:
    branches: [tangled]
  workflow_dispatch:
  schedule:
    - cron: "0 6 * * *"

jobs:
  matrix:
    runs-on: ubuntu-24.04
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - id: set-matrix
        name: ask the flake which checks exist
        run: echo "matrix=$(nix eval --json '.#githubActions.matrix')" >> "$GITHUB_OUTPUT"

  check:
    name: ${{ matrix.name }} (${{ matrix.system }})
    needs: matrix
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.matrix.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - uses: cachix/cachix-action@v17
        with:
          name: linyinfeng
          signingKey: ${{ secrets.CACHIX_SIGNING_KEY }}
      - run: nix build -L --no-update-lock-file ".#$ATTR"
        env:
          ATTR: ${{ matrix.attr }}

  prove:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - uses: cachix/cachix-action@v17
        with:
          name: linyinfeng
          signingKey: ${{ secrets.CACHIX_SIGNING_KEY }}
      - run: nix build -L --no-update-lock-file .#lp
      - run: ./result/bin/lp self prove /tmp/proved
````)

The policy file travels with the tree for the same reason the workflow does: `zizmor` now runs *in* the
build, as one of treefmt's programs, so what it reads has to be part of what the tree is. It is the same
file the local `gates` script points `zizmor` at, which is why it argues for the `@vN` pins only once.

`typos` runs there too, and its configuration is a list of *words* rather than a list of files, which is not
the obvious choice. Excluding a file cannot work here: the words it objects to are `flate` and `writeable`,
both of which appear in the `Cargo.lock` this document quotes verbatim — and a quoted file is not a path any
more, it is the document. A word list is the only mechanism that reaches a word wherever it is written, and
the words are the crate names `flate2` and `writeable`, so the list is short. Note that `typos` flags the
word it matched and not the token: `flate` inside `flate2`, which is why allowing `flate2` would change
nothing.

#chunk("nix: the words typos should leave alone", ````toml
[default.extend-words]
flate = "flate"
writeable = "writeable"
````)

#chunk("nix: the zizmor policy", ````yaml

rules:
  unpinned-uses:
    disable: true
````)

= What this repository carries

`lp` treats its output directory as its own and refuses to guess: every file under it
is produced by a declaration or listed in the `.lpignore` of its directory. Here the
output directory is the repository root, so what this document does *not* produce is
whatever is not the crate, the package or a control file — and the lock
files cargo and nix maintain, which no chunk has any business owning.

#file(".gitignore", ````gitignore
.lp
target

````)

#file(".lpignore", ````gitignore
/.git

/target
````)

= What git is asked to ignore

Everything under `tangled/` is generated, so the whole directory is ignored: the crate, the
package, the protect list and the maps. What is tracked at the root is the document,
the pointer, the pipeline, and this file. `README.md` is that pointer, and there is one of it: a second name for
the same text is a second name that can drift, which is the whole reason this file's text is a
pointer. The `.gitignore` is written as the list itself — ignore everything, then allow these — so it
cannot fall out of step with what the repository is. The seed is not tracked in the working tree
either: it is the
`tangled` branch of this same repository, which is the one place output can live without being a file next to the
document.

= Starting from nothing

A fresh clone holds four things and nothing else: this document, the pointer at the root that leads
here, the `.gitignore`, which says exactly that — ignore everything, allow these — and the pipeline
that hands each generation to the seed branch. The seed is a branch as well, and there is nothing
else: everything beyond these is produced.
Everything else is produced
by tangling — except the one thing this document cannot produce for itself, the binary that reads
it, because the package has to exist before the document can be evaluated at all.

That is the seed, and it is not a file in the tree: it is a branch. One whole older generation — a
crate and the package it is built with — sits at its root, ready to unpack:

```sh
tangled_ref=$(git rev-parse --verify --quiet tangled || git rev-parse --verify --quiet origin/tangled)
mkdir -p tangled
git archive "$tangled_ref" | tar -x -C tangled     # the previous generation, into tangled/
git init -q tangled                                # the generated code gets its own history
cargo build --manifest-path tangled/Cargo.toml
./tangled/target/debug/lp tangle lp.typ            # writes to tangled/, next to the document
cargo test --manifest-path tangled/Cargo.toml
```

A clone is enough; there is no second remote to fetch from. `origin/tangled` is the fallback for the
case where the clone knows the branch only by that name.

These commands assume `typst` and `cargo` are on the path. This repository does not carry an
environment of its own: a flake in it would be a tracked file that the document could not produce,
since nix will not evaluate a flake whose files are not in git. Borrowing the tools for one command
is a line long — `nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo test
--manifest-path tangled/Cargo.toml` — and that is the whole of the story; there is no command that
assembles the environment for you.

The tangle writes to `tangled/` without being told to: when `--out` is not given it is the
directory `tangled` next to the document, because the document is what the output belongs to. The
older lp reads the declarations here and writes this generation over its own tree — crate, package,
protect list. Its own history is what makes it readable a generation later, which is the
whole trick: the seed was never a special artifact, only an older generation of this.

That tree is a copy that can be read on its own, and it is a repository, but it is not this
repository: nobody edits the generated code, and its first commit is a judgement about the program
rather than about the document. One generation per commit is worth recommending — the tree is a
whole program, so a diff across it says what the program did before and does now — and that is as
far as the recommendation goes. Nothing here commits, and nothing here should: when a generation is
worth keeping is the writer's call, not the tool's.

The tree declares its own ignore rules rather than leaving them to a reader: they say what the tool keeps
and what the build tools write, and a file that only changes when someone remembers to change it is a file
that goes stale — the published tree is built from a seed, and a hand-maintained file has no way to reach
it. Being output, it is written when it differs and compared by `--check` like everything else:

```gitignore
.lp
target

```

Write it, declare it in the protect list above next to `/.git` — they are the same kind of file,
settings of the inner repository rather than content of this document — and the tangle leaves it
alone.

After that the loop is the ordinary one: edit this document, tangle, test. While writing,

```sh
./tangled/target/debug/lp watch lp.typ --check-cmd 'cargo build --manifest-path tangled/Cargo.toml --message-format=short'
```

`tests/self.rs` is what keeps the loop honest: the binary this document builds has to be
able to reproduce the sources it was built from, so hand-editing `src/` or `tests/` fails
a test instead of quietly working.

One thing that trips people up once: this prose is Typst, not Markdown. Emphasis is one
star (`*like this*`); a doubled star is a warning, not bold. Inside a fence it does not
matter — that text is whatever its language says it is.

= Keeping the seed in step

The seed only ever reads, and it is output: the same tree the tangle writes, committed at the root
of its own branch instead of being kept in the working tree. Keeping it in step is part of building
this repository rather than part of using the tool: the pipeline does it on every change to the
document — it takes the previous generation as the seed, builds it, tangles this document, checks the
tree against it, and then hands the branch the result. Nothing about the generated code is checked
there: a program's tests are the program's business, not the document's. That business is written down
where it lives — the flake and the workflow further on are output too, and they describe the tree they
are tangled into. What this document can state is the property that has to hold —
the branch carries a generation that can read the document, and a generation only ever reads.

So it is output in the strict sense: never edited, never checked out, never worked in. A worktree of
it would be stale the moment the next generation is committed. Looking at it costs no worktree
either: `git show tangled:<path>` reads one file, `git archive tangled | tar -x -C <dir>` unpacks a
whole tree.

== What the branch carries, and what it does not

The branch carries what the tree's own repository commits: the declared files, `Cargo.lock`, and
the tree's own `.gitignore`. The lock file is the one file in the seed that no declaration produces
— a pinned resolution is a decision, not a derivation — and the `.gitignore` is a setting of the
inner repository, protected next to `.git` for that reason. Everything else the tangle writes stays
out, and each for a reason worth being able to say:

- `.lpmap.json`, in every directory that received a file. The tool classifies it as a *control
  file* rather than content — the same list `--check` exempts — and it is derived from the document
  alone. The first tangle of a fresh clone writes it back.
- `.lp/`, the copy of the package unpacked next to a document so Typst can import it. Also
  derived: it is the declaration of the package, unpacked.
- `target/`, which the build produces rather than this document.

So the seed is the program, not the state around it: a generation to read, to build, and — in the
one case where that matters — one to bootstrap from. Being a program is also the test: if the
bootstrap in "Starting from nothing" runs green from the branch alone, the branch carries enough,
and nothing else needs a rule.

Only one property is required of the seed: it must be a generation that can read this document, and
one generation behind is enough. Being the current one is better, so refresh it whenever the tree
changes — which is exactly what `--check` cannot tell you, since it guards the tree, not the
branch.

= The rules

These are not style preferences; each one was paid for.

- *Elegance is an admission requirement.* If the only way to build a feature is to
  search source text heuristically, or to parse Typst a second time, the feature is not
  built. That is how line-number mapping, label-as-chunk-name and static analysis of
  Typst were dropped.
- *The tool never parses Typst.* Its whole understanding is one `typst eval` reading the
  declaration stream.
- *No line numbers.* Typst's script layer has no source positions; provenance is
  chunk-level, and pretending otherwise would mean re-parsing.
- *Orthogonality.* No knowledge of any target language in the algorithms; language
  differences are data (the fence tag), never code.
- *Generated files stay out of git*, and only this document is edited: the crate, the package,
  the control files. The seed is output too, and lives on the `tangled` branch for
  bootstrap reasons — a fresh clone has no binary to tangle with. It is the same guarded tree, one
  generation behind.
- *An error points at a declaration*, never at a bare string: which chunk, and which
  line inside it.
- *Unexplained files are errors, deletion is explicit.* Everything under the output
  directory is produced by a declaration or listed in a `.lpignore`; `lp` never deletes
  anything by itself.
- *Only changed bytes are written, and a document that does not evaluate is not tangled.*
  The previous good output stays until the document is valid again.
- *The order is free and the language tag is data* (D18). Thought-first, progressive
  disclosure and logical consistency cannot be checked by a tool, so they are the
  writer's job: this book argues for them, and no check can do it instead.
- *The code carries no comments.* An explanation belongs in the prose that introduces the
  chunk — where it can be read in order, argued with, and moved when the design moves — and a
  comment is a second voice saying the same thing in a place a reader of this book never looks.
  This document is its own example: nothing it tangles has a comment in it, and the sentences that
  used to be comments are one paragraph up, in the chapter that introduces the code. The one
  banner that survives is `Cargo.lock`'s, and that one is cargo's — the document quotes the lock
  verbatim, so what cargo writes is what the document has to carry.
- *Dependencies are chosen from mature crates* (D7); every new one gets a line saying
  why. `typst` is a hard dependency of tangling (`LP_TYPST`, then `PATH`).

= The example, which is this document

A literate program is worth what its subject is worth. Forty lines can show the syntax — a reference
resolves, indentation survives, a compiler's complaint comes back with a chunk name — and can show none of
the decisions that make the practice worth the trouble: what belongs in one fragment, where the seams go,
what to do when the reference graph is deeper than a reader can hold in mind, and which corner you would
rather cut. A program that small never asks, so it never answers.

The decisions are here instead, because this document is a program rather than a description of one:

- *One source, two outputs.* `lp tangle lp.typ` writes the crate, the package and the control files;
  `lp weave lp.typ lp.pdf` renders what you are reading.
- *A document that reproduces its own tree*, checked by a test that re-tangles the book and compares it —
  `the_document_regenerates_the_sources_we_are_running`, which is also why the crate's source has to be
  the whole tree.
- *A seed that has to be able to read the next generation*, because a fresh clone has no binary to tangle
  with.
- *Six claims with a name each.* `package`, `test`, `clippy`, `treefmt`, `roundtrip`, `devShell` —
  `nix flake check` is the loud half of every claim this document makes, and it is not a script anyone has
  to remember to run.

Every command a demonstration would have shown you appears in the chapters above, applied to this document:
`lp tangle --check` for drift, `lp map` for which declaration produced a line, `lp explain` for a compiler's
complaint handed back to the chunk that caused it, and the pipeline that published the tree you are reading.
Read it front to back and the order is the design walk.

= Appendix: what is pinned

Two files in this tree are not the build tools' business, and they are not protected files either: a lock
file records *decisions* — which versions of everything, resolved once — and a decision belongs in the
document that made it. So they are declared here, quoted verbatim, tangled out like anything else, and
compared by `--check`.

That is the price, and it is worth naming: these two are edited by hand, because nothing else knows what
"the same resolution" means. Change a dependency and the lock the tools write is drift — the tool says so,
and this appendix is where the answer goes. The alternative, leaving them to the tools and protecting them,
hides the decision in the output, where it travels in a seed and nobody reads it.

#file("Cargo.lock", ````toml
<<lock: the cargo resolution>>
````)

#file("flake.lock", ````json
<<lock: the nix inputs>>
````)

#chunk("lock: the cargo resolution", ````toml
# This file is automatically @generated by Cargo.
# It is not intended for manual editing.
version = 4

[[package]]
name = "addr2line"
version = "0.25.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "1b5d307320b3181d6d7954e663bd7c774a838b8220fe0593c86d9fb09f498b4b"
dependencies = [
 "gimli",
]

[[package]]
name = "adler2"
version = "2.0.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "320119579fcad9c21884f5c4861d16174d0e06250625266f50fe6898340abefa"

[[package]]
name = "aes"
version = "0.9.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "35f0f96ce78e38c3dc6d8948aa8163d06385be74000f3c7a95bf1eef35d3ea32"
dependencies = [
 "cipher",
 "cpubits",
 "cpufeatures",
]

[[package]]
name = "aho-corasick"
version = "1.1.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c982642fa9e8606056828ee9a8505737230110bb1099153c79efe865c59d12ba"
dependencies = [
 "memchr",
]

[[package]]
name = "alloc-no-stdlib"
version = "2.0.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "cc7bb162ec39d46ab1ca8c77bf72e890535becd1751bb45f64c597edb4c8c6b3"

[[package]]
name = "alloc-stdlib"
version = "0.2.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "0e76a019e91224d279006ff972f1e984179a6e9feb050adba6ce8274aef23195"
dependencies = [
 "alloc-no-stdlib",
]

[[package]]
name = "anstream"
version = "1.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "824a212faf96e9acacdbd09febd34438f8f711fb84e09a8916013cd7815ca28d"
dependencies = [
 "anstyle",
 "anstyle-parse",
 "anstyle-query",
 "anstyle-wincon",
 "colorchoice",
 "is_terminal_polyfill",
 "utf8parse",
]

[[package]]
name = "anstyle"
version = "1.0.14"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "940b3a0ca603d1eade50a4846a2afffd5ef57a9feac2c0e2ec2e14f9ead76000"

[[package]]
name = "anstyle-parse"
version = "1.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "52ce7f38b242319f7cabaa6813055467063ecdc9d355bbb4ce0c68908cd8130e"
dependencies = [
 "utf8parse",
]

[[package]]
name = "anstyle-query"
version = "1.1.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "40c48f72fd53cd289104fc64099abca73db4166ad86ea0b4341abe65af83dadc"
dependencies = [
 "windows-sys 0.61.2",
]

[[package]]
name = "anstyle-wincon"
version = "3.0.11"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "291e6a250ff86cd4a820112fb8898808a366d8f9f58ce16d1f538353ad55747d"
dependencies = [
 "anstyle",
 "once_cell_polyfill",
 "windows-sys 0.61.2",
]

[[package]]
name = "backtrace"
version = "0.3.76"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "bb531853791a215d7c62a30daf0dde835f381ab5de4589cfe7c649d2cbe92bd6"
dependencies = [
 "addr2line",
 "cfg-if",
 "libc",
 "miniz_oxide 0.8.9",
 "object",
 "rustc-demangle",
 "windows-link",
]

[[package]]
name = "backtrace-ext"
version = "0.2.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "537beee3be4a18fb023b570f80e3ae28003db9167a751266b259926e25539d50"
dependencies = [
 "backtrace",
]

[[package]]
name = "bitflags"
version = "2.13.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "3ded4057c258ba199e2d26386d3af3780957ecaee6c4ef4041c6b4b8b97c0b06"

[[package]]
name = "block-buffer"
version = "0.12.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d2f6c7dbe95a6ed67ad9f18e57daf93a2f034c524b99fd2b76d18fdfeb6660aa"
dependencies = [
 "hybrid-array",
]

[[package]]
name = "block-padding"
version = "0.4.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "710f1dd022ef4e93f8a438b4ba958de7f64308434fa6a87104481645cc30068b"
dependencies = [
 "hybrid-array",
]

[[package]]
name = "brotli-decompressor"
version = "5.0.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "3a32acac15fe1967bc3986b2a6347dffc965602354ea6f450ad07e8bfd253583"
dependencies = [
 "alloc-no-stdlib",
 "alloc-stdlib",
]

[[package]]
name = "bstr"
version = "1.13.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "6bb31b46c14244e20ee9984b11bf5c992b91fb6939fea616e3512c8baecdbe5f"
dependencies = [
 "memchr",
 "serde_core",
]

[[package]]
name = "cbc"
version = "0.2.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ce2dc9ee5f88d11e0beb842c88b33c8a5cf0d1329c4b19494af42b07dbfe8896"
dependencies = [
 "cipher",
]

[[package]]
name = "cfg-if"
version = "1.0.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "9330f8b2ff13f34540b44e946ef35111825727b38d33286ef986142615121801"

[[package]]
name = "chacha20"
version = "0.10.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "65c35e4b699c7e15ccbe7ee35c005e4fc0a278d22238a2857e6ce2dadeda1b06"
dependencies = [
 "cfg-if",
 "cpufeatures",
 "rand_core",
]

[[package]]
name = "cipher"
version = "0.5.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e8cf2a2c93cd704877c0858356ed03480ff301ee950b43f1cbe4573b088bfa6c"
dependencies = [
 "crypto-common",
 "inout",
]

[[package]]
name = "clap"
version = "4.6.6"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "473c7e07f409a8d772161724aa8db6a765a2532a70f9667eeb7b49d3d02fbdca"
dependencies = [
 "clap_builder",
 "clap_derive",
]

[[package]]
name = "clap_builder"
version = "4.6.6"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7b48fea5a88e9ae728a2dcbedbfc0e730f7d60da42e1cb049a83c9fb8b789889"
dependencies = [
 "anstream",
 "anstyle",
 "clap_lex",
 "strsim",
]

[[package]]
name = "clap_derive"
version = "4.6.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d012d2b9d65aca7f18f4d9878a045bc17899bba951561ba5ec3c2ba1eed9a061"
dependencies = [
 "heck",
 "proc-macro2",
 "quote",
 "syn 3.0.5",
]

[[package]]
name = "clap_lex"
version = "1.1.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c8d4a3bb8b1e0c1050499d1815f5ab16d04f0959b233085fb31653fbfc9d98f9"

[[package]]
name = "colorchoice"
version = "1.0.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "1d07550c9036bf2ae0c684c4297d503f838287c83c53686d05370d0e139ae570"

[[package]]
name = "const-oid"
version = "0.10.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "a6ef517f0926dd24a1582492c791b6a4818a4d94e789a334894aa15b0d12f55c"

[[package]]
name = "core_detect"
version = "1.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7f8f80099a98041a3d1622845c271458a2d73e688351bf3cb999266764b81d48"

[[package]]
name = "cpubits"
version = "0.1.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "15b85f9c39137c3a891689859392b1bd49812121d0d61c9caf00d46ed5ce06ae"

[[package]]
name = "cpufeatures"
version = "0.3.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "5ca28b0ae3115b884660db4118d803791fd6756b6e88f39c0f3f7859060d7566"
dependencies = [
 "libc",
]

[[package]]
name = "crc32fast"
version = "1.5.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "8498c871161e1742aaa9d52551b2d6ebdd4c3d45a3be423e3728f33b955be550"
dependencies = [
 "cfg-if",
]

[[package]]
name = "crossbeam-deque"
version = "0.8.8"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "622f3fc73690be383c7214310406f28a90e6edeadc3cea882f9d71e495b9711a"
dependencies = [
 "crossbeam-epoch",
 "crossbeam-utils",
]

[[package]]
name = "crossbeam-epoch"
version = "0.9.21"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "dc74980687109a3b14c72fd458107bf0baa1da1a1a805e178d15501ba9b86d9d"
dependencies = [
 "crossbeam-utils",
]

[[package]]
name = "crossbeam-utils"
version = "0.8.23"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "a31eee39dddec8330830986fcd7625edb5a24ec90ea038215273bbc3adb08ac6"

[[package]]
name = "crypto-common"
version = "0.2.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ce6e4c961d6cd6c9a86db418387425e8bdeaf05b3c8bc1411e6dca4c252f1453"
dependencies = [
 "hybrid-array",
]

[[package]]
name = "digest"
version = "0.11.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "f1dd6dbb5841937940781866fa1281a1ff7bd3bf827091440879f9994983d5c2"
dependencies = [
 "block-buffer",
 "const-oid",
 "crypto-common",
]

[[package]]
name = "displaydoc"
version = "0.2.7"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c6232dd377dcc64799954cbd3a9bb882e9cdc1308ccd87b1c098f1fb2eaf82a8"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 3.0.5",
]

[[package]]
name = "ecb"
version = "0.2.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "26f2a8b3e564eba0877223dc343703ad0385794e882e6d13f3a4dd5c6b1f41ac"
dependencies = [
 "cipher",
]

[[package]]
name = "encoding_rs"
version = "0.8.41"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7b5ef0006ac9ab233c38522f5ae99cae3625151de8f706cacee1cba4b8e2832a"
dependencies = [
 "cfg-if",
 "core_detect",
 "multiversion",
 "multiversion_no_op",
 "rustversion",
 "scopeguard",
 "simdutf8",
]

[[package]]
name = "equivalent"
version = "1.0.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "877a4ace8713b0bcf2a4e7eec82529c029f1d0619886d18145fea96c3ffe5c0f"

[[package]]
name = "errno"
version = "0.3.14"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "39cab71617ae0d63f51a36d69f866391735b51691dbda63cf6f96d042b63efeb"
dependencies = [
 "libc",
 "windows-sys 0.61.2",
]

[[package]]
name = "fastrand"
version = "2.5.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "da7c62ceae207dd37ea5b845da6a0696c799f85e97da1ab5b7910be3c1c80223"

[[package]]
name = "file-id"
version = "0.2.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e1fc6a637b6dc58414714eddd9170ff187ecb0933d4c7024d1abbd23a3cc26e9"
dependencies = [
 "windows-sys 0.60.2",
]

[[package]]
name = "flate2"
version = "1.1.10"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "6e634e2e0ebac1ee034020da1ca582e17ffe4e0f5e985823721e168928136dcb"
dependencies = [
 "crc32fast",
 "miniz_oxide 0.9.1",
 "zlib-rs",
]

[[package]]
name = "fsevent-sys"
version = "4.1.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "76ee7a02da4d231650c7cea31349b889be2f45ddb3ef3032d2ec8185f6313fd2"
dependencies = [
 "libc",
]

[[package]]
name = "getrandom"
version = "0.4.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "300e883d756b2e4ec94e02791f39b04b522276138852cfc41d9fb7e904106099"
dependencies = [
 "cfg-if",
 "libc",
 "r-efi",
 "rand_core",
]

[[package]]
name = "gimli"
version = "0.32.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e629b9b98ef3dd8afe6ca2bd0f89306cec16d43d907889945bc5d6687f2f13c7"

[[package]]
name = "globset"
version = "0.4.20"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "07c34a9410465b45bd9787443bc7370f37735bad04b0f0cd57ff1a3186c98988"
dependencies = [
 "aho-corasick",
 "bstr",
 "log",
 "regex-automata",
 "regex-syntax",
]

[[package]]
name = "hashbrown"
version = "0.17.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ed5909b6e89a2db4456e54cd5f673791d7eca6732202bbf2a9cc504fe2f9b84a"

[[package]]
name = "heck"
version = "0.5.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "2304e00983f87ffb38b55b444b5e3b60a884b5d30c0fca7d82fe33449bbe55ea"

[[package]]
name = "hybrid-array"
version = "0.4.15"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "27f864f10dfb56725ce5ce5472bc52252c8f93a4ab86327122cebf62c5f59a17"
dependencies = [
 "typenum",
]

[[package]]
name = "icu_collections"
version = "2.3.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "fa68d21081c4a05d5a901a1c62add574c77048b6a1c67be3b50ce0b60d4ca513"
dependencies = [
 "displaydoc",
 "potential_utf",
 "utf8_iter",
 "yoke",
 "zerofrom",
 "zerovec",
]

[[package]]
name = "icu_locale_core"
version = "2.3.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d56e28588da92eee5c3201a6eff33fabdd49b62269c8938d4ff050ce4d900deb"
dependencies = [
 "displaydoc",
 "litemap",
 "serde",
 "tinystr",
 "writeable",
 "zerovec",
]

[[package]]
name = "icu_locale_fallback"
version = "2.3.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "251af8e57c9400e3eb58242fe5b8b1152b2a64fdf4cf632f923c38ccee6f2fa9"
dependencies = [
 "icu_locale_core",
 "icu_locale_fallback_data",
 "icu_provider",
 "potential_utf",
 "tinystr",
 "zerovec",
]

[[package]]
name = "icu_locale_fallback_data"
version = "2.3.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "decf2a22ec8fa68f1a0c1129a3f8583f8f8bc24e8b9ccbe98ead99f62a4dc3a8"

[[package]]
name = "icu_provider"
version = "2.3.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d27bbb9d3abbefac45d55f647c9de1d44aafcd1186eb91879afef17c396c3e73"
dependencies = [
 "displaydoc",
 "icu_locale_core",
 "serde",
 "stable_deref_trait",
 "writeable",
 "yoke",
 "zerofrom",
 "zerotrie",
 "zerovec",
]

[[package]]
name = "icu_segmenter"
version = "2.3.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "82d07aafccd67af15d02512a6adf5896fbc5ed00f2e99b471d2efa14016db3db"
dependencies = [
 "icu_collections",
 "icu_locale_fallback",
 "icu_provider",
 "icu_segmenter_data",
 "potential_utf",
 "smallvec",
 "utf8_iter",
 "zerovec",
]

[[package]]
name = "icu_segmenter_data"
version = "2.3.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ae293c039020f9ec10710af98d29ce6aa2051486638b49c9a6409f3b4a9e98ad"

[[package]]
name = "ignore"
version = "0.4.33"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "00b69833ed729dc5aa7d19541d96d6cf8e9137194207a04916d658e43168402f"
dependencies = [
 "crossbeam-deque",
 "globset",
 "log",
 "memchr",
 "regex-automata",
 "same-file",
 "walkdir",
 "winapi-util",
]

[[package]]
name = "include_dir"
version = "0.7.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "923d117408f1e49d914f1a379a309cffe4f18c05cf4e3d12e613a15fc81bd0dd"
dependencies = [
 "include_dir_macros",
]

[[package]]
name = "include_dir_macros"
version = "0.7.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7cab85a7ed0bd5f0e76d93846e0147172bed2e2d3f859bcc33a8d9699cad1a75"
dependencies = [
 "proc-macro2",
 "quote",
]

[[package]]
name = "indexmap"
version = "2.14.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "cc4e190f5d26ca7051642629da2c52fc03bde85a03197c99408dcd291734c855"
dependencies = [
 "equivalent",
 "hashbrown",
]

[[package]]
name = "inotify"
version = "0.11.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4cc00ea907cab49550b7da656f80ebb97be1b997d931fbcd28d39734e17ce592"
dependencies = [
 "bitflags",
 "inotify-sys",
 "libc",
]

[[package]]
name = "inotify-sys"
version = "0.1.8"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c033f80b2c113cdf91ab7a33faa9cbc014726dcad99880c8609af2a370edf37d"
dependencies = [
 "libc",
]

[[package]]
name = "inout"
version = "0.2.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4250ce6452e92010fdf7268ccc5d14faa80bb12fc741938534c58f16804e03c7"
dependencies = [
 "block-padding",
 "hybrid-array",
]

[[package]]
name = "is_ci"
version = "1.2.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7655c9839580ee829dfacba1d1278c2b7883e50a277ff7541299489d6bdfdc45"

[[package]]
name = "is_terminal_polyfill"
version = "1.70.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "a6cb138bb79a146c1bd460005623e142ef0181e3d0219cb493e02f7d08a35695"

[[package]]
name = "itoa"
version = "1.0.18"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "8f42a60cbdf9a97f5d2305f08a87dc4e09308d1276d28c869c684d7777685682"

[[package]]
name = "kqueue"
version = "1.2.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "8d763e5b24120b4ddf50de6c92308156765aabfbbccebf401da7cff2d70a41ea"
dependencies = [
 "kqueue-sys",
 "libc",
]

[[package]]
name = "kqueue-sys"
version = "1.1.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "07293a4e297ac234359b510362495713f75ea345d5307140414f20c69ffeb087"
dependencies = [
 "bitflags",
 "libc",
]

[[package]]
name = "libc"
version = "0.2.189"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "3eaf3ede3fee6db1a4c2ee091bf8a8b4dccdc6d17f656fb07896ee72867612f2"

[[package]]
name = "linux-raw-sys"
version = "0.12.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "32a66949e030da00e8c7d4434b251670a91556f4144941d37452769c25d58a53"

[[package]]
name = "litemap"
version = "0.8.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "47d9d19d1d6efa0109d2f65ff4c85cddd50bd572e5a00127ab10987290bcefae"

[[package]]
name = "log"
version = "0.4.34"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "f9f8bd3e56ce4dfc153cf470fffbfa98c7620958b312ca5c3a4b8d5181fd13c6"

[[package]]
name = "lopdf"
version = "0.45.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "bfffda0fe1ab0157e1a13c14bebd3f28671f2fccb7922f0722ec53926e6922d3"
dependencies = [
 "aes",
 "bitflags",
 "brotli-decompressor",
 "cbc",
 "ecb",
 "encoding_rs",
 "flate2",
 "getrandom",
 "indexmap",
 "itoa",
 "log",
 "md-5",
 "nom",
 "rand",
 "rangemap",
 "sha2",
 "stringprep",
 "thiserror",
 "weezl",
]

[[package]]
name = "lp"
version = "0.1.0"
dependencies = [
 "clap",
 "ignore",
 "include_dir",
 "lopdf",
 "miette",
 "notify",
 "notify-debouncer-full",
 "regex",
 "serde",
 "serde_json",
 "tempfile",
 "thiserror",
]

[[package]]
name = "md-5"
version = "0.11.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "69b6441f590336821bb897fb28fc622898ccceb1d6cea3fde5ea86b090c4de98"
dependencies = [
 "cfg-if",
 "digest",
]

[[package]]
name = "memchr"
version = "2.8.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "cf8baf1c55e62ffcace7a9f06f4bd9cd3f0c4beb022d3b367256b91b87513d98"

[[package]]
name = "miette"
version = "7.6.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "5f98efec8807c63c752b5bd61f862c165c115b0a35685bdcfd9238c7aeb592b7"
dependencies = [
 "backtrace",
 "backtrace-ext",
 "cfg-if",
 "miette-derive",
 "owo-colors",
 "supports-color",
 "supports-hyperlinks",
 "supports-unicode",
 "terminal_size",
 "textwrap",
 "unicode-width 0.1.14",
]

[[package]]
name = "miette-derive"
version = "7.6.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "db5b29714e950dbb20d5e6f74f9dcec4edbcc1067bb7f8ed198c097b8c1a818b"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 2.0.119",
]

[[package]]
name = "miniz_oxide"
version = "0.8.9"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "1fa76a2c86f704bdb222d66965fb3d63269ce38518b83cb0575fca855ebb6316"
dependencies = [
 "adler2",
]

[[package]]
name = "miniz_oxide"
version = "0.9.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b63fbc4a50860e98e7b2aa7804ded1db5cbc3aff9193adaff57a6931bf7c4b4c"
dependencies = [
 "adler2",
 "simd-adler32",
]

[[package]]
name = "mio"
version = "1.2.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4b18443e9c262bfe8fa82f51666e2642c53393f7e5c27b3e1aeab922cff5b9d8"
dependencies = [
 "libc",
 "log",
 "wasi",
 "windows-sys 0.61.2",
]

[[package]]
name = "multiversion"
version = "0.9.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b4ca4bea16ffc3f443cf7d866912118196bfef4c6a1556ca00f9f9b00bb43f7c"
dependencies = [
 "multiversion-macros",
]

[[package]]
name = "multiversion-macros"
version = "0.9.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "0d416831a7317ef4b08bee00b69cbbb9c8763da7959a7026244d6266869f9c83"
dependencies = [
 "proc-macro2",
 "quote",
 "rustversion",
 "syn 3.0.5",
]

[[package]]
name = "multiversion_no_op"
version = "1.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "743fb55ba31b18fb1ecef6bdc9aa2743314978ac084044301a7eee33fb99a20d"

[[package]]
name = "nom"
version = "8.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "df9761775871bdef83bee530e60050f7e54b1105350d6884eb0fb4f46c2f9405"
dependencies = [
 "memchr",
]

[[package]]
name = "notify"
version = "8.2.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4d3d07927151ff8575b7087f245456e549fea62edf0ec4e565a5ee50c8402bc3"
dependencies = [
 "bitflags",
 "fsevent-sys",
 "inotify",
 "kqueue",
 "libc",
 "log",
 "mio",
 "notify-types",
 "walkdir",
 "windows-sys 0.60.2",
]

[[package]]
name = "notify-debouncer-full"
version = "0.7.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c02b49179cfebc9932238d04d6079912d26de0379328872846118a0fa0dbb302"
dependencies = [
 "file-id",
 "log",
 "notify",
 "notify-types",
 "walkdir",
]

[[package]]
name = "notify-types"
version = "2.1.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "42b8cfee0e339a0337359f3c88165702ac6e600dc01c0cc9579a92d62b08477a"
dependencies = [
 "bitflags",
]

[[package]]
name = "object"
version = "0.37.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ff76201f031d8863c38aa7f905eca4f53abbfa15f609db4277d44cd8938f33fe"
dependencies = [
 "memchr",
]

[[package]]
name = "once_cell"
version = "1.21.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "9f7c3e4beb33f85d45ae3e3a1792185706c8e16d043238c593331cc7cd313b50"

[[package]]
name = "once_cell_polyfill"
version = "1.70.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "384b8ab6d37215f3c5301a95a4accb5d64aa607f1fcb26a11b5303878451b4fe"

[[package]]
name = "owo-colors"
version = "4.4.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "13c45bb4a6ae1280ec0803b1ef9d3455eb50f01efbbe1447ab020f1d54fba9d8"

[[package]]
name = "potential_utf"
version = "0.1.6"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d83eb9bc6d8e5cf568e7a1101d60ee05e81ed50ea106026f3d18deeb046d7661"
dependencies = [
 "serde_core",
 "writeable",
 "zerovec",
]

[[package]]
name = "proc-macro2"
version = "1.0.107"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "985e7ec9bb745e6ce6535b544d84d6cd6f7ad8bd711c398938ae983b91a766d9"
dependencies = [
 "unicode-ident",
]

[[package]]
name = "quote"
version = "1.0.47"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "1fbf4db142a473a8d80c26bbf18454ed458bf8d26c8219c331daecfdbd079001"
dependencies = [
 "proc-macro2",
]

[[package]]
name = "r-efi"
version = "6.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "f8dcc9c7d52a811697d2151c701e0d08956f92b0e24136cf4cf27b57a6a0d9bf"

[[package]]
name = "rand"
version = "0.10.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c7f5fa3a058cd35567ef9bfa5e75732bee0f9e4c55fa90477bef2dfcdbc4be80"
dependencies = [
 "chacha20",
 "getrandom",
 "rand_core",
]

[[package]]
name = "rand_core"
version = "0.10.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "63b8176103e19a2643978565ca18b50549f6101881c443590420e4dc998a3c69"

[[package]]
name = "rangemap"
version = "1.8.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "a611d15b50743feb4c76b7d03edcb0e64f399c26961e4efe6975bc398be6aa3d"

[[package]]
name = "regex"
version = "1.13.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "f020237b6c8eed93db2e2cb53c00c60a8e1bc73da7d073199a1180401450218d"
dependencies = [
 "aho-corasick",
 "memchr",
 "regex-automata",
 "regex-syntax",
]

[[package]]
name = "regex-automata"
version = "0.4.18"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ad8553b9b26413251cbf30e620595c7a41b3887f03da04579c0e6b0d6a06b4b2"
dependencies = [
 "aho-corasick",
 "memchr",
 "regex-syntax",
]

[[package]]
name = "regex-syntax"
version = "0.8.11"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d6f6ff9a378485b298a5286656da665ba74413d36db0979633275d2e708145d4"

[[package]]
name = "rustc-demangle"
version = "0.1.28"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b74b56ffa8bb2830709a538c2cbcae9aa062db0d2a42563bfb09bdaae44020eb"

[[package]]
name = "rustix"
version = "1.1.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b6fe4565b9518b83ef4f91bb47ce29620ca828bd32cb7e408f0062e9930ba190"
dependencies = [
 "bitflags",
 "errno",
 "libc",
 "linux-raw-sys",
 "windows-sys 0.61.2",
]

[[package]]
name = "rustversion"
version = "1.0.23"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "cf54715a573b99ac80df0bc206da022bcd442c974952c7b9720069370852e21f"

[[package]]
name = "same-file"
version = "1.0.6"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "93fc1dc3aaa9bfed95e02e6eadabb4baf7e3078b0bd1b4d7b6b0b68378900502"
dependencies = [
 "winapi-util",
]

[[package]]
name = "scopeguard"
version = "1.2.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "94143f37725109f92c262ed2cf5e59bce7498c01bcc1502d7b9afe439a4e9f49"

[[package]]
name = "serde"
version = "1.0.229"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4148590afebada386688f18773da617792bf2ef03ffc1e4cbd2b1d45b023e0ba"
dependencies = [
 "serde_core",
 "serde_derive",
]

[[package]]
name = "serde_core"
version = "1.0.229"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "67dca2c9c51e58a4791a4b1ed58308b39c64224d349a935ab5039aa360942a48"
dependencies = [
 "serde_derive",
]

[[package]]
name = "serde_derive"
version = "1.0.229"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e7a5d71263a5a7d47b41f6b3f06ba276f10cc18b0931f1799f710578e2309348"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 3.0.5",
]

[[package]]
name = "serde_json"
version = "1.0.151"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c841b55ecdae098c80dcae9cf767f6f8a0c2cdb3416bbef72181df4d0fe73f14"
dependencies = [
 "itoa",
 "memchr",
 "serde",
 "serde_core",
 "zmij",
]

[[package]]
name = "sha2"
version = "0.11.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "446ba717509524cb3f22f17ecc096f10f4822d76ab5c0b9822c5f9c284e825f4"
dependencies = [
 "cfg-if",
 "cpufeatures",
 "digest",
]

[[package]]
name = "simd-adler32"
version = "0.3.10"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "3a219298ac11a56ea9a6d2120044824d6f01aeb034955e7af7bc16858527deea"

[[package]]
name = "simdutf8"
version = "0.1.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e3a9fe34e3e7a50316060351f37187a3f546bce95496156754b601a5fa71b76e"

[[package]]
name = "smallvec"
version = "1.16.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ba467056f1b547ed52077911161fc86985becbc60e8e1857c8a144dab0def891"

[[package]]
name = "stable_deref_trait"
version = "1.2.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "6ce2be8dc25455e1f91df71bfa12ad37d7af1092ae736f3a6cd0e37bc7810596"

[[package]]
name = "stringprep"
version = "0.1.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7b4df3d392d81bd458a8a621b8bffbd2302a12ffe288a9d931670948749463b1"
dependencies = [
 "unicode-bidi",
 "unicode-normalization",
 "unicode-properties",
]

[[package]]
name = "strsim"
version = "0.11.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7da8b5736845d9f2fcb837ea5d9e2628564b3b043a70948a3f0b778838c5fb4f"

[[package]]
name = "supports-color"
version = "3.0.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c64fc7232dd8d2e4ac5ce4ef302b1d81e0b80d055b9d77c7c4f51f6aa4c867d6"
dependencies = [
 "is_ci",
]

[[package]]
name = "supports-hyperlinks"
version = "3.2.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e396b6523b11ccb83120b115a0b7366de372751aa6edf19844dfb13a6af97e91"

[[package]]
name = "supports-unicode"
version = "3.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b7401a30af6cb5818bb64852270bb722533397edcfc7344954a38f420819ece2"

[[package]]
name = "syn"
version = "2.0.119"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "872831b642d1a07999a962a351ed35b955ea2cfc8f3862091e2a240a84f17297"
dependencies = [
 "proc-macro2",
 "quote",
 "unicode-ident",
]

[[package]]
name = "syn"
version = "3.0.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "12df2e0110f65b775f769bb17ef989067a1d931b2eb822bd4346631eeada89f9"
dependencies = [
 "proc-macro2",
 "quote",
 "unicode-ident",
]

[[package]]
name = "synstructure"
version = "0.13.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "728a70f3dbaf5bab7f0c4b1ac8d7ae5ea60a4b5549c8a5914361c99147a709d2"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 2.0.119",
]

[[package]]
name = "tempfile"
version = "3.27.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "32497e9a4c7b38532efcdebeef879707aa9f794296a4f0244f6f69e9bc8574bd"
dependencies = [
 "fastrand",
 "getrandom",
 "once_cell",
 "rustix",
 "windows-sys 0.61.2",
]

[[package]]
name = "terminal_size"
version = "0.4.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "230a1b821ccbd75b185820a1f1ff7b14d21da1e442e22c0863ea5f08771a8874"
dependencies = [
 "rustix",
 "windows-sys 0.61.2",
]

[[package]]
name = "textwrap"
version = "0.16.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b81c0cb5fce14f53e49c1d4da0c508334ff12040221bb8ab01b2dabd91d04b6e"
dependencies = [
 "icu_segmenter",
 "unicode-width 0.2.2",
]

[[package]]
name = "thiserror"
version = "2.0.20"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ec86235f5fcc2a73650310756d2ac5b138a5780bbbdfae3eeccec992c435ba4f"
dependencies = [
 "thiserror-impl",
]

[[package]]
name = "thiserror-impl"
version = "2.0.20"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "bc04cd3e1236dd4a98afca4569f2deb3f120e5422a4023be2cb683f8486292af"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 3.0.5",
]

[[package]]
name = "tinystr"
version = "0.8.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b1e27c91459209c2986af3dcf603a5a74a4368754ce37414f59acc971167f643"
dependencies = [
 "displaydoc",
 "serde_core",
 "zerovec",
]

[[package]]
name = "tinyvec"
version = "1.13.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4cf0ded5c4e56918d8f8a339e1bb67d038d3bc6d144ac407904015ba2e4cde9b"
dependencies = [
 "tinyvec_macros",
]

[[package]]
name = "tinyvec_macros"
version = "0.1.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "1f3ccbac311fea05f86f61904b462b55fb3df8837a366dfc601a0161d0532f20"

[[package]]
name = "typenum"
version = "1.20.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b6f5e870be6c3b371b77fe0ee0bafb859fa4964b4404c27de1d380043c4dda20"

[[package]]
name = "unicode-bidi"
version = "0.3.18"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "5c1cb5db39152898a79168971543b1cb5020dff7fe43c8dc468b0885f5e29df5"

[[package]]
name = "unicode-ident"
version = "1.0.24"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e6e4313cd5fcd3dad5cafa179702e2b244f760991f45397d14d4ebf38247da75"

[[package]]
name = "unicode-normalization"
version = "0.1.25"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "5fd4f6878c9cb28d874b009da9e8d183b5abc80117c40bbd187a1fde336be6e8"
dependencies = [
 "tinyvec",
]

[[package]]
name = "unicode-properties"
version = "0.1.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7df058c713841ad818f1dc5d3fd88063241cc61f49f5fbea4b951e8cf5a8d71d"

[[package]]
name = "unicode-width"
version = "0.1.14"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "7dd6e30e90baa6f72411720665d41d89b9a3d039dc45b8faea1ddd07f617f6af"

[[package]]
name = "unicode-width"
version = "0.2.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b4ac048d71ede7ee76d585517add45da530660ef4390e49b098733c6e897f254"

[[package]]
name = "utf8_iter"
version = "1.0.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b6c140620e7ffbb22c2dee59cafe6084a59b5ffc27a8859a5f0d494b5d52b6be"

[[package]]
name = "utf8parse"
version = "0.2.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "06abde3611657adf66d383f00b093d7faecc7fa57071cce2578660c9f1010821"

[[package]]
name = "walkdir"
version = "2.5.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "29790946404f91d9c5d06f9874efddea1dc06c5efe94541a7d6863108e3a5e4b"
dependencies = [
 "same-file",
 "winapi-util",
]

[[package]]
name = "wasi"
version = "0.11.1+wasi-snapshot-preview1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ccf3ec651a847eb01de73ccad15eb7d99f80485de043efb2f370cd654f4ea44b"

[[package]]
name = "weezl"
version = "0.2.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d4ca08e5ef825b65b056d9efbd95c8750683f0a6d0466d02e96dc2e4e360f3d2"

[[package]]
name = "winapi-util"
version = "0.1.11"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c2a7b1c03c876122aa43f3020e6c3c3ee5c05081c9a00739faf7503aeba10d22"
dependencies = [
 "windows-sys 0.61.2",
]

[[package]]
name = "windows-link"
version = "0.2.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "f0805222e57f7521d6a62e36fa9163bc891acd422f971defe97d64e70d0a4fe5"

[[package]]
name = "windows-sys"
version = "0.60.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "f2f500e4d28234f72040990ec9d39e3a6b950f9f22d3dba18416c35882612bcb"
dependencies = [
 "windows-targets",
]

[[package]]
name = "windows-sys"
version = "0.61.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ae137229bcbd6cdf0f7b80a31df61766145077ddf49416a728b02cb3921ff3fc"
dependencies = [
 "windows-link",
]

[[package]]
name = "windows-targets"
version = "0.53.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4945f9f551b88e0d65f3db0bc25c33b8acea4d9e41163edf90dcd0b19f9069f3"
dependencies = [
 "windows-link",
 "windows_aarch64_gnullvm",
 "windows_aarch64_msvc",
 "windows_i686_gnu",
 "windows_i686_gnullvm",
 "windows_i686_msvc",
 "windows_x86_64_gnu",
 "windows_x86_64_gnullvm",
 "windows_x86_64_msvc",
]

[[package]]
name = "windows_aarch64_gnullvm"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "a9d8416fa8b42f5c947f8482c43e7d89e73a173cead56d044f6a56104a6d1b53"

[[package]]
name = "windows_aarch64_msvc"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "b9d782e804c2f632e395708e99a94275910eb9100b2114651e04744e9b125006"

[[package]]
name = "windows_i686_gnu"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "960e6da069d81e09becb0ca57a65220ddff016ff2d6af6a223cf372a506593a3"

[[package]]
name = "windows_i686_gnullvm"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "fa7359d10048f68ab8b09fa71c3daccfb0e9b559aed648a8f95469c27057180c"

[[package]]
name = "windows_i686_msvc"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "1e7ac75179f18232fe9c285163565a57ef8d3c89254a30685b57d83a38d326c2"

[[package]]
name = "windows_x86_64_gnu"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "9c3842cdd74a865a8066ab39c8a7a473c0778a3f29370b5fd6b4b9aa7df4a499"

[[package]]
name = "windows_x86_64_gnullvm"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "0ffa179e2d07eee8ad8f57493436566c7cc30ac536a3379fdf008f47f6bb7ae1"

[[package]]
name = "windows_x86_64_msvc"
version = "0.53.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d6bbff5f0aada427a1e5a6da5f1f98158182f26556f345ac9e04d36d0ebed650"

[[package]]
name = "writeable"
version = "0.6.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "3ad82d2a33cdc9674dc7465672f271e096168fcdbe0f799d9e6db8c5892679dc"

[[package]]
name = "yoke"
version = "0.8.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "709fe23a0424b6a435d82152b1bd3fdfb0833487d5fa90d05d42762a9891fef5"
dependencies = [
 "stable_deref_trait",
 "yoke-derive",
 "zerofrom",
]

[[package]]
name = "yoke-derive"
version = "0.8.2"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "de844c262c8848816172cef550288e7dc6c7b7814b4ee56b3e1553f275f1858e"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 2.0.119",
 "synstructure",
]

[[package]]
name = "zerofrom"
version = "0.1.8"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "0ec05a11813ea801ff6d75110ad09cd0824ddba17dfe17128ea0d5f68e6c5272"
dependencies = [
 "zerofrom-derive",
]

[[package]]
name = "zerofrom-derive"
version = "0.1.7"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "11532158c46691caf0f2593ea8358fed6bbf68a0315e80aae9bd41fbade684a1"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 2.0.119",
 "synstructure",
]

[[package]]
name = "zerotrie"
version = "0.2.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "4ea269c3bd32f0a32c321907a2ae912ba6f4649bb0fc764a15627e99a7095a3f"
dependencies = [
 "displaydoc",
 "zerovec",
]

[[package]]
name = "zerovec"
version = "0.11.8"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "bb0464e17806c1d976d5cba29399c7f08e516e279e2ba493f63123b5fca67dd8"
dependencies = [
 "serde",
 "yoke",
 "zerofrom",
 "zerovec-derive",
]

[[package]]
name = "zerovec-derive"
version = "0.11.6"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "34df6fc39dbd26ddc9c10e6a2984476e13acce22e64e4487636ef494369225da"
dependencies = [
 "proc-macro2",
 "quote",
 "syn 3.0.5",
]

[[package]]
name = "zlib-rs"
version = "0.6.7"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "34b31d188d9d685a4f9c7b46d6e36631b07058d2cfe190267adce54dc230bf12"

[[package]]
name = "zmij"
version = "1.0.23"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "29666d0abbfad1e3dc4dcf6144730dd3a3ab225bbbdac83319345b1b44ccfc1b"
````)

#chunk("lock: the nix inputs", ````json
{
  "nodes": {
    "crane": {
      "locked": {
        "lastModified": 1788465171,
        "narHash": "sha256-Y1/TTVXjYXGF068IThQH9fPSZ0SIE74PABlUxnWTUH0=",
        "owner": "ipetkov",
        "repo": "crane",
        "rev": "eb35abda9f232cc6610b1d1e3200d15c49b7ac54",
        "type": "github"
      },
      "original": {
        "owner": "ipetkov",
        "repo": "crane",
        "type": "github"
      }
    },
    "flake-parts": {
      "inputs": {
        "nixpkgs-lib": [
          "nixpkgs"
        ]
      },
      "locked": {
        "lastModified": 1788450739,
        "narHash": "sha256-glZLQlzIn1fXH6PazR2iUmTo7kzzyYSshrWhLS9TqCU=",
        "owner": "hercules-ci",
        "repo": "flake-parts",
        "rev": "31729ca8cbdb4fa927b34e5f4353e6a83f39e993",
        "type": "github"
      },
      "original": {
        "owner": "hercules-ci",
        "repo": "flake-parts",
        "type": "github"
      }
    },
    "nix-github-actions": {
      "inputs": {
        "nixpkgs": [
          "nixpkgs"
        ]
      },
      "locked": {
        "lastModified": 1737420293,
        "narHash": "sha256-F1G5ifvqTpJq7fdkT34e/Jy9VCyzd5XfJ9TO8fHhJWE=",
        "owner": "nix-community",
        "repo": "nix-github-actions",
        "rev": "f4158fa080ef4503c8f4c820967d946c2af31ec9",
        "type": "github"
      },
      "original": {
        "owner": "nix-community",
        "repo": "nix-github-actions",
        "type": "github"
      }
    },
    "nixpkgs": {
      "locked": {
        "lastModified": 1789006805,
        "narHash": "sha256-xB8mKMOx1IA9vTDNLmJZ6n4wCMq/cuWBBOzGCRnqxrU=",
        "owner": "NixOS",
        "repo": "nixpkgs",
        "rev": "8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe",
        "type": "github"
      },
      "original": {
        "owner": "NixOS",
        "ref": "nixos-unstable",
        "repo": "nixpkgs",
        "type": "github"
      }
    },
    "root": {
      "inputs": {
        "crane": "crane",
        "flake-parts": "flake-parts",
        "nix-github-actions": "nix-github-actions",
        "nixpkgs": "nixpkgs",
        "treefmt-nix": "treefmt-nix"
      }
    },
    "treefmt-nix": {
      "inputs": {
        "nixpkgs": [
          "nixpkgs"
        ]
      },
      "locked": {
        "lastModified": 1786901030,
        "narHash": "sha256-WSFCsDSE5ffgD2MqzkM2CYjeFiKhRF/dJUN8uedb6YE=",
        "owner": "numtide",
        "repo": "treefmt-nix",
        "rev": "27b3b12a8e6375f28ebe122f07d230ca5459bbfa",
        "type": "github"
      },
      "original": {
        "owner": "numtide",
        "repo": "treefmt-nix",
        "type": "github"
      }
    }
  },
  "root": "root",
  "version": 7
}
````)
