// lp, described by itself.
//
// Nothing here is documentation *about* the tool: this file is the tool. Tangling it produces the
// crate, the package, the example and the control files; compiling it produces the document you
// are reading.
//
// The document is arranged as an argument — from what a declaration is, through what a pass
// does with it, to the pieces that read the result back — and the tests are the gate for every
// change. Order is free here, so a chapter can be moved without moving its code.
//
// Two mechanical facts about writing here: a line that is exactly `<<name>>` is a reference,
// and `@<<name>>` is how you write such a line without it being one (D17). The prose is Typst,
// not Markdown: emphasis is *one star*.

#import "@local/lp:0.1.0": chunk, file, rule
#show: rule

= The tool, in its own words

This is the whole of `lp`: the program, the package it is written with, and the example it ships.
There is no second source — the crate, the package and the example in this repository are the
output of tangling this file, and `typst compile lp.typ` renders what you are reading.

It is a literate program, and that is not a remark about its formatting. The document is
where the thinking lives; the code is quoted into it as the evidence that makes the
thinking checkable. Reading front to back is meant to be the design walk: what a
declaration is, what a pass does with it, how the result is read back, and why each of
those choices is the one it is.

== What literate programming is, in four claims

The idea splits into four claims, and they are worth separating because a reader can accept some
of them without the others.

1. *The document is the source.* The code is tangled out of it, so there is no second copy that
   can disagree with the prose.
2. *The order belongs to the reader.* Names are resolved while tangling, not while reading, so
   the text can be arranged in the order the design is understood rather than the order the
   machine runs it.
3. *A program is written as literature.* Prose is not a comment on the code; it is where the
   thinking lives, and the code is the evidence that the thinking is real.
4. *The woven document is worth having on its own.* Here that is `typst compile lp.typ`: the same
   declarations, rendered as the page you are reading.

This document takes the first claim literally and argues for the other three by being an example
of them. The case against all four is worth stating at its strongest, because most of it is
reasonable. The payoff falls as a language gets more expressive: good names, small functions and
tests already carry much of what prose would say. The friction has a history — an extra tool
between the author and the compiler, no editor support, diagnostics pointing at generated code —
and it is why WEB and CWEB stayed niche. And reading code just got cheap, which is an argument
about the work rather than about the tool.

What those objections do not cover is the two things this document is built on: the *why*, which
was never in the code, and a single source whose drift is a check failure rather than a matter of
discipline. A stance that cannot state its opposition is not an argument.

= The package: what a declaration is

This document is written with three functions — `chunk`, `file` and `rule` — and none of them is
built into the tool. They are declared in `lit/lp.typ`, which this document produces: the syntax
and the tool that reads it share one source, so there is no second opinion about what a
declaration looks like.

`chunk` and `file` do two things each. They attach a metadata record — the name, the language
from the fence, the text — and then render the code as a titled block. That is the whole
difference between a fragment and a root: the same body, one word, and a record that says which
of the two it is. `rule` is the show rule that marks references when the document is woven.

The declarations deliberately do not depend on that show rule. A show rule that consumes an
element can hide it from a query, and that is not a hypothesis: a styling rule once made every
chunk in this project's own example vanish from the pass that collects them (ADR D12). So the
metadata is attached where the declaration is written, and rendering is free to be as decorative
as it likes afterwards.

== The shape of the package

#file("lit/typst.toml", ````toml
<<package: the manifest>>
````)

#file("lit/lp.typ", ````typst
<<package: what this file is>>

<<package: what a reference looks like>>

<<package: the escape>>

<<package: the indentation a reference contributes>>

<<package: the show rule>>

<<package: how a chunk is rendered>>

<<package: a fence without a language>>

<<package: a fragment>>

<<package: a root>>
````)

== The two patterns

The reference is a whole line: indentation, `<<`, a name without angle brackets, `>>`, and
nothing else. The indentation is captured rather than ignored, because it is part of what a
reference *means* — it is what indents the expansion when tangling, so the woven page has to show
it too, or the page disagrees with the file it claims to describe.

The second pattern is the escape, and it exists because this document quotes itself: a chapter
showing what a reference looks like has to write a line that looks exactly like one.

#chunk("package: what this file is", ````typst
// lp.typ — declare chunks for the `lp` tool.
//
// A chunk is written by calling `chunk` (a fragment, referenced as <<name>>) or
// `file` (a chunk whose name is the output path, i.e. a root). The code block is
// passed as the argument, so the declaration carries everything the tool needs —
// name, language, text — and the tool never has to read the source to find out
// what a chunk is.
//
//   #import "lp.typ": chunk, file
//
//   #chunk("imports", ```rust
//   use std::fmt;
//   ```)
//
//   #file("src/main.rs", ```rust
//   <<imports>>
//   ```)
//
// Rendering lives here too, so the document does not need show rules: a chunk
// shows up as a titled block with its references marked.
````)

#chunk("package: what a reference looks like", ````typst
// A reference line is indentation + <<name>>. The indentation is part of what a
// reference *means*: it decides how the expanded chunk is laid out when tangled,
// so the woven page has to show it — otherwise the document lies about the code.
#let ref-re = regex("^(\\s*)<<([^<>]+)>>\\s*$")
````)

#chunk("package: the escape", ````typst
// The escape: a line that starts with `@` is a reference only to the eye. Tangling
// writes it out as `<<name>>`, so a document can quote the syntax it is written in
// (ADR D17).
#let esc-re = regex("^(\\s*)@<<([^<>]+)>>\\s*$")
````)

#chunk("package: the indentation a reference contributes", ````typst
/// The indentation a reference line contributes to the expanded chunk, or "" when
/// the line is not a reference. The renderer below uses it too, so this is the
/// implementation rather than a helper kept alive for a test.
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
/// Ref marking is cosmetics, so a show rule is fine here — the *declarations*
/// below carry the semantics, and they do not depend on any show rule running.
#let rule(body) = {
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
        raw(ref-indent(line.text)) + text(fill: rgb("#0a6"))[⟪#m.captures.at(1)⟫]
      }
      out = if out == none { piece + linebreak() } else { out + piece + linebreak() }
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
// A fence without an info string has no `lang` field at all. The tag is data rather than
// a promise (ADR D18): missing means "not declared", and the tool records nothing.
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
/// A named fragment: referenced as `<<name>>`, written nowhere on its own.
#let chunk(name, code) = {
  [#metadata((lp: "chunk", name: name, lang: lang-of(code), text: code.text))<lp-decl>]
  tile(name, lang-of(code), code)
}
````)

#chunk("package: a root", ````typst
/// A root chunk: the name is the path it is tangled to.
#let file(path, code) = {
  [#metadata((lp: "file", name: path, lang: lang-of(code), text: code.text))<lp-decl>]
  tile(path, lang-of(code), code)
}
````)

= How an error is reported

Every failure in this program is one type, and it carries two things: what went wrong, and what to
do about it. There are no source spans — Typst gives no source positions, and a span could only
come from searching the source or parsing Typst again, which is not worth doing for the sake of an
underline (ADR D14). Errors name the chunk and quote the line instead.

The type is deliberately small: a message, an optional help, and the three constructors callers
actually need. Everything that renders it lives in one place (`main.rs`), so no module has to know
what an error looks like on a terminal.

== The shape of the file

#file("src/diag.rs", ````rust
<<diag: the imports>>

<<diag: what an error carries>>

impl LpError {
    <<diag: a plain error>>

    <<diag: adding advice>>

    <<diag: the io case>>
}

<<diag: what a terminal needs>>

