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

#import "@local/lp:0.1.0": chunk, file, tangle-options, show-rule
#show: show-rule

// Where the tangled tree keeps this book, so that a tree can be read — and re-tangled — without the
// repository it came from. The tree's own `.gitignore` travels with it: the book is the whole of what
// this repository was before tangling, not only its prose.
#tangle-options((book-directory: "book", book-files: ("*.typ", "README.md", ".gitignore")))

= The tool, in its own words

This is the whole of `lp`: the program, the package it is written with, and the example it ships.
There is no second source — the crate, the package and the example in this repository are the
output of tangling this file, and `lp weave lp.typ lp.pdf` renders what you are reading — which is
`typst compile` with the package this tool unpacks already in scope.

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
4. *The woven document is worth having on its own.* Here that is `lp weave lp.typ lp.pdf`: the same
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
chunk in this project's own example vanish from the pass that collects them (ADR D12). So the
metadata is attached where the declaration is written, and rendering is free to be as decorative
as it likes afterwards.

== The shape of the package

#file("typst/typst.toml", ````toml
<<package: the manifest>>
````)

#file("typst/lp.typ", ````typst
<<package: what this file is>>

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

== Settings, and why they are a dict

Not everything a document says is a chunk. Some of it is about the tangling itself — where the book is
carried, which of its files travel with the tree — and it belongs in the document rather than on the
command line: the output is the book's, not the invocation's, and a tree whose contents depend on how
someone called the tool is a tree nobody can check.

So there is one function for settings, and it takes a dict. A dict because the set of settings will
change: adding one should add a key, not another name to the syntax. Unknown keys are refused where they
are written, which is the only place the mistake is still fresh.

#chunk("package: options", ````typst
/// Settings for the tangling, as one dict. A document that needs to say something about how it is
/// tangled says it here, and the tool reads it from the declaration stream like everything else.
#let tangle-options(options) = {
  let known = ("book-directory", "book-files")
  for key in options.keys() {
    if not known.contains(key) {
      panic("unknown tangle option: " + key + " (known: " + known.join(", ") + ")")
    }
  }
  [#metadata((lp: "options", options: options))<lp-decl>]
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
//! declares its chunks through the `lp` package (`typst/lp.typ`), whose `chunk` and
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
    /// `"chunk"`, `"file"` or `"options"`.
    pub lp: String,
    /// The fragment's name, or the path for a file declaration. Settings have none.
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub lang: Option<String>,
    #[serde(default)]
    pub text: String,
    /// The dict of a settings declaration, carried as it was written.
    #[serde(default)]
    pub options: Option<serde_json::Value>,
}
````)

#chunk("metadata: the two kinds", ````rust
/// What the three declaration functions mean.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    /// `#chunk(name, …)`: a fragment that only exists where it is referenced.
    Chunk,
    /// `#file(path, …)`: a chunk whose name is the path it is written to.
    File,
    /// `#tangle-options(…)`: a setting, which produces no file.
    Options,
}
````)

#chunk("metadata: a kind we do not know", ````rust
/// A declaration that says something else is a mistake in the package or in
/// whatever emitted the metadata — not a fragment by default.
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
/// The package this tool is written with, compiled into the binary: a document should not have
/// to ship a copy of it to be tangled, or find one (D21). `include_str!` is the whole
/// mechanism — the standard library, no dependency, checked at compile time.
const PACKAGE_MANIFEST: &str = include_str!("../typst/typst.toml");
const PACKAGE_ENTRY: &str = include_str!("../typst/lp.typ");

/// The directory, next to a document, that the package is unpacked into. It belongs to the tool,
/// so the ownership check treats it like a control file rather than content.
pub const PACKAGE_ROOT: &str = ".lp";

/// Where a document's import (`@local/lp:0.1.0`) resolves inside that directory: namespace,
/// name, version.
const PACKAGE_DIR: &str = "local/lp/0.1.0";

