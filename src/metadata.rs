//! What the document says its chunks are.
//!
//! Typst is Turing-complete, so the only authority on which chunks exist is
//! Typst: a code block can come from a loop, a branch, a function, or a file that
//! was `#include`d, and no amount of reading the source can tell. Measured: a
//! three-line document whose loop builds `raw(...)` blocks yields chunks whose
//! text appears in no source line at all. So the document is asked, not parsed.
//!
//! The asking is deliberately dull: `query(raw.where(block: true))` over a
//! wrapper that `#include`s the user's files. Two things were tried and rejected:
//!
//! * **Show rules with a counter** (one metadata event per block, ordered,
//!   interleaved with headings). It works — until a styling show rule *consumes*
//!   the element, which is exactly what our own `lit.typ` does for labelled
//!   blocks: the rule replaces the raw block with a rendered box, and the
//!   instrumentation never sees it. The document lost every chunk and only the
//!   unlabelled samples survived. A query reads the element tree, which styling
//!   does not change.
//! * **Parsing the source** (`typst-syntax`): wrong by construction once a
//!   document generates anything, and a second implementation of Typst's
//!   semantics to keep in sync forever.
//!
//! Source positions are the one thing evaluation cannot give (Typst has no
//! spans), and they are `locate.rs`'s problem.

use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use crate::diag::LpError;

/// Ask for every labelled code block, with its language and its text.
const QUERY: &str = "\
query(raw.where(block: true))
  .filter(block => block.at(\"label\", default: none) != none)
  .map(block => (
    label: str(block.at(\"label\", default: none)),
    lang: block.lang,
    text: block.text,
  ))";

#[derive(Debug, Clone, Deserialize)]
pub struct Chunk {
    pub label: String,
    #[serde(default)]
    pub lang: Option<String>,
    #[serde(default)]
    pub text: String,
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
                "tangling asks the document what its chunks are, so typst has to be available (set LP_TYPST or put it on PATH)",
            )
        })
}

/// Ask the documents for their chunks, in the order the document produced them.
///
/// `docs` are paths as the user wrote them, which is what the wrapper includes,
/// so they have to be readable from `cwd`.
pub fn chunks(typst: &Path, docs: &[PathBuf], cwd: &Path) -> Result<Vec<Chunk>, LpError> {
    // A wrapper only because `#include`ing several files in one document needs
    // one; the user's files are never modified.
    let mut wrapper = String::new();
    for doc in docs {
        wrapper.push_str(&format!("#include \"{}\"\n", doc.display()));
    }

    let path = cwd.join(format!(".lp-metadata-{}.typ", std::process::id()));
    std::fs::write(&path, wrapper).map_err(|err| LpError::io(&path, err))?;
    let output = Command::new(typst)
        .arg("eval")
        .arg(QUERY)
        .arg("--in")
        .arg(&path)
        .current_dir(cwd)
        .output();
    let _ = std::fs::remove_file(&path);

    let output =
        output.map_err(|err| LpError::plain(format!("cannot run {}: {err}", typst.display())))?;
    if !output.status.success() {
        let message = String::from_utf8_lossy(&output.stderr);
        return Err(LpError::plain(format!(
            "the document did not evaluate, so there are no chunks to tangle:\n{}",
            message.trim_end()
        )));
    }

    serde_json::from_slice(&output.stdout).map_err(|err| {
        LpError::plain(format!("cannot read the document's chunks: {err}"))
            .with_help(String::from_utf8_lossy(&output.stdout).to_string())
    })
}