<<diag: the standard error trait>>

<<diag: what miette needs>>
````)

== The error, and why it holds no positions

The file needs one import, and the error itself is two fields — a message and an optional
help. The reason there is no third field for a position is the subject of this section.

#chunk("diag: the imports", ````rust
use std::fmt;
````)

#chunk("diag: what an error carries", ````rust
/// A user-facing error: what went wrong, and what to do about it.
///
/// No source spans. Typst gives no source positions, so a span could only come
/// from searching the source or parsing Typst again, and that is not worth doing
/// for the sake of an underline (ADR D14). Errors name the chunk and quote the
/// line instead.
#[derive(Debug)]
pub struct LpError {
    message: String,
    help: Option<String>,
}
````)

== Three constructors

`with_help` appends rather than replaces, which is what lets a layer close to the problem add its
own context without dropping what a lower layer already said. `io` exists because the path is the
only interesting part of an I/O error here: the file that could not be read or written is exactly
what the reader needs, and the rest is noise.

#chunk("diag: a plain error", ````rust
pub fn plain(message: impl Into<String>) -> Self {
    Self {
        message: message.into(),
        help: None,
    }
}
````)

#chunk("diag: adding advice", ````rust
/// Add advice. Repeated calls append, so a caller can add its own context
/// without dropping what the error already said.
pub fn with_help(mut self, help: impl Into<String>) -> Self {
    let help = help.into();
    self.help = Some(match self.help {
        Some(existing) => format!("{existing}\n{help}"),
        None => help,
    });
    self
}
````)

#chunk("diag: the io case", ````rust
pub fn io(path: &std::path::Path, err: std::io::Error) -> Self {
    Self::plain(format!("{}: {err}", path.display()))
}
````)

== The plumbing that lets miette render it

Three trait implementations and nothing else: `Display` writes the message, `Error` makes it an
error, and `Diagnostic` hands miette the help that was collected. The fancy rendering is one call
in `main.rs`; this file only promises that there is something to render.

#chunk("diag: what a terminal needs", ````rust
impl fmt::Display for LpError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}
````)

#chunk("diag: the standard error trait", ````rust
impl std::error::Error for LpError {}
````)

#chunk("diag: what miette needs", ````rust
impl miette::Diagnostic for LpError {
    fn help(&self) -> Option<Box<dyn fmt::Display + '_>> {
        self.help
            .as_ref()
            .map(|help| Box::new(help.clone()) as Box<dyn fmt::Display + '_>)
    }
}
````)

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
<<metadata: the module note>>

<<metadata: the imports>>

<<metadata: the one query>>

<<metadata: what a declaration says>>

<<metadata: the two kinds>>

impl Decl {
    <<metadata: a kind we do not know>>
}

<<metadata: finding typst>>

/// Evaluate the documents and read their declarations.
///
/// Typst resolves `#include` against its project root, which is the directory of
/// the file being evaluated. So the wrapper is written where every document lives
/// and includes them relatively: a document outside the working directory works
/// the same as one inside it. (Writing the wrapper into the working directory, as
/// this did at first, silently refused any document that was not under it.)
pub fn declarations(typst: &Path, docs: &[PathBuf]) -> Result<Vec<Decl>, LpError> {
    <<metadata: absolute documents, and where we are>>

    <<metadata: where the wrapper goes>>
    <<metadata: ask typst, and let the wrapper go>>

    <<metadata: when the document does not evaluate>>

    <<metadata: read the answer>>
    <<metadata: a document that declares nothing>>
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

#chunk("metadata: the module note", ````rust
//! What the document declares its chunks to be.
//!
//! Typst is Turing-complete: a chunk can come from a loop, a branch, a function
//! or an `#include`d file, so the only authority is evaluation. The document
//! declares its chunks through the `lp` package (`lit/lp.typ`), whose `chunk` and
//! `file` functions take the code block as an argument and emit one metadata
//! record each:
//!
//! ```typ
//! #chunk("imports", ```rust
//! use std::fmt;
//! ```)
//!
//! #file("src/main.rs", ```rust
//! <<imports>>
//! ```)
//! ```
//!
//! A declaration carries name, language and text, so nothing has to be recovered
//! from the source afterwards — which is why the sources are not read at all.
````)

#chunk("metadata: the imports", ````rust
use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use crate::diag::LpError;
````)

#chunk("metadata: the one query", ````rust
/// Every declaration, in the order the document produced them.
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
    /// `"chunk"` or `"file"`.
    pub lp: String,
    /// The fragment's name, or the path for a file declaration.
    pub name: String,
    #[serde(default)]
    pub lang: Option<String>,
    #[serde(default)]
    pub text: String,
}
````)

#chunk("metadata: the two kinds", ````rust
/// What the two declaration functions mean.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    /// `#chunk(name, …)`: a fragment that only exists where it is referenced.
    Chunk,
    /// `#file(path, …)`: a chunk whose name is the path it is written to.
    File,
}
````)

#chunk("metadata: a kind we do not know", ````rust
/// A declaration that says something else is a mistake in the package or in
/// whatever emitted the metadata — not a fragment by default.
pub fn kind(&self) -> Result<Kind, LpError> {
    match self.lp.as_str() {
        "chunk" => Ok(Kind::Chunk),
        "file" => Ok(Kind::File),
        other => Err(LpError::plain(format!(
            "{}: unknown declaration kind {other:?}",
            self.name
        ))
        .with_help("the package emits `lp: \"chunk\"` or `lp: \"file\"`")),
    }
}
````)

== Finding typst

The binary is a hard dependency: without it there are no declarations to read. An explicit
override first, then `PATH`, and if neither works the error says what to do rather than
failing later with a confusing message.

#chunk("metadata: finding typst", ````rust
/// The package this tool is written with, compiled into the binary: a document should not have
/// to ship a copy of it to be tangled, or find one (D21). `include_str!` is the whole
/// mechanism — the standard library, no dependency, checked at compile time.
const PACKAGE_MANIFEST: &str = include_str!("../lit/typst.toml");
const PACKAGE_ENTRY: &str = include_str!("../lit/lp.typ");

/// The directory, next to a document, that the package is unpacked into. It belongs to the tool,
/// so the ownership check treats it like a control file rather than content.
pub const PACKAGE_ROOT: &str = ".lp";

/// Where a document's import (`@local/lp:0.1.0`) resolves inside that directory: namespace,
/// name, version.
const PACKAGE_DIR: &str = "local/lp/0.1.0";

/// Write the embedded package to `<root>/.lp/…` so Typst can resolve what the document imports,
/// and hand back the directory to point `--package-path` at. Only changed bytes are written, so
/// a pass in a loop does not touch the disk.
fn unpack_package(root: &Path) -> Result<PathBuf, LpError> {
    let packages = root.join(PACKAGE_ROOT);
    let dir = packages.join(PACKAGE_DIR);
    std::fs::create_dir_all(&dir).map_err(|err| LpError::io(&dir, err))?;
    for (name, text) in [("typst.toml", PACKAGE_MANIFEST), ("lib.typ", PACKAGE_ENTRY)] {
        let path = dir.join(name);
        if std::fs::read_to_string(&path).ok().as_deref() != Some(text) {
            std::fs::write(&path, text).map_err(|err| LpError::io(&path, err))?;
        }
    }
    Ok(packages)
}

/// Locate the `typst` binary: an explicit override, then `PATH`.
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
// Typst refuses to read outside its project root, and a document may import a
// package from outside its own directory, so the root has to cover the working
// directory *and* every document. The wrapper lives next to the documents (it
// must be inside the root to be readable) and includes them relatively.
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