/// Write the embedded package to `<root>/.lp/…` so Typst can resolve what the document imports,
/// and hand back the directory to point `--package-path` at. Only changed bytes are written, so
/// a pass in a loop does not touch the disk.
pub fn unpack_package(root: &Path) -> Result<PathBuf, LpError> {
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

/// The book a document declares, if it declares one. The tangle wants the whole plan; a rendering wants
/// only this much, and asking for it is what lets a page carry its own source.
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
        book_copies = crate::book::plan(settings, &metadata::common_ancestor(&absolute), docs)?;
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
use crate::map::{Book, FileMap, LpMap, MAP_FILE, Run, split};
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
    /// What the document asked for, if it asked.
    pub book: Option<Book>,
    /// The book's files, resolved against the source tree and ready to be carried.
    pub book_copies: Vec<crate::book::Copy>,
}

/// The settings a document declares, or an error naming what is missing.
///
/// The keys are the package's own list; the tool checks them again because a document can be
/// written against a newer package than the binary reading it.
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
            .ok_or_else(|| LpError::plain("`book-files` is a list of globs"))?;
        for entry in list {
            match entry.as_str() {
                Some(glob) => files.push(glob.to_string()),
                None => return Err(LpError::plain("`book-files` is a list of globs")),
            }
        }
    }
    Ok(Book { directory, files })
}

/// The documents as the output directory sees them: relative to the root the given paths share,
/// which is where the book's copy of each one lands. Absolute paths here would make a published
/// tree depend on the machine that tangled it.
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
for declaration in metadata::declarations(&typst, docs)? {
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
    // The book is output too: carried by the pass rather than written by a declaration, and just as much
    // this pass's business — so the ownership check reads it as accounted for.
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
if !plan.book_copies.is_empty() {
    let carried = crate::book::place(out, &plan.book_copies, check)?;
    if carried > 0 {
        let plural = if carried == 1 { "" } else { "s" };
        println!("carried {carried} book file{plural}");
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
        // The pass's own map carries what the pass was: which documents, and what the
        // document asked for. A directory's map is about that directory.
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
== Carrying the book into what it produced

A tree that cannot be read on its own is a build artifact; a tree that carries the document which
produced it is a program with its source of truth beside it. So a document may ask for the copy:

```typst
#tangle-options((book-directory: "book", book-files: ("*.typ", "README.md")))
```

Every file under the book's root that matches one of those globs — plus the documents themselves, which
are the book whatever else it holds — is copied into the output directory under `book-directory`, keeping
the shape it had in the source. The globs are matched the way a `.gitignore` matches, against the source
tree, and they respect its own `.gitignore` files: what the source calls ignored is not part of the book.

The copy is output like everything else: written only when its bytes differ, part of what `--check`
compares, and accounted for by the ownership check rather than reported as a stray.

#file("src/embedded.rs", ````rust
<<self: the module note>>

<<self: the imports>>

<<self: the book, carried>>

<<self: reading it>>

<<self: proving it>>
````)

#file("src/book.rs", ````rust
<<book: the module note>>

<<book: the imports>>

<<book: what the settings ask for>>

<<book: carrying it over>>
````)

#chunk("book: the module note", ````rust
//! Carrying the book into the tree it produced.
//!
//! The document says where and which; this walks the source tree, matches, and copies. Nothing here
//! knows about any declaration: it works on paths and globs, which is all the settings are.
````)

#chunk("book: the imports", ````rust
use std::path::{Path, PathBuf};

use ignore::WalkBuilder;
use ignore::gitignore::GitignoreBuilder;

use crate::diag::LpError;
use crate::map::Book;
use crate::metadata::PACKAGE_ROOT;
````)

#chunk("book: what the settings ask for", ````rust
/// One file to carry: where it comes from, and where it goes, relative to the output directory.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Copy {
    pub from: PathBuf,
    pub to: String,
}

