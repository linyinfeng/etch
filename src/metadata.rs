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

impl Decl {
    pub fn is_file(&self) -> bool {
        self.lp == "file"
    }
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
/// `docs` are paths as the user wrote them, which is what the wrapper includes,
/// so they have to be readable from `cwd`.
pub fn declarations(typst: &Path, docs: &[PathBuf], cwd: &Path) -> Result<Vec<Decl>, LpError> {
    // A wrapper only because including several files in one document needs one;
    // the user's files are never modified.
    let mut wrapper = String::new();
    for doc in docs {
        wrapper.push_str(&format!("#include \"{}\"\n", doc.display()));
    }

    let path = cwd.join(format!(".lp-decl-{}.typ", std::process::id()));
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

    let declarations: Vec<Decl> = serde_json::from_slice(&output.stdout).map_err(|err| {
        LpError::plain(format!("cannot read the document's declarations: {err}"))
            .with_help(String::from_utf8_lossy(&output.stdout).to_string())
    })?;
    if declarations.is_empty() {
        return Err(LpError::plain("the document declares no chunks").with_help(
            "import the package and declare them: `#import \"lp.typ\": chunk, file`, then `#chunk(\"name\", ```…```)` or `#file(\"src/main.rs\", ```…```)`",
        ));
    }
    Ok(declarations)
}