#chunk("metadata: a document that declares nothing", ````rust
if declarations.is_empty() {
    return Err(LpError::plain("the document declares no chunks").with_help(
        "import the package and declare them: `#import \"lp.typ\": chunk, file`, then `#chunk(\"name\", ```…```)` or `#file(\"src/main.rs\", ```…```)`",
    ));
}
````)

#chunk("metadata: every kind is checked here", ````rust
for declaration in &declarations {
    declaration.kind()?;
}
````)

== A file that exists for one command

The wrapper is a temporary document holding one `#include` per document named on the command
line. It is removed when it goes out of scope, and that includes the failing and panicking
paths: a leftover `.lp-decl-*.typ` in someone's directory would surface as an unaccounted file
on the next pass, which is a bug in the user's tree caused by a tool that forgot to clean up.

#chunk("metadata: the wrapper document", ````rust
/// A wrapper document, removed when it goes out of scope — including when the
/// evaluation fails, and including on panic.
struct Wrapper {
    path: PathBuf,
}
````)

#chunk("metadata: writing the wrapper", ````rust
fn write(root: &Path, docs: &[PathBuf]) -> Result<Self, LpError> {
    let path = root.join(format!(".lp-decl-{}.typ", std::process::id()));
    let mut text = String::new();
    for doc in docs {
        let relative = doc.strip_prefix(root).unwrap_or(doc);
        // Quoted, because that is how Typst takes a path; a quote or backslash
        // in a file name must not break the wrapper open.
        let quoted = relative
            .to_string_lossy()
            .replace('\\', "/")
            .replace('"', "\\\"");
        text.push_str(&format!("#include \"{quoted}\"\n"));
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

The deepest directory containing every document, which is also the directory the wrapper is
written into. The unit test is here rather than in `tests/` because this arithmetic — walk up
until every path fits — is easy to get subtly wrong, and the failure mode is quiet: a wrapper
written outside the root is simply refused by Typst, with a message about a path, not about
this function.

#chunk("metadata: the deepest directory that contains every document", ````rust
/// The deepest directory that contains every document.
fn common_ancestor(docs: &[PathBuf]) -> PathBuf {
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
<<tangle: the module note>>

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

    Ok(Plan {
        maps,
        texts,
        warnings,
        blocks,
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

#chunk("tangle: the module note", ````rust
//! Tangling: expand chunks into whole files, write them, and record where every
//! output line came from.
//!
//! Which chunks exist is Typst's answer (`metadata.rs`), and it is the only thing
//! the tool cannot work out for itself. What is left here is our own small part:
//! `<<references>>`, indentation, writing files, and recording which chunk
//! produced which output lines.
````)

#chunk("tangle: the imports", ````rust
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use crate::diag::LpError;
use crate::map::{FileMap, LpMap, MAP_FILE, Run, split};
use crate::metadata;
````)

#chunk("tangle: a chunk as declared", ````rust
/// A chunk as the document declared it.
pub struct Block {
    /// A `file` declaration names the path it is tangled to; a `chunk` is a
    /// fragment that only exists where it is referenced.
    pub root: bool,
    pub name: String,
    pub lang: Option<String>,
    pub text: String,
}
````)

#chunk("tangle: an error quotes the line", ````rust
impl Block {
    /// An error about the `index`-th line of this chunk. It quotes the line: with
    /// no source positions to point at, the quote is what tells the reader where
    /// to look (ADR D14).
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
/// One set over every chunk of the invocation, in the order the document
/// produced them.
pub fn new(blocks: &'a [Block]) -> Self {
    let mut chunks: BTreeMap<&str, Vec<&Block>> = BTreeMap::new();
    for block in blocks {
        chunks.entry(block.name.as_str()).or_default().push(block);
    }
    Self { chunks }
}
````)

#chunk("tangle: the declared files", ````rust
/// The declared files, in the order the document declared them.
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
/// Reject declared paths that would write outside the output directory.
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
/// `<<name>>` on a line of its own, with any indentation. Anything else on the
/// line (prose, `a << b` in C++) stays literal.
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
/// A line that reads as a reference but has to stay literal: `@<<name>>` comes out
/// as `<<name>>`. A document quoting the syntax itself — this one, for example —
/// needs it (D17).
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
    /// File contents, always ending in a newline.
    pub text: String,
    /// Which chunk produced which consecutive output lines.
    pub runs: Vec<Run>,
    /// Lines written so far, so a run can be extended without counting the text.
    lines: usize,
}
````)

#chunk("tangle: one line, with its indentation", ````rust
fn push(&mut self, chunk: &str, indent: &str, line: &str) {
    self.text.push_str(indent);
    self.text.push_str(line);
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
    /// Outputs whose bytes differ from what is on disk (written unless checking).
    pub changed: Vec<Output>,
    /// Outputs that were already up to date.
    pub unchanged: Vec<Output>,
    /// Drift reports, filled only when `check` is set.
    pub stale: Vec<String>,
    /// Files under the output directory that neither a chunk nor a declaration
    /// accounts for. Non-empty means the pass failed.
    pub unaccounted: Vec<crate::status::Unaccounted>,
    pub warnings: Vec<String>,
}
````)

#chunk("tangle: the plan", ````rust
/// What the documents produce, without writing anything.
pub struct Plan {
    pub maps: BTreeMap<PathBuf, LpMap>,
    pub texts: BTreeMap<String, String>,
    pub warnings: Vec<String>,
    pub blocks: Vec<Block>,
}
````)

== Planning a pass

Planning begins by asking for the declarations — the one thing this tool cannot work out for
itself — and turning them into blocks.

#chunk("tangle: ask typst what the document declares", ````rust
let typst = metadata::binary()?;
let blocks: Vec<Block> = metadata::declarations(&typst, docs)?
    .into_iter()
    .map(|declaration| Block {
        root: declaration.kind().expect("checked") == metadata::Kind::File,
        name: declaration.name,
        lang: declaration.lang,
        text: declaration.text,
    })
    .collect();
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
reported rather than quietly filled. The two checks are separate fragments for a reason this
project keeps running into: a blank line inside a fragment that is referenced from an indented
place turns into a line of spaces, and whitespace is not layout.

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
// The language tag is data: the map records it, the woven page shows it, and downstream
// tools read it. It cannot be recovered from a file name — and this program will not try,
// because a guess dressed as data is worse than a gap — so a declaration that does not
// carry one is said out loud. It is a warning rather than an error: a `.lpignore` has no
// language to declare (D18).
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
/// What the documents produce, per directory: what `status.rs` counts against.
pub fn produced(plan: &Plan) -> BTreeMap<String, BTreeSet<String>> {
    plan.maps
        .iter()
        .map(|(dir, map)| {
            (
                dir.to_string_lossy().replace('\\', "/"),
                map.files.keys().cloned().collect(),
            )
        })
        .collect()
}
````)

== Writing the pass

`run` is the three steps in order. First the plan.

#chunk("tangle: plan, then an empty outcome", ````rust
let plan = plan(docs)?;
let documented = docs
    .iter()
    .map(|doc| doc.display().to_string())
    .collect::<Vec<_>>();
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
// A map tracks the *document*, so it can be stale even when no output byte
// moved (a line of prose shifts every mapping); `write_if_changed` compares
// content rather than the output files'. Maps for directories that stopped
// producing anything are removed with the directories themselves: the map
// travels with the files it explains.
//
// The ownership check comes first: it runs before any map is written, but *after*
// the files above, because `.lpignore` is one of the things a document can produce.
// A fresh repository has no control file yet, and the pass that writes it is the
// pass that makes the tree consistent (ADR D20).
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
    map.set_docs(documented.clone());
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
/// Every name referenced by a block, in document order.
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
        // Not references: they must survive tangling as literal text.
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
<<explain: the module note>>

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