/// Resolve the settings against the source tree. Nothing is written here — the plan can be checked
/// before anything moves.
pub fn plan(settings: &Book, anchor: &Path, docs: &[PathBuf]) -> Result<Vec<Copy>, LpError> {
    let mut matcher = GitignoreBuilder::new(anchor);
    for glob in &settings.files {
        matcher.add_line(None, glob).map_err(|err| {
            LpError::plain(format!("book-files: {glob}: {err}"))
                .with_help("globs are written the way a .gitignore writes them")
        })?;
    }
    let matcher = matcher
        .build()
        .map_err(|err| LpError::plain(format!("book-files: {err}")))?;

    let documents: Vec<PathBuf> = docs
        .iter()
        .map(|doc| doc.canonicalize().unwrap_or_else(|_| doc.clone()))
        .collect();

    // The walk applies the source tree's own `.gitignore` files to every entry, and `require_git(false)`
    // is what makes that true outside a repository — a build directory is not one, and a tree must not
    // depend on which of the two it came from. The machine's global rules and any parent's are turned
    // off: what the book is should be a property of the book.
    let walk = WalkBuilder::new(anchor)
        .git_ignore(true)
        .require_git(false)
        .git_global(false)
        .git_exclude(false)
        .parents(false)
        .build();

    let mut copies = Vec::new();
    for entry in walk {
        let entry =
            entry.map_err(|err| LpError::plain(format!("reading {}: {err}", anchor.display())))?;
        if !entry.file_type().is_some_and(|kind| kind.is_file()) {
            continue;
        }
        let path = entry.path();
        // The tool unpacks its package next to whatever document it evaluates — including the copy
        // this very pass has just written — so that directory is state, never part of the book.
        if path
            .strip_prefix(anchor)
            .unwrap_or(path)
            .components()
            .any(|part| part.as_os_str() == PACKAGE_ROOT)
        {
            continue;
        }
        let canonical = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
        let wanted = matcher.matched(path, false).is_ignore() || documents.contains(&canonical);
        if !wanted {
            continue;
        }
        let relative = path.strip_prefix(anchor).unwrap_or(path);
        copies.push(Copy {
            from: path.to_path_buf(),
            to: format!(
                "{}/{}",
                settings.directory.trim_end_matches('/'),
                relative.to_string_lossy().replace('\\', "/")
            ),
        });
    }
    copies.sort_by(|a, b| a.to.cmp(&b.to));
    Ok(copies)
}
````)

#chunk("book: carrying it over", ````rust
/// The id this tool writes into a rendering and looks for when taking the book back out. A `<script>`
/// whose type is not JavaScript is a *data block*, not a script, so the book rides inside a valid page
/// without pretending to be code — and the whole opening tag is the marker, not the text of the id: a
/// document is free to mention `lp-source` in prose, and prose is not a block.
const SOURCE_ID: &str = "lp-source";

/// Put the book into a rendered page. The page stays a page: nothing here is executed, and a browser
/// that ignores the block has lost nothing.
pub fn attach(page: &Path, copies: &[Copy]) -> Result<(), LpError> {
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
        files.insert(copy.to.clone(), serde_json::Value::String(text));
    }
    let payload = serde_json::json!({ "version": 1, "files": files }).to_string();

    // `</script>` inside a string would end the block early — and `<` cannot appear outside a string in
    // JSON, so escaping every one of them is safe and sufficient.
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

/// Read the book back out of a page this tool rendered and write it into a directory. A name that would
/// climb out of the output directory is refused: a page is data, and this one may not be ours.
pub fn extract(page: &Path, out: &Path) -> Result<usize, LpError> {
    let html = std::fs::read_to_string(page).map_err(|err| LpError::io(page, err))?;
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

/// Write the copies whose bytes differ, and say how many those were. Under `check` nothing is written:
/// a copy that is missing or different is the tree being out of date, which is the same failure as an
/// output that no longer matches its document.
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
  and its path. An HTML rendering carries the book with it, so what opens is a page that can give its own
  source back.
- `lp self prove <dir>` unpacks that book into `<dir>`, tangles it with *this* binary, and runs the
  tree's own checks in it: the whole bootstrap in one command, with nothing outside the binary but the
  toolchain it borrows. The lock file is part of the book, so nix is asked not to resolve one — writing
  one there would be drift.

`include_dir` is the one dependency this adds, and the line D7 asks for: embedding a directory tree is
`include_bytes!` at scale — one macro, no runtime dependency, and `Dir::extract` writes the tree back out
in a single call. It also embeds in *every* profile, which matters more than it sounds: a crate that reads
from the file system in debug builds would make the test below pass without embedding anything.

#chunk("self: the module note", ````rust
//! The book, carried inside this binary.
//!
//! `include_dir!` embeds the directory beside this crate at compile time. That directory is the book:
//! this document, the pointer next to it, and the tree's own ignore rules. It is what makes `lp self`
//! self-contained — the binary carries its own source of truth, and needs nothing else to hand it over.
````)

