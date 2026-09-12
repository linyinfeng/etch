#import "@local/lp:0.1.0": chunk, file

= Asking the document what it declares

This is the one thing `lp` cannot work out for itself. Typst is Turing-complete: a chunk can come from a
loop, a branch, a function, or a file that was `#include`d, so the only authority on what a document
declares is evaluating it. Rather than parse the document — which would mean being wrong exactly where the
document is clever — the tool asks Typst a question and reads the answer.

The question is one `query`, and the package is what makes it possible: `chunk` and `file` attach a
metadata record to every declaration they are called with, carrying the name, the language and the text.
Everything else in this program works from that stream. Nothing is recovered from the source afterwards,
which is why the sources are never read.

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

The record's field names are written twice: once in the package that emits them, and once in the struct
below that reads them. Nothing checks that the two agree — a mismatch shows up as a serde error at
runtime, reported with the raw output that Typst actually printed. That is the weakest joint in the
program, and it is a joint by construction: two languages, two files, one agreement.

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

A declaration is data: which of the two functions produced it, the name, the language from the fence, and
the text. The kind is not free-form — the package emits `"chunk"` or `"file"` — so anything else is a
mistake in the package or in whatever produced the metadata, and it is an error rather than a default. A
third kind would mean the package grew a feature the tool has not learned yet, which is not something to
guess at.

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

== Finding typst, and putting the package where it can be imported

The binary is a hard dependency: without it there are no declarations to read. An explicit override first,
then `PATH`, and if neither works the error says what to do rather than failing later with a confusing
message. The same fragment also unpacks the package the document imports, because both are the same
question asked of the environment — what does Typst need in order to answer this document's imports? The
package is the copy embedded in this binary, written under `.lp` next to the document, and it is rewritten
only when the bytes differ, which is what keeps its mtime — and everything downstream of it — still.

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

Four fragments, and together they are the whole interaction with the outside world: make the paths
absolute, decide where the wrapper lives, run Typst, and report what came back.

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

Two constraints meet here. Typst refuses to read outside its project root, and a document may import a
package from outside its own directory — so the root has to cover the working directory *and* every
document, and the wrapper has to live inside that root to be readable at all. Hence a wrapper next to the
documents, including them relatively, with the root computed as the deepest directory that contains
everything involved.

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

The failure is reported with Typst's own message, because that is the message the person who wrote the
document needs to see — a missing bracket in a chunk is a document error, not a tool error.

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

The wrapper is a temporary document holding one `#include` per document named on the command line. It is
removed when it goes out of scope, and that includes the failing and panicking paths.

It lives under `.lp` because of what it is not: a file beside a document is a name taken from whoever works
there, and one reserved name is enough. Inside `.lp` a leftover — a run that was killed before it could
clean up — is invisible rather than reported, because no pass reads that directory at all.

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

The paths are quoted and their backslashes and quotes escaped: a file name must not be able to break the
wrapper open, and on some systems a file name may contain a quote.

#chunk("metadata: removing it, whatever happens", ````rust
impl Drop for Wrapper {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}
````)

== The directory the wrapper lives in

The deepest directory containing every document. The wrapper goes into `.lp` under it, which is what lets it
say `#include "../…"` and reach every one of them; the deepest directory is what the `..` is relative to.
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