#chunk("explain: the module note", ````rust
//! Turning a toolchain's diagnostics into chunk references.
//!
//! `lp explain` is a filter: it echoes what it reads and, for every
//! `file:line:col:` it can find in a map, prints which chunk that generated line
//! came from and how far into it the line is. Find that chunk in the document —
//! `rg '#chunk("print-results"'` — and you are at the place to edit.
//!
//! It knows nothing about any language, and it does not know `.typ` line numbers
//! either: Typst does not expose source positions (ADR D14).
````)

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
<<map: the module note>>

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

#chunk("map: the module note", ````rust
//! Which chunk produced which lines of a generated file.
//!
//! Not line numbers: Typst exposes no source positions, and recovering them would
//! mean searching the source or parsing Typst again — neither is worth doing for
//! a convenience (ADR D14). What expansion *does* know for free is which chunk
//! produced each run of output lines, and how far into that chunk the run starts.
//! That is what a map records, one per directory, next to the files it explains.
````)

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
const VERSION: u32 = 5;
````)

== What a map holds

Three structures, all serde-shaped, because the file's format is the interface: a map, the
entry for one file, and one run of lines.

#chunk("map: what a map holds", ````rust
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
````)

#chunk("map: read one map", ````rust
pub fn read(dir: &Path) -> Result<Self, LpError> {
    let path = dir.join(MAP_FILE);
    let text = std::fs::read_to_string(&path).map_err(|err| LpError::io(&path, err))?;
    serde_json::from_str(&text)
        .map_err(|err| LpError::plain(format!("{}: {err}", path.display())))
}
````)

The search is two fragments rather than one: the guard for an output directory that does
not exist yet, and the walk. That split is also a lesson about blank lines — a fragment
that carries one drags its indentation along when it is pulled into an indented place, so
the blank line between these two thoughts stays in the skeleton where it belongs to no
fragment at all.

#chunk("map: when there is no output directory", ````rust
/// Every map under `out`, paired with its directory relative to `out` (`""`
/// for the output directory itself), in a stable order.
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
````)

== Paths, in one shape

Every path in this module is a string with forward slashes, and the output directory itself
is the empty string. Those strings travel through Typst declaration names, through
diagnostics written by other tools, and through JSON, so the shape is fixed once here
rather than re-derived at each use.

#chunk("map: paths, in one shape", ````rust
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
<<status: the module note>>

<<status: the imports>>

<<status: the file that says what lp does not manage>>

<<status: what a directory of strays looks like>>

/// Everything under the output directory that no chunk produces and no
/// declaration owns.
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

<<status: lp's own control files are never content>>

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

#chunk("status: the module note", ````rust
//! What nothing accounts for.
//!
//! Every file under the output directory falls into exactly one of three groups:
//!
//! * **produced** — a `#file` declaration writes it;
//! * **declared** — a `.lpignore` says *"lp does not manage this"*;
//! * **unaccounted** — neither. Nothing explains why it is there.
//!
//! The third group is the one worth reporting: a file a chunk should probably
//! produce, a file to declare, or stale output to delete — and only the user knows
//! which. Nothing here deletes anything; `delete` is called from
//! `lp unaccounted --delete` and never as a side effect of tangling.
//!
//! Point `--out` at a directory and the whole directory is `lp`'s, at any depth.
//! The `.lpignore` rules say what is not, and the crate's own walker applies them
//! — nested files, deepest wins, whitelists — so there is no second
//! implementation of that logic here.
````)

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
/// The file in which a directory declares what `lp` does not manage.
pub const IGNORE_FILE: &str = ".lpignore";
````)

== What a directory of strays looks like

The report is grouped by directory, because the fix is per directory: each group is one
directory and the entries nothing accounts for inside it. An entry that ends in a slash
means a whole subtree was compressed into one line — which is why entries are strings and
not paths.

#chunk("status: what a directory of strays looks like", ````rust
/// Entries in one directory that nothing accounts for.
#[derive(Debug)]
pub struct Unaccounted {
    /// Directory relative to the output directory (`""` for the output itself).
    pub dir: String,
    /// File or directory names, a directory marked with a trailing `/`.
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
// What the walker yields is content: it applies every `.lpignore` in the tree
// as it descends, so a declared file — or a whole declared directory — never
// reaches this loop.
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
    if !entry.file_type().is_some_and(|kind| kind.is_file()) {
        continue;
    }
    let path = entry.path();
    if is_control_file(path) {
        continue;
    }
    let rel = relative(out, path);
    // The directory the package is unpacked into is the tool's own scratch space, like the two
    // control files: a document does not have to declare it, and neither does a project (D21).
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
    // A compressed entry keeps its trailing slash so a reader can tell a
    // directory from a file.
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

== Two files that are never content

The map and the ignore file are the two names `lp` reserves, and they are exempt from the
report: a file that exists to explain the others is not one of them. The directory the package
is unpacked into is exempt for the same reason — it is the tool's own scratch space, and a
document that had to declare it would not be self-contained.

#chunk("status: lp's own control files are never content", ````rust
/// `lp`'s own control files are never content, and neither is the directory it unpacks its
/// package into.
fn is_control_file(path: &Path) -> bool {
    path.file_name()
        .is_some_and(|name| name == MAP_FILE || name == IGNORE_FILE)
}
````)

== A build directory is one line

One constant, and its value is a judgement: eight entries is where a list stops being readable
and naming the directory starts being more useful.

#chunk("status: when a subtree is too big to list", ````rust
/// Beyond this many entries a subtree stops being listed file by file and is
/// named as a directory instead: a build directory is one line, not thousands.
const COMPRESS_ABOVE: usize = 8;
````)

#chunk("status: compressing a subtree", ````rust
/// Turn the unaccounted files into the entries to show, compressing a directory
/// that carries too many of them.
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
/// Delete everything nothing accounts for.
///
/// This is the only way `lp` ever removes a file, and it never happens as a side
/// effect of tangling: stale output is either declared (then it is accounted for)
/// or deleted on request.
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
        // The full path, so a line here can be copied, grepped, or declared
        // as it stands.
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

Four unit tests, in the file they test rather than in `tests/`, because they are about one
function and need no binary: produced files are accounted for however deep they are,
declared files are accounted for even in a nested directory, a subtree that overflows is
named once at the directory that overflows, and everything under the output directory is
ours at any depth.

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
            [names("", &["produced.txt"])].into_iter().collect();
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
            [names("", &["produced.txt"])].into_iter().collect();
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
<<watch: the module note>>

<<watch: the imports>>

<<watch: what the command line passes in>>

pub fn run(options: Options) -> Result<(), LpError> {
    <<watch: one debouncer, one channel>>

    <<watch: the directories, not the files>>

    <<watch: say what is being watched>>

    <<watch: pass once, then wait>>
    Ok(())
}

/// One pass. `initial` only changes the wording when there is nothing to do.
/// Returns whether the pass rewrote anything.
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