#chunk("self: the imports", ````rust
use std::path::{Path, PathBuf};
use std::process::Command;

use include_dir::{Dir, include_dir};

use crate::diag::LpError;

/// The book, embedded: the document, the pointer, and the ignore rules.
static BOOK: Dir = include_dir!("$CARGO_MANIFEST_DIR/book");
````)

#chunk("self: the book, carried", ````rust
/// Write the book out, entire, and say how many files that was.
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
/// Materialise the book in a directory, tangle it with this binary, and run the tree's own checks.
///
/// This is the whole bootstrap in one command: nothing outside the binary and the toolchain it borrows
/// is needed — no repository, no seed branch, no network beyond what `cargo` and `nix` themselves want.
pub fn prove(dir: &Path) -> Result<i32, LpError> {
    let files = book(dir)?;

    // The book names no document as *the* document, and this does not guess by file name either: it
    // takes the .typ files it finds and insists there is exactly one.
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

    // The document keeps its usual place: beside its output, not inside it. Tangling in place would put
    // the book's own sources under the output directory, where the ownership check would rightly ask who
    // they are — so the tree lands in `tangled/`, exactly as it does in the repository.
    let tree = dir.join("tangled");
    println!("wrote {files} files of the book to {}", dir.display());
    crate::tangle::run(&documents, &tree, false)?;

    // The lock belongs to the book, so nix must not resolve anything here: if the lock were out of date
    // it would write a new one, and a check that can rewrite its own input is not a check.
    let status = Command::new("nix")
        .args(["flake", "check", "--no-update-lock-file"])
        .current_dir(&tree)
        .status()
        .map_err(|err| LpError::plain(format!("cannot run nix: {err}")))?;
    Ok(status.code().unwrap_or(1))
}
````)

#chunk("self: reading it", ````rust
/// Weave the document this binary carries and hand the result to the desktop.
///
/// The rendering goes to a directory of its own under the system temporary directory and stays there:
/// the opener returns long before anyone has looked at it, and a viewer that is still starting up cannot
/// be asked to hold a temporary file open.
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

    // Best effort: no desktop, no `xdg-open`, and the file is still there with its path printed.
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
be improved. `lp extract --format html <page> --out <dir>` is the inverse: it finds the block, reads the
book back, and writes it where the names say.

What marks the block is the whole opening tag, not the text of the id. This document says "lp-source" in
prose — here, in this paragraph — and the first version, which searched for the id as a substring, found
this sentence instead and failed on it. A marker has to be something a page cannot mention by accident.

Only HTML, and the format is never guessed. `extract` demands `--format` because a wrong guess would
produce silence rather than an error, and only an `.html` output gets a book, because a PDF is not a
container for a JSON block.

The package is the copy embedded in this binary, unpacked fresh, so weaving needs no tangle before it:
the document is the source of both. And the document stays a normal Typst file — an editor rendering it
without the tool sets `TYPST_PACKAGE_PATH` itself, to the same path this command passes. That is the one
place the unpacking is visible from outside, and this command exists so that nobody has to type it.

#file("src/weave.rs", ````rust
<<weave: the module note>>

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

