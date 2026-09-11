//! What the document says its chunks are.
//!
//! Typst is Turing-complete, so the only authority on which chunks exist is
//! Typst: a code block can come from a loop, a branch, a function, or a file that
//! was `#include`d, and no amount of reading the source can tell. We ask the
//! document instead: a generated wrapper installs a show rule that emits one
//! metadata event per code block and per heading, in document order, and
//! `typst eval` hands them back as JSON.
//!
//! This is also why there is no Typst parser left in the tool. The one thing
//! evaluation cannot provide is *source positions* — Typst has no spans — so that
//! is a separate, much smaller problem (`locate.rs`).

use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use crate::diag::LpError;

/// The instrumentation. It is prepended to a wrapper that `#include`s the
/// documents, so the user's files are never modified: show rules installed
/// before the include still see the included content (verified), and the
/// document's own show rules on `raw` keep working on top of ours.
const HELPER: &str = r#"#let lp-seq = counter("lp-seq")
#let lp-label(it) = {
  let value = it.at("label", default: none)
  if value == none { none } else { str(value) }
}
#show raw.where(block: true): it => {
  lp-seq.step()
  [#metadata((
    kind: "chunk",
    n: lp-seq.get().first(),
    label: lp-label(it),
    lang: it.lang,
    text: it.text,
  ))<lp-event>]
  it
}
#show heading: it => {
  lp-seq.step()
  [#metadata((
    kind: "heading",
    n: lp-seq.get().first(),
    level: it.level,
  ))<lp-event>]
  it
}
"#;

/// The query expression: the events, in the order the document produced them.
const QUERY: &str = "query(<lp-event>).map(event => event.value)";

#[derive(Debug, Clone, Deserialize)]
pub struct Event {
    pub kind: String,
    /// Chunks only; `None` for a code block without a label.
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub lang: Option<String>,
    #[serde(default)]
    pub text: Option<String>,
    /// Headings only.
    #[serde(default)]
    pub level: Option<usize>,
}

impl Event {
    pub fn label(&self) -> Option<&str> {
        self.label.as_deref()
    }

    pub fn text(&self) -> &str {
        self.text.as_deref().unwrap_or("")
    }
}

/// Locate the `typst` binary: an explicit override, then `PATH`.
pub fn binary() -> Result<PathBuf, LpError> {
    if let Some(path) = std::env::var_os("LP_TYPST") {
        return Ok(PathBuf::from(path));
    }
    let name = if cfg!(windows) { "typst.exe" } else { "typst" };
    std::env::var_os("PATH")
        .map(|paths| std::env::split_paths(&paths).map(|dir| dir.join(name)).find(|candidate| candidate.is_file()))
        .flatten()
        .ok_or_else(|| {
            LpError::plain("no `typst` binary found").with_help(
                "tangling asks the document what its chunks are, so typst has to be available (set LP_TYPST or put it on PATH)",
            )
        })
}

/// Ask the documents for their events. `docs` are paths as the user wrote them,
/// which is what the wrapper includes, so they must be readable from `cwd`.
pub fn events(typst: &Path, docs: &[PathBuf], cwd: &Path) -> Result<Vec<Event>, LpError> {
    let mut wrapper = String::from(HELPER);
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
        LpError::plain(format!("cannot read the document's metadata: {err}"))
            .with_help(String::from_utf8_lossy(&output.stdout).to_string())
    })
}
