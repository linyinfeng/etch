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

use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use crate::diag::LpError;

/// Every declaration, in the order the document produced them.
const QUERY: &str = "query(<lp-decl>).map(declaration => declaration.value)";

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

/// What the two declaration functions mean.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    /// `#chunk(name, …)`: a fragment that only exists where it is referenced.
    Chunk,
    /// `#file(path, …)`: a chunk whose name is the path it is written to.
    File,
}

impl Decl {
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
}

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

/// Evaluate the documents and read their declarations.
///
/// Typst resolves `#include` against its project root, which is the directory of
/// the file being evaluated. So the wrapper is written where every document lives
/// and includes them relatively: a document outside the working directory works
/// the same as one inside it. (Writing the wrapper into the working directory, as
/// this did at first, silently refused any document that was not under it.)
pub fn declarations(typst: &Path, docs: &[PathBuf]) -> Result<Vec<Decl>, LpError> {
    let cwd = std::env::current_dir()
        .map_err(|err| LpError::plain(format!("cannot read the working directory: {err}")))?;
    let docs: Vec<PathBuf> = docs
        .iter()
        .map(|doc| std::path::absolute(doc).unwrap_or_else(|_| cwd.join(doc)))
        .collect();

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

    let output =
        output.map_err(|err| LpError::plain(format!("cannot run {}: {err}", typst.display())))?;
    if !output.status.success() {
        let message = String::from_utf8_lossy(&output.stderr);
        return Err(LpError::plain(format!(
            "the document did not evaluate, so there are no chunks to tangle:\n{}",
            message.trim_end()
        )));
    }

    let declarations: Vec<Decl> = serde_json::from_slice(&output.stdout).map_err(|err| {
        LpError::plain(format!("cannot read the document's declarations: {err}"))
            .with_help(String::from_utf8_lossy(&output.stdout).to_string())
    })?;
    if declarations.is_empty() {
        return Err(LpError::plain("the document declares no chunks").with_help(
            "import the package and declare them: `#import \"lp.typ\": chunk, file`, then `#chunk(\"name\", ```…```)` or `#file(\"src/main.rs\", ```…```)`",
        ));
    }
    for declaration in &declarations {
        declaration.kind()?;
    }
    Ok(declarations)
}

/// A wrapper document, removed when it goes out of scope — including when the
/// evaluation fails, and including on panic.
struct Wrapper {
    path: PathBuf,
}

impl Wrapper {
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
}

impl Drop for Wrapper {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

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