#chunk("weave: the module note", ````rust
//! Rendering the document: `typst compile`, with the two facts this tool knows.
//!
//! The package this tool unpacks has to be in scope, and Typst's root has to cover the document and
//! the working directory. Everything else about rendering belongs to the compiler, so the command is
//! thin on purpose.
````)

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
    // The document as the writer named it goes to Typst; the absolute one decides where the package
    // is and how far up the root has to reach, because `common_ancestor` starts from a parent.
    let anchor = doc.canonicalize().map_err(|err| LpError::io(doc, err))?;
    // The anchor is kept: after the compile, the same document says which files its book is made of.
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

/// A rendering of a literate document carries the source it was woven from, so the page can be handed to
/// someone and give the book back — the same promise this binary makes about itself.
///
/// Only `.html`: Typst decides the format from the output name, and a PDF is not a container for a JSON
/// block. Refusing to guess is the same rule that makes `extract` demand an explicit `--format`.
fn carry_the_book(anchor: &Path, output: Option<&Path>) -> Result<(), LpError> {
    let Some(page) = output.filter(|out| out.extension().is_some_and(|ext| ext == "html")) else {
        return Ok(());
    };
    let Some(directory) = anchor.parent() else {
        return Ok(());
    };
    let docs = vec![anchor.to_path_buf()];
    let Some(book) = crate::tangle::declared_book(&docs)? else {
        return Ok(());
    };
    let copies = crate::book::plan(&book, directory, &docs)?;
    crate::book::attach(page, &copies)
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
const VERSION: u32 = 6;
````)

== What a map holds

Three structures, all serde-shaped, because the file's format is the interface: a map, the
entry for one file, and one run of lines.

#chunk("map: what a map holds", ````rust
#[derive(Debug, Serialize, Deserialize)]
pub struct LpMap {
    pub version: u32,
    /// Documents that produced the files listed here, relative to the book's root. Only the
    /// tangle's own map — the one in the output directory itself — carries them: they say
    /// something about the whole pass, not about this directory.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub docs: Vec<String>,
    /// The settings the document declared, in that same map.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub book: Option<Book>,
    /// Keyed by file name *within this directory*.
    pub files: BTreeMap<String, FileMap>,
}

/// What `#tangle-options(…)` asked for: where the book is carried, and which of its files match.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Book {
    /// Directory inside the output directory that the book's files are copied into.
    pub directory: String,
    /// Globs, matched against the source tree the way a `.gitignore` matches.
    pub files: Vec<String>,
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
//! every root (measured: ~1ms for 2k lines). Reverse-reachability
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
/// Take the book back out of a page this tool rendered
Extract {
    /// Which rendering to read
    #[arg(long)]
    format: String,
    /// The rendered page
    file: PathBuf,
    /// Directory to write the book into
    #[arg(long)]
    out: PathBuf,
},
````)

#chunk("main: self", ````rust
/// Read, unpack or prove the book this binary carries
#[command(name = "self")]
Itself {
    #[command(subcommand)]
    method: SelfMethod,
},
````)

#chunk("main: self, what it can do", ````rust
#[derive(Subcommand)]
enum SelfMethod {
    /// Write the book out, entire
    Book {
        /// Directory to write it into
        #[arg(long)]
        out: PathBuf,
    },
    /// Weave the document this binary carries, then open it
    Read {
        /// Which rendering to make
        #[arg(long, default_value = "pdf")]
        format: String,
    },
    /// Unpack the book, tangle it with this binary, and run the tree's own checks
    Prove {
        /// Directory to build the book in
        dir: PathBuf,
    },
}
````)