#chunk("watch: the module note", ````rust
//! `lp watch`: keep the generated files in step with the document while it is
//! being edited, and fuse the check loop in.
//!
//! Three properties matter more than raw speed here:
//!
//! 1. **Only real changes are written.** A pass compares the tangled bytes with
//!    what is on disk, so files that did not change keep their mtime — cargo and
//!    rust-analyzer stay asleep instead of rebuilding the world on every keypress.
//! 2. **Half-written documents are not tangled.** Mid-edit states are normal, so a
//!    syntax error prints and skips the pass, leaving the last good output alone.
//! 3. **Editor events are coalesced.** `notify`'s debouncer plus draining our own
//!    writes means one pass per burst, not one per keystroke.
//!
//! ponytail: every pass re-reads and re-parses the whole document and re-expands
//! every root (measured: ~1ms for 2k lines, see agent-notes). Reverse-reachability
//! and `typst-syntax`'s reparser are only worth it if that ever shows up in a
//! profile on a book-sized document.
````)

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
    /// Run after a pass that changed something, e.g.
    /// `cargo build --message-format=short`.
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
// Watch the containing directories, not the files: editors save by renaming a
// temporary file over the target, which drops a file-level watch.
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
// Drop events queued while we were working (our own writes included) so a
// single edit cannot trigger a second, useless pass.
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
// Report even when nothing was written: deleting a root chunk leaves a file
// behind without changing any other output.
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
// Same translation as `lp explain`, reading the maps we just wrote.
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
<<main: the modules, and what they are called>>

<<main: the surface, as clap sees it>>

#[derive(Subcommand)]
enum Command {
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

/// Where tangled files go: the directory that was named, or `tangled` next to the documents —
/// `tangled` in the working directory for a command that takes no documents. The document is what
/// decides, because it is the document's output.
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
mod diag;
mod explain;
mod map;
mod metadata;
mod status;
mod tangle;
mod watch;

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

#chunk("main: tangle", ````rust
/// Expand a .typ document into its source files
Tangle {
    /// Documents to tangle, e.g. tangled/examples/demo/literate.typ
    #[arg(required = true)]
    docs: Vec<PathBuf>,
    /// Directory the root chunk names resolve into (default: tangled/ next to the
    /// documents, or in the working directory for commands that take none)
    #[arg(long)]
    out: Option<PathBuf>,
    /// Write nothing; fail if the generated files are out of date
    #[arg(long)]
    check: bool,
},
````)

#chunk("main: map", ````rust
/// Tell which chunk produced a line of a generated file (or the reverse)
Map {
    /// Generated file, relative to --out (a unique basename also works)
    #[arg(long, conflicts_with = "typ")]
    file: Option<String>,
    /// Reverse mode: list the generated lines that came from this chunk
    #[arg(long, conflicts_with = "file")]
    typ: Option<String>,
    /// Line of the generated file (required with --file)
    #[arg(long)]
    line: Option<usize>,
    #[arg(long)]
    out: Option<PathBuf>,
},
````)

#chunk("main: explain", ````rust
/// Rewrite diagnostics so they name the chunk that produced the line
Explain {
    #[arg(long)]
    out: Option<PathBuf>,
},
````)

#chunk("main: watch", ````rust
/// Keep the generated files in step while the document is edited
Watch {
    /// Documents to watch, e.g. tangled/examples/demo/literate.typ
    #[arg(required = true)]
    docs: Vec<PathBuf>,
    #[arg(long)]
    out: Option<PathBuf>,
    /// Coalesce editor events for this many milliseconds
    #[arg(long, default_value_t = 200)]
    debounce: u64,
    /// Command to run after a pass that changed something, e.g.
    /// 'cargo build --message-format=short'; its diagnostics get translated
    #[arg(long)]
    check_cmd: Option<String>,
},
````)

#chunk("main: list", ````rust
/// List the chunks a document declares
List { doc: PathBuf },
````)

`list` and `metadata` are the two commands that exist for the person debugging a document
rather than for the build. They answer the questions a reader of this document asks all the
time — which chunks exist, in what order, and what does Typst actually hand over — and they do
it without writing anything.

#chunk("main: metadata", ````rust
/// Ask the documents which chunks they have, in order
Metadata {
    /// Documents to ask, e.g. book.typ chapter.typ
    #[arg(required = true)]
    docs: Vec<PathBuf>,
},
````)

#chunk("main: unaccounted", ````rust
/// List (or delete) files under the output directory that nothing accounts for
Unaccounted {
    /// Documents that decide what counts as produced
    #[arg(required = true)]
    docs: Vec<PathBuf>,
    #[arg(long)]
    out: Option<PathBuf>,
    /// Delete them: the explicit alternative to declaring them
    #[arg(long)]
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
        // Reverse: which generated lines came from this chunk?
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
    // Where to edit: the chunk, and how far into it this line is. Typst
    // exposes no source positions, so a name is the pointer (ADR D14).
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
<<flow: the file's purpose>>

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
- `a_chunk_built_by_code_is_attributed_to_itself` — roots declared by a loop are attributed to the declarations the loop produced
- `the_declaration_is_where_the_line_lives` — the answer includes the `rg` command that finds the declaration

#chunk("flow: the file's purpose", ````rust
//! End-to-end tests: they run the real binary against throwaway documents.
````)

#chunk("flow: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

/// A document in the real authoring form: the package is imported, its rules are
/// installed, and the body declares chunks.
fn document(body: &str) -> String {
    format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}")
}

/// One file declaration, a shared fragment, a fragment written in two pieces,
/// and a code sample that is not a chunk at all.
///
/// The two references are spliced in rather than written on lines of their own:
/// a line that is exactly `<<name>>` would be expanded when this file is tangled
/// (ADR D15, `agent-notes/decisions/2026-09-11-self-hosting-layout.md`).
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
    // No source positions anywhere: a run says which chunk, and which lines it covers.
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

#chunk("flow: a_chunk_written_indented_in_the_document_is_still_dedented", ````rust
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
````)

#chunk("flow: a_chapter_can_hold_the_fragment_another_file_references", ````rust
#[test]
fn a_chapter_can_hold_the_fragment_another_file_references() {
    // Documents are chapters of one program: prose in one, the fragment in another,
    // the file that pulls them together in a third.
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

    // A run with no file declarations anywhere is still an error.
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

#chunk("flow: the_map_follows_the_document_even_when_no_output_byte_changes", ````rust
#[test]
fn the_map_follows_the_document_even_when_no_output_byte_changes() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    // Prose above the declarations shifts nothing in the output; the map must
    // still be rewritten so it keeps describing the document.
    let moved = format!(
        "{}\n{}",
        "#import \"lp.typ\": chunk, file, rule\n#show: rule", DOC
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
````)

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

    // Reverse: which generated lines came from that chunk?
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
    // The declaration is written once, inside a loop. There is no line to point at
    // and none is invented; the chunk it produced is named instead.
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
    // A sanity check that the document text itself is what the chunk quotes back,
    // which is what makes "find it with rg" work.
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
<<lazy: the file's purpose>>

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

#chunk("lazy: the file's purpose", ````rust
//! The lazy contract: a pass touches only what actually changed, refuses to
//! tangle a document that does not evaluate, and keeps the line map usable in
//! both directions.
````)

#chunk("lazy: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

/// The two references are spliced in: a line that is exactly `<<name>>` would be
/// expanded when this file is tangled (ADR D15).
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
    let text = format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}");
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

    // Mid-edit, the document does not evaluate: nothing is tangled and the last
    // good output stays where it is.
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

    // Forward: which chunk produced this generated line?
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

    // Reverse: which generated lines came from that chunk?
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
<<metadata: the file's purpose>>

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

#chunk("metadata: the file's purpose", ````rust
//! The declaration side: what the document says its chunks are.
//!
//! These tests need the `typst` binary (the tool asks the document, it does not
//! read it), so they skip cleanly when it is not on PATH.
````)

