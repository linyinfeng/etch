//! Turning a toolchain's diagnostics into chunk references.
//!
//! `lp explain` is a filter: it echoes what it reads and, for every
//! `file:line:col:` it can find in a map, prints which chunk that generated line
//! came from and how far into it the line is. Find that chunk in the document —
//! `rg '#chunk("print-results"'` — and you are at the place to edit.
//!
//! It knows nothing about any language, and it does not know `.typ` line numbers
//! either: Typst does not expose source positions (ADR D14).

use std::path::Path;

use regex::Regex;

use crate::diag::LpError;
use crate::map::{LpMap, join, resolve_all};

pub fn run(out: &Path, format: &str, input: &str) -> Result<usize, LpError> {
    if format == "cargo" {
        return Err(
            LpError::plain("--format cargo (JSON) is not implemented yet")
                .with_help("pipe `cargo build --message-format=short` through lp explain instead"),
        );
    }

    let pattern = Regex::new(r"^(?P<file>[^\s:]+\.\w+):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
        .map_err(|err| LpError::plain(format!("internal: bad diagnostic pattern: {err}")))?;

    let maps = LpMap::read_all(out);
    let mut mapped = 0;

    for line in input.lines() {
        println!("{line}");

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
    }

    Ok(mapped)
}