#chunk("main: weave", ````rust
/// Render a document, with the package this tool unpacks in scope
Weave {
    /// The document to render
    doc: PathBuf,
    /// Where to write it (Typst reads the format off the extension)
    output: Option<PathBuf>,
    /// Arguments passed on to `typst compile`, untouched
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    extra: Vec<String>,
},
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
Command::Weave { doc, output, extra } => weave::run(&doc, output.as_deref(), &extra),
Command::Extract { format, file, out } => {
    if format != "html" {
        return Err(diag::LpError::plain(format!(
            "--format {format} is not implemented yet"
        ))
        .with_help(
            "only `html` carries the book so far: a PDF is not a container for JSON",
        ));
    }
    let files = crate::book::extract(&file, &out)?;
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

<<flow: weave_renders_a_document_that_imports_the_package>>

<<flow: a_page_gives_the_book_back>>

<<flow: reading_weaves_what_the_binary_carries>>

<<flow: the_book_comes_back_out_whole>>

<<flow: the_book_is_carried_into_the_tree>>

<<flow: an_unknown_tangle_option_is_refused>>

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
- `the_book_is_carried_into_the_tree` — the settings put the book beside its output, in its own shape, minus what the source calls ignored
- `the_book_comes_back_out_whole` — `lp self book --out` writes exactly the book the binary carries, byte for byte
- `reading_weaves_what_the_binary_carries` — `lp self read --format html` weaves the embedded document and leaves a rendering behind
- `a_page_gives_the_book_back` — `lp weave` puts the book the document declares into the HTML it renders, and `lp extract` gets it back byte for byte
- `an_unknown_tangle_option_is_refused` — the package refuses a key it does not know, at the line that wrote it
- `a_book_without_a_directory_is_an_error` — asking for a book without saying where it goes is refused by the tool
- `a_book_may_not_overwrite_an_output` — a book that would land on a declared file is refused while planning
- `a_chunk_built_by_code_is_attributed_to_itself` — roots declared by a loop are attributed to the declarations the loop produced
- `the_declaration_is_where_the_line_lives` — the answer includes the `rg` command that finds the declaration

#chunk("flow: the file's purpose", ````rust
//! End-to-end tests: they run the real binary against throwaway documents.
````)

#chunk("flow: the fixtures and helpers", ````rust
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../typst/lp.typ");

/// A document in the real authoring form: the package is imported, its rules are
/// installed, and the body declares chunks.
fn document(body: &str) -> String {
    format!("#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}")
}

/// One file declaration, a shared fragment, a fragment written in two pieces,
/// and a code sample that is not a chunk at all.
///
/// The two references are spliced in rather than written on lines of their own:
/// a line that is exactly `<<name>>` would be expanded when this file is tangled
/// (ADR D15).
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