#chunk("metadata: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

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

/// Write the package and a document that imports it.
fn write(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.join(name),
        format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}"),
    )
    .expect("doc");
}
````)

#chunk("metadata: a_styling_show_rule_does_not_hide_a_chunk", ````rust
#[test]
fn a_styling_show_rule_does_not_hide_a_chunk() {
    // The declaration is what the tool reads, and it is emitted before the block
    // is rendered — so even a show rule that throws the element away cannot hide
    // a chunk. (An instrumented show rule could not survive this; a declaration
    // does not care.)
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
    // Typst merges #include'd content, so the tool does not need to be told about
    // every file — the document already says.
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

    // The output line is attributed to the declaration that produced it.
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

    // The chunks built by the loop are tangled like any other.
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

#chunk("metadata: a_document_outside_the_working_directory_can_be_tangled", ````rust
#[test]
fn a_document_outside_the_working_directory_can_be_tangled() {
    // The wrapper document has to live where Typst's root can reach the file it
    // includes, so it goes next to the documents rather than in the cwd.
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

    // And the wrapper is gone again.
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
````)

#chunk("metadata: a_declaration_of_an_unknown_kind_is_an_error", ````rust
#[test]
fn a_declaration_of_an_unknown_kind_is_an_error() {
    // Only `chunk` and `file` exist; anything else means the package and the tool
    // disagree, and that must not be read as a fragment.
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
    // No copy of the package next to it, no environment variable, no git: the tool carries the
    // package and unpacks it for Typst (D21).
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("alone.typ"),
        "#import \"@local/lp:0.1.0\": chunk, file, rule\n#show: rule\n\n#file(\"main.py\", ```py\n<<body>>\n```)\n\n#chunk(\"body\", ```py\nprint('alone')\n```)\n",
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
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("declares no chunks"), "{message}");
    assert!(
        message.contains("#file("),
        "the remedy belongs there: {message}"
    );
}
````)

=== tests/owned.rs — who owns the output directory

Ownership is the part of the tool that can destroy a user's work if it is wrong, so it has the
most cases per line of code: what is accounted for, what is not, which ignore rules count, and
what `--check` and `--delete` each do.

#file("tests/owned.rs", ````rust
<<owned: the file's purpose>>

<<owned: the fixtures and helpers>>

<<owned: a_dropped_declaration_is_an_error_until_it_is_resolved>>

<<owned: declared_files_are_accounted_for>>

<<owned: the_pattern_language_is_gitignores>>

<<owned: a_deeper_ignore_file_can_take_a_file_back>>

<<owned: control_files_survive_and_other_dotfiles_are_ordinary_files>>

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
- `control_files_survive_and_other_dotfiles_are_ordinary_files` — the map and the ignore file are never content, and every other dotfile is
- `a_git_directory_is_ordinary_content` — `.git/` is not special-cased, so it has to be declared like anything else
- `check_reports_a_stray_without_removing_it` — `--check` lists a stray and changes nothing
- `deleting_a_foreign_subtree_takes_one_line_and_one_command` — one compressed entry, one `--delete`, and a subtree is gone
- `without_a_declaration_a_stray_is_still_an_error` — with no `.lpignore` at all, strays are still errors
- `a_missing_output_directory_is_not_an_io_error` — a missing output file is drift, not an I/O failure
- `the_unpacked_package_is_not_content` — the directory the tool unpacks its package into is never reported

#chunk("owned: the file's purpose", ````rust
//! Nothing under the output directory may go unaccounted for.
//!
//! A file is either produced by a declaration, declared in a `.lpignore`, or an
//! error the user resolves — by declaring it, or by deleting it on purpose. `lp`
//! never removes anything on its own, and it never lets a stray file pass
//! silently.
````)

#chunk("owned: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

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

/// Write a document in the real authoring form, plus the package it imports.
fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}");
    std::fs::write(dir.join(name), &text).expect("doc");
    text
}

/// A project tangled into an output directory with the given declaration.
fn tangled(declaration: &str, extra: &[(&str, &str)]) -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    if !declaration.is_empty() {
        std::fs::create_dir_all(dir.path().join("out")).expect("out");
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

/// The same document without the `src/b.py` declaration.
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

    // The leftover is an error, not something quietly removed.
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

    // The report agrees, and says so with its exit code.
    let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(report.status.code(), Some(1));
    assert!(stdout(&report).contains("src/b.py"), "{}", stdout(&report));

    // One remedy: declare it. Then everything is accounted for again.
    let mut declaration = std::fs::read_to_string(dir.join("out/.lpignore")).expect("ignore");
    declaration.push_str("src/b.py\n");
    std::fs::write(dir.join("out/.lpignore"), &declaration).expect("ignore");
    let declared = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(declared.status.success(), "{}", stderr(&declared));
    assert!(dir.join("out/src/b.py").exists(), "declared, so kept");

    // The other: delete it deliberately.
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

#chunk("owned: control_files_survive_and_other_dotfiles_are_ordinary_files", ````rust
#[test]
fn control_files_survive_and_other_dotfiles_are_ordinary_files() {
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
        "the line map is never content"
    );
    assert!(dir.join("out/.lpignore").exists(), "nor are the rules");
    assert!(dir.join("out/kept.dot").exists(), "listed, so kept");
}
````)

#chunk("owned: a_git_directory_is_ordinary_content", ````rust
#[test]
fn a_git_directory_is_ordinary_content() {
    // Nothing is special-cased, not even a repository: built here rather than by
    // the helper because the first tangle is supposed to fail.
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

    // The escape hatch is the declaration, like for anything else.
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

#chunk("owned: deleting_a_foreign_subtree_takes_one_line_and_one_command", ````rust
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
````)

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
<<self: the file's purpose>>

<<self: the fixtures and helpers>>

<<self: the_document_regenerates_the_sources_we_are_running>>
````)

The cases, in the order they appear:

- `the_document_regenerates_the_sources_we_are_running` — the binary reproduces the sources it was built from, byte for byte

#chunk("self: the file's purpose", ````rust
//! Self-reproduction: the document has to regenerate the crate it ships.
````)

#chunk("self: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::Command;
````)

#chunk("self: the_document_regenerates_the_sources_we_are_running", ````rust
/// The document is the source of the files that are compiled, so `--check` in the
/// crate root has to be clean. This is the permanent half of the fixed point:
/// Stage 1 also required the output to equal the frozen seed, which stopped
/// being true the moment the document was refactored (ADR D15); the seed is a
/// branch now, and it is refreshed from this same tree.
#[test]
fn the_document_regenerates_the_sources_we_are_running() {
    // The crate lives in `tangled/`, one level below the document it is generated from.
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("repository root");
    let output = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["tangle", "lp.typ", "--check"])
        .current_dir(root)
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

<<env: which worlds it keeps out>>

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

#chunk("env: which worlds it keeps out", ````toml
# The old probes are their own little worlds: nothing here depends on them, and
# saying so keeps the resolver out of their manifests.
[workspace]
exclude = ["agent-notes/experiments/*"]
````)

#chunk("env: the runtime dependencies", ````toml
[dependencies]
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
tempfile = "3"
````)

= What this repository carries

`lp` treats its output directory as its own and refuses to guess: every file under it
is produced by a declaration or listed in the `.lpignore` of its directory. Here the
output directory is the repository root, so what this document does *not* produce is
whatever is not the crate, the package, the example or a control file — and the lock
files cargo and nix maintain, which no chunk has any business owning.

#file(".lpignore", ````gitignore
# What the tangled tree carries besides the document's output.
#
# Matching here means *protect* (ADR D10): every file under the output directory is either
# produced by a #file declaration or listed here, and this lists what the document does not
# produce. The output directory is `tangled/`, the crate the document generates.

# `tangled/` is a repository of its own, so that the generated code has a history separate
# from the document's (the bootstrap makes it one; `git init tangled`). Its metadata and its own
# ignore rules are not content, and these are the two lines that say so.
/.git
/.gitignore

# cargo's own files, and the example's build directory — whose own .lpignore governs what is
# inside it, because a nested document's output is not this document's business.
/Cargo.lock
/target
/examples/demo/build
````)

= What git is asked to ignore

Everything under `tangled/` is generated, so the whole directory is ignored: the crate, the
package, the example, the protect list and the maps. What is tracked at the root is the document,
the notes, the pointer — and one `.gitignore`, because a file that ignores the output directory
cannot be inside it. `README.md` is that pointer and `AGENTS.md` is a symlink to it: the two names
exist because tools look for different ones, and a symlink is the only way to have two names and
still one text. The notes are the other half of the repository, and the conventions for working in
it are a note: `agent-notes/README.md` is the index, `agent-notes/decisions/` holds the records
behind the rules, `agent-notes/working-agreements.md` the process — worktrees, the borrowed
toolchain, what a note is for. The seed is not tracked in the working tree either: it is a branch
of this same repository, which is the one place output can live without being a file next to the
document.

= Starting from nothing

A fresh clone holds five things and nothing else: this document, the notes, the two names at the
root that point here — one file, one symlink to it — and the `.gitignore` that keeps the output out
of git. Everything else is produced
by tangling — except the one thing this document cannot produce for itself, the binary that reads
it, because the package has to exist before the document can be evaluated at all.

That is the seed, and it is not a file in the tree: it is a branch. One whole older generation — a
crate and the package it is built with — sits at its root, ready to unpack:

```sh
seed_ref=$(git rev-parse --verify --quiet seed || git rev-parse --verify --quiet origin/seed)
mkdir -p tangled
git archive "$seed_ref" | tar -x -C tangled        # the previous generation, into tangled/
git init -q tangled                                # the generated code gets its own history
cargo build --manifest-path tangled/Cargo.toml
./tangled/target/debug/lp tangle lp.typ            # writes to tangled/, next to the document
cargo test --manifest-path tangled/Cargo.toml
```

A clone is enough; there is no second remote to fetch from. `origin/seed` is the fallback for the
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
example, protect list. Its own history is what makes it readable a generation later, which is the
whole trick: the seed was never a special artifact, only an older generation of this.

That tree is a copy that can be read on its own, and it is a repository, but it is not this
repository: nobody edits the generated code, and its first commit is a judgement about the program
rather than about the document. One generation per commit is worth recommending — the tree is a
whole program, so a diff across it says what the program did before and does now — and that is as
far as the recommendation goes. Nothing here commits, and nothing here should: when a generation is
worth keeping is the writer's call, not the tool's.

The one thing that tree needs from you is its own `.gitignore`, because the root's does not reach
inside it. The tool's state and cargo's are not a program:

```gitignore
# The tool's own state, and what cargo builds — wherever in the tree they land.
.lp
.lpmap.json
target

# The example's build directory is a nested document's output; that document says what is inside.
examples/demo/build
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

= Keeping the seed branch in step

The seed only ever reads, and it is output: the same tree the tangle writes, committed at the root
of its own branch instead of being kept in the working tree. Refreshing it belongs to a change, not
to a ceremony — tangle the document, then commit the tree to the branch:

```sh
./tangled/target/debug/lp tangle lp.typ      # the tree is this generation now
agent-notes/dev.sh seed                      # ... and the branch carries it
```

The task is four plumbing commands: a temporary index, a temporary work tree filled from
`tangled/`'s own repository, `git commit-tree` with the previous seed as parent, and
`git update-ref` on `refs/heads/seed`. It never touches the working tree of `main` — and it cannot
simply add `tangled/`, because a directory holding a `.git` is a repository, and git will not add
what is inside one.

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
- `target/` and the example's `build/`, which the build and the nested document produce rather than
  this document.

So the seed is the program, not the state around it: a generation to read, to build, and — in the
one case where that matters — one to bootstrap from. Being a program is also the test: if the
bootstrap in "Starting from nothing" runs green from the branch alone, the branch carries enough,
and nothing else needs a rule.

Only one property is required of the seed: it must be a generation that can read this document, and
one generation behind is enough. Being the current one is better, so refresh it whenever the tree
changes — which is exactly what `--check` cannot tell you, since it guards the tree, not the
branch.

= The rules

These are not style preferences; each one was paid for. The decisions behind them are in
`agent-notes/decisions/`.

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
  the example, the control files. The seed is output too, and lives on its own branch for bootstrap
  reasons — a fresh clone has no binary to tangle with. It is the same guarded tree, one
  `dev.sh seed` behind.
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
- *Dependencies are chosen from mature crates* (D7); every new one gets a line saying
  why. `typst` is a hard dependency of tangling (`LP_TYPST`, then `PATH`).

= The example: the same tool, used on something small

`tangled/examples/demo/` is a small Rust crate written as one document: one fragment shared by two
files, indentation that matters, a woven PDF, and a real rustc error translated back to the chunk
it came from. It is here because it is the loud half of every claim this document makes — `run.sh`
fails when the tool stops working, and it runs with the tests.

It is also the best answer to the question this document keeps asking itself. The example *is* a
literate program, and it is a separate one: its own document, its own sections, its own
record of decisions. So its sections are fragments of this document in exactly the same way
the chapters above are — which is the point being made, made twice.

#file("examples/demo/literate.typ", ````typst
<<demo: the document's opening>>

<<demo: the manifest>>

<<demo: the library>>

<<demo: the binary>>

<<demo: the shared preamble>>

<<demo: the module body>>

<<demo: what main prints>>

<<demo: running the result>>

<<demo: who owns that directory>>

<<demo: when it breaks>>
````)

== What the example demonstrates

Its document is tangled into `tangled/examples/demo/` — the tree is where it lives, and the
commands inside its own document are written from there, which is also where `run.sh` runs them.

The order of its sections is the argument of a much smaller program, and it is worth reading as
one: what the crate is, the three files as skeletons, then the pieces each in the section that
explains it, then how to run it, who owns the directory it writes into, and what a broken build
looks like after the error has been translated.

The last section is the one to keep in mind while reading the rest of this document: an error that
points at a chunk is the difference between a generator and a tool you can debug.

#chunk("demo: the document's opening", ````typst
#import "@local/lp:0.1.0": chunk, file, rule
#show: rule

#set page(width: 15cm, height: auto, margin: 2cm)
#set text(size: 10pt)

= A multi-file crate, written as one document

This document is a normal Typst file — `typst compile examples/demo/literate.typ`
renders it. It is also the only source of a small Rust crate: every `#file(...)`
declaration names a real file to write when you run

```sh
lp tangle examples/demo/literate.typ --out examples/demo/build
```

Text like this never reaches the generated code. `#chunk("name", …)` declares a
fragment and chunks pull each other in with `<<name>>`. The order below is a
choice: the three files first, as skeletons that name what they need, then each
piece in the section that explains it. Pieces first and assembly last would be
just as legitimate — the argument decides, not the tool — and this document says
so in its first paragraph because a reader should know which shape they are in.
````)

#chunk("demo: the manifest", ````typst
== The manifest

The crate is its own workspace so the surrounding repository's `Cargo.toml`
does not claim it.