#chunk("flow: weave_renders_a_document_that_imports_the_package", ````rust
#[test]
fn weave_renders_a_document_that_imports_the_package() {
    // No `lp.typ` next to it: the only way this document can be rendered is through the package
    // this tool unpacks, which is exactly what `weave` passes on to Typst.
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

    // Byte for byte, against the book beside the crate: this is the embedding itself, and it can fail.
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

#chunk("flow: a_page_gives_the_book_back", ````rust
#[test]
fn a_page_gives_the_book_back() {
    let dir = TempDir::new().expect("temp dir");
    // A document on disk, not the embedded one: carrying the book is what weaving does, not something
    // only the binary can do about itself.
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

    // The round trip: the page carries the book under the names the tree uses, and gives it back whole.
    let carried = Path::new(env!("CARGO_MANIFEST_DIR")).join("book");
    for name in ["lp.typ", "README.md", ".gitignore"] {
        let back = std::fs::read(dir.path().join("back/book").join(name)).expect(name);
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
            "#tangle-options((book-directory: \"book\", book-files: (\"**/*.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        dir.path().join("tangled/book/demo.typ").exists(),
        "the document is part of the book whatever else it holds"
    );
    assert!(
        dir.path().join("tangled/book/chapters/one.typ").exists(),
        "a matched file keeps its shape"
    );
    assert!(
        dir.path().join("tangled/book/README.md").exists(),
        "and so does one matched by name"
    );
    assert!(
        !dir.path().join("tangled/book/ignored.txt").exists(),
        "what the source calls ignored is not part of the book"
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

#chunk("flow: a_book_without_a_directory_is_an_error", ````rust
#[test]
fn a_book_without_a_directory_is_an_error() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-files: (\"*.py\",)))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
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
            "#tangle-options((book-directory: \"src\", book-files: (\"*.py\",)))\n\n#file(\"src/main.py\", ```py\nprint('x')\n```)\n",
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

const PKG: &str = include_str!("../typst/lp.typ");

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

/// Write the package and a document that imports it.
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
    let text = format!(
        "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
    );
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
/// The document is the source of the files that are compiled, so the tree has to regenerate itself.
/// The map beside this crate names the documents and the directory the book was carried into — that
/// copy is the document, and this crate's own directory is the output directory. The same command
/// therefore works in the repository, in a worktree of the published tree, and in a build of it,
/// which is what makes this a fixed point rather than a path (ADR D15).
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
# D7: embedding a directory tree is `include_bytes!` at scale — one macro, no runtime dependency, and it
# embeds in every profile.
include_dir = "0.7"
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

So these three files are output too. They are declared here, tangled with everything else, and carried
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

== The package, the way nixpkgs would write it

`rustPlatform.buildRustPackage` with the lock file, which is the shape every Rust package in nixpkgs has.
Two things are this tool's own:

- *Typst is a runtime dependency.* Tangling asks the document for its declarations, so the binary has to
  find `typst` when it runs — and a package that works only when the user happens to have the right
  thing on their `PATH` is not a package. The wrapper puts it there.
- *One test belongs to the document, not to the program.* `the_document_regenerates_the_sources_we_are_running`
  asserts that `lp.typ` at the repository root regenerates this tree; in a build of the tree there is no
  repository root above it, and the assertion would be asking the wrong question. It is skipped here, and
  it keeps running in the repository that has a document.

#chunk("nix: the package", ````nix
{ lib, rustPlatform, typst, makeWrapper }:

rustPlatform.buildRustPackage rec {
  pname = "lp";
  version = "0.1.0";

  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ typst ];

  postInstall = ''
    wrapProgram $out/bin/lp --prefix PATH : ${lib.makeBinPath [ typst ]}
  '';

  meta = {
    description = "Literate programming: tangling sources out of a Typst document";
    mainProgram = "lp";
  };
}
````)

== The flake, and the systems it is for

Three systems, named once. `checks` holds the two things worth saying about this flake: that the package
builds, and that the development shell can be constructed — a shell that cannot be built is a shell
nobody uses. `nix flake check` builds both for the machine it runs on and evaluates the rest, so a typo
in the Darwin branch of anything is caught on Linux.

#chunk("nix: the flake", ````nix
{
  description = "lp: literate programming for Typst documents";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      each = nixpkgs.lib.genAttrs systems;
      lp = system: (import nixpkgs { inherit system; }).callPackage ./lp.nix { };
      shell = system: (import nixpkgs { inherit system; }).mkShell {
        inputsFrom = [ (lp system) ];
      };
    in {
      packages = each (system: {
        default = lp system;
        lp = lp system;
      });

      devShells = each (system: { default = shell system; });

      checks = each (system: {
        package = lp system;
        devShell = shell system;
      });
    };
}
````)

== The workflow

Four steps: check the generation out, get Nix, get the cache, and run the check. The cache is where a
pipeline like this earns its keep — a Rust build with Nix is several hundred derivations, and the second
run should download them instead of building them.

The cache name is the Cachix cache this repository pushes to; the token comes from a secret, because a
signing key in a workflow file is a signing key given away.

#chunk("nix: the workflow", ````yaml
name: check

on:
  push:
    branches: [tangled]
  workflow_dispatch:
  schedule:
    - cron: "0 6 * * *"

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - uses: cachix/cachix-action@v16
        with:
          name: linyinfeng
          signingKey: ${{ secrets.CACHIX_SIGNING_KEY }}
      # Build this tree's own tool, then hand it the book it carries: `self prove` unpacks the book into
      # an empty directory, tangles it, and runs this tree's own checks there.
      - run: nix build .#lp --no-update-lock-file
      - run: ./result/bin/lp self prove /tmp/proved
````)

= What this repository carries

`lp` treats its output directory as its own and refuses to guess: every file under it
is produced by a declaration or listed in the `.lpignore` of its directory. Here the
output directory is the repository root, so what this document does *not* produce is
whatever is not the crate, the package, the example or a control file — and the lock
files cargo and nix maintain, which no chunk has any business owning.

#file(".gitignore", ````gitignore
# The tool's own state, and what the build tools write — wherever in the tree they land.
.lp
target

# The example's build directory is a nested document's output, and this document declares the one
# file in it that governs the rest.
examples/demo/build/*
!examples/demo/build/.lpignore
````)

#file(".lpignore", ````gitignore
# What the tangled tree carries besides the document's output.
#
# Matching here means *protect* (ADR D10): every file under the output directory is either
# produced by a #file declaration or listed here, and this lists what the document does not
# produce. The output directory is `tangled/`, the crate the document generates.

# `tangled/` is a repository of its own, so that the generated code has a history separate
# from the document's (the bootstrap makes it one; `git init tangled`). Its metadata is not
# content, and this is the line that says so.
/.git

# What the build tools write, and the example's build directory — whose own .lpignore governs what is
# inside it, because a nested document's output is not this document's business. The lock files are
# not here: they are decisions, declared in the appendix.
/target
/examples/demo/build
````)

= What git is asked to ignore

Everything under `tangled/` is generated, so the whole directory is ignored: the crate, the
package, the example, the protect list and the maps. What is tracked at the root is the document,
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
example, protect list. Its own history is what makes it readable a generation later, which is the
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
# The tool's own state, and what the build tools write — wherever in the tree they land.
.lp
target

# The example's build directory is a nested document's output, and this document declares the one
# file in it that governs the rest.
examples/demo/build/*
!examples/demo/build/.lpignore
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
  the example, the control files. The seed is output too, and lives on the `tangled` branch for
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
#import "@local/lp:0.1.0": chunk, file, tangle-options, show-rule
#show: show-rule

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

Two of its steps are plain `typst` rather than `lp`, on purpose: the example is also a demonstration
that a woven document is an ordinary Typst file. Those steps need the package path the tangle unpacked,
so `TYPST_PACKAGE_PATH` is set for them — the same line an editor needs, and the one `lp weave` exists
to save everyone else from typing.

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
name = "aho-corasick"
version = "1.1.5"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "c982642fa9e8606056828ee9a8505737230110bb1099153c79efe865c59d12ba"
dependencies = [
 "memchr",
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
 "miniz_oxide",
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
name = "bstr"
version = "1.13.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "6bb31b46c14244e20ee9984b11bf5c992b91fb6939fea616e3512c8baecdbe5f"
dependencies = [
 "memchr",
 "serde_core",
]

[[package]]
name = "cfg-if"
version = "1.0.4"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "9330f8b2ff13f34540b44e946ef35111825727b38d33286ef986142615121801"

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
name = "heck"
version = "0.5.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "2304e00983f87ffb38b55b444b5e3b60a884b5d30c0fca7d82fe33449bbe55ea"

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
name = "lp"
version = "0.1.0"
dependencies = [
 "clap",
 "ignore",
 "include_dir",
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
name = "same-file"
version = "1.0.6"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "93fc1dc3aaa9bfed95e02e6eadabb4baf7e3078b0bd1b4d7b6b0b68378900502"
dependencies = [
 "winapi-util",
]

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
name = "unicode-ident"
version = "1.0.24"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "e6e4313cd5fcd3dad5cafa179702e2b244f760991f45397d14d4ebf38247da75"

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
name = "zmij"
version = "1.0.23"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "29666d0abbfad1e3dc4dcf6144730dd3a3ab225bbbdac83319345b1b44ccfc1b"
````)

#chunk("lock: the nix inputs", ````json
{
  "nodes": {
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
        "nixpkgs": "nixpkgs"
      }
    }
  },
  "root": "root",
  "version": 7
}
````)