#file("Cargo.toml", ```toml
[package]
name = "lp-demo"
version = "0.0.0"
edition = "2024"

# `lp` output is standalone; keep it out of the parent workspace.
[workspace]
```)
````)

#chunk("demo: the library", ````typst
== The library

Two thirds of the crate: a banner comment it shares with the binary, and one
module. Neither is spelled out here — the sections below do that, in the order a
reader wants them.

`` `<<math-items>>` `` sits inside a module, so its two chunks are indented by four
spaces on the way out:

#file("src/lib.rs", ```rust
@<<crate-preamble>>

pub mod math {
    @<<math-items>>
}
```)
````)

#chunk("demo: the binary", ````typst
== The binary

The entry point: the same banner, the library's module, and whatever `main`
prints.

#file("src/main.rs", ```rust
@<<crate-preamble>>

use lp_demo::math;

fn main() {
    @<<print-results>>
}
```)
````)

#chunk("demo: the shared preamble", ````typst
== The shared preamble

Both crate roots want the same banner comment at the top. It is not something
`lp` injects: the tool writes exactly the chunks you give it, nothing else. This
is just a chunk that two different root chunks happen to pull in — the same text
in two files, written once:

#chunk("crate-preamble", ```rust
//! generated by lp from literate.typ — edit the document, not this file
```)
````)

#chunk("demo: the module body", ````typst
== The module body

The module has two functions, declared as two separate `#chunk("math-items", …)`
blocks. Tangling concatenates declarations sharing a name, in document order, the
way noweb and org-babel do. The first one:

#chunk("math-items", ```rust
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```)

and the second one, which the reader meets right where it belongs:

#chunk("math-items", ```rust
pub fn square(x: i32) -> i32 {
    x * x
}
```)
````)

#chunk("demo: what main prints", ````typst
== What `main` prints

#chunk("print-results", ```rust
println!("add(2, 3) = {}", math::add(2, 3));
println!("square(5) = {}", math::square(5));
```)
````)

#chunk("demo: running the result", ````typst
== Running the result

```sh
lp tangle examples/demo/literate.typ --out examples/demo/build
cargo run --quiet --manifest-path examples/demo/build/Cargo.toml
```

```
add(2, 3) = 5
square(5) = 25
```
````)

#chunk("demo: who owns that directory", ````typst
== Who owns that directory

`examples/demo/build/.lpignore` declares it as ours: every file in there that no
chunk produces gets removed, and the ones listed in the file are left alone —
cargo's `target/` and `Cargo.lock`, the woven PDF, the PNGs. Delete a root chunk
here and its file follows, instead of lingering for `cargo` to compile.

The rule is simple: point `--out` at a directory and that whole directory is
`lp`'s. Every file in it must be either produced by a chunk or declared in an
`.lpignore`. Anything else is an error — `lp tangle` fails and names it — and the
two ways out are to declare it, or to delete it on purpose with
`lp unaccounted --delete`. `lp` never removes anything by itself.
````)

#chunk("demo: when it breaks", ````typst
== When it breaks

If that binary stops compiling, the error is reported against the *generated*
file — `src/main.rs:6:5: cannot find function ...`. `lp` records which chunk
produced every generated line, so the diagnostic can be translated back:

```sh
cargo build --manifest-path examples/demo/build/Cargo.toml --message-format=short 2>&1 \
  | lp explain --out examples/demo/build
```

That is the difference between this and a preprocessor that only knows how to
dump text: the generated code stays accountable to the prose it came from.
````)

== The harness, and the files it owns

The example is a document *and* a script. `run.sh` is what makes it a claim rather than an
illustration: it tangles the crate, builds it, runs it, compares the output with what the
document says it should be, weaves the PDF, checks for drift, and then breaks one line on
purpose so that a real rustc error can be translated back to the chunk it came from.

The files in `tangled/examples/demo/build/` are the demonstration's own territory, and its `.lpignore`
says which of them other tools own — cargo's directory and lock file, the PDF, the frames
`run.sh` produces for the transcript.

Two of its steps are plain `typst` rather than `lp`, and those need the package path that the
tangle unpacked: `TYPST_PACKAGE_PATH` is set to it for the weave and for the probe of the
renderer. That is the one place a user of this tool has to know about the unpacking at all, and
it is the same line their editor would need.

One thing to know about tangled scripts: a file the tangle writes has ordinary permissions, so a
shell script comes out readable and not executable. `bash run.sh` is the way in, and a project
that wants the bit set can `chmod` it or declare it in its build; the tool will not decide by
looking at the name.

#file("examples/demo/run.sh", ````bash
<<demo: the harness>>
````)

#chunk("demo: the harness", ````bash
#!/usr/bin/env bash
# The whole flow: tangle, build and run the result, weave, drift check, and
# translating a real rustc error back into the document.
# Run with: bash examples/demo/run.sh (typst and cargo on the path)
set -euo pipefail
cd "$(dirname "$0")/../.."          # the tangled tree, which holds this crate

LP=(cargo run --quiet --manifest-path Cargo.toml)
DOC=examples/demo/literate.typ
OUT=examples/demo/build

# The weave below is plain `typst`, not `lp`, so it needs the package path the tangle unpacked
# (`lp` passes it to its own Typst call; a user's editor has to set it the same way).
export TYPST_PACKAGE_PATH="$PWD/examples/demo/.lp"

echo "== tangle =="
"${LP[@]}" tangle "$DOC" --out "$OUT"

echo "== run the tangled crate =="
cargo run --quiet --manifest-path "$OUT/Cargo.toml" > "$OUT/run.txt"
diff -u examples/demo/expected.txt "$OUT/run.txt" && echo "output matches the document"

echo "== weave (PDF in $OUT) =="
typst compile --root . "$DOC" "$OUT/demo.pdf"

# A reference line's indentation decides the indentation of the expanded chunk, so
# the woven document has to show it (regression: it used to render flush left).
echo "== weave: references keep their indentation =="
indent=$(typst eval '{ import "@local/lp:0.1.0": ref-indent; ref-indent("    <<print-results>>") }')
if [ "$indent" != '"    "' ]; then
    echo "FAIL: reference indentation is lost when weaving (got $indent)" >&2
    exit 1
fi
echo "reference indent survives: $indent"

echo "== drift check =="
"${LP[@]}" tangle "$DOC" --out "$OUT" --check

echo "== which chunk produced src/main.rs:6 =="
"${LP[@]}" map --file src/main.rs --line 6 --out "$OUT"

echo "== translate a real rustc error =="
sed -i 's/math::add(2, 3)/math::ad(2, 3)/' "$OUT/src/main.rs"
cargo build --manifest-path "$OUT/Cargo.toml" --message-format=short 2>&1 | "${LP[@]}" explain --out "$OUT" || true

echo "== restore =="
"${LP[@]}" tangle "$DOC" --out "$OUT" > /dev/null
"${LP[@]}" tangle "$DOC" --out "$OUT" --check && echo "document and generated code agree"
````)

#file("examples/demo/expected.txt", ````text
<<demo: what the output must be>>
````)

#chunk("demo: what the output must be", ````text
add(2, 3) = 5
square(5) = 25
````)

#file("examples/demo/build/.lpignore", ````gitignore
<<demo: what cargo owns in the build directory>>
````)

#chunk("demo: what cargo owns in the build directory", ````gitignore
# This directory belongs to lp: a file here that no chunk produces is removed.
# These are the ones other tools own, plus the weave output.
Cargo.lock
target/
*.pdf
*.png
run.txt
````)
