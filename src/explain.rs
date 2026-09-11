//! Turning a toolchain's diagnostics into `.typ` locations.
//!
//! `lp explain` is a filter: it echoes what it reads and, for every
//! `file:line:col:` it can find in a line map, prints the `.typ` line the
//! generated code actually came from. It knows nothing about any language —
//! the mapping is pure bookkeeping.
//!
//! Maps are per directory, so a diagnostic's path is resolved against the most
//! specific map that claims the file name.

use std::collections::BTreeMap;
use std::path::Path;

use regex::Regex;

use crate::diag::LpError;
use crate::map::{LpMap, join, resolve};
use crate::parse::Doc;

pub fn run(out: &Path, format: &str, input: &str) -> Result<usize, LpError> {
    if format == "cargo" {
        return Err(
            LpError::plain("--format cargo (JSON) is not implemented yet")
                .with_help("pipe `cargo build --message-format=short` through lp explain instead"),
        );
    }

    let pattern = Regex::new(r"^(?P<file>[^\s:]+\.\w+):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
        .map_err(|e| LpError::plain(format!("internal: bad diagnostic pattern: {e}")))?;

    let maps = LpMap::read_all(out);
    let mut docs: BTreeMap<String, Doc> = BTreeMap::new();
    let mut mapped = 0;

    for line in input.lines() {
        println!("{line}");

        let Some(caps) = pattern.captures(line) else {
            continue;
        };
        let (file, out_line) = (&caps["file"], caps["line"].parse::<usize>().unwrap_or(0));
        let Ok((dir, name, entry)) = resolve(&maps, file) else {
            continue;
        };
        let Some([mapped_line, typ_line]) = entry.locate(out_line) else {
            continue;
        };
        let rel = join(dir, name);

        let doc = match docs.get(&entry.typ) {
            Some(doc) => doc,
            None => docs
                .entry(entry.typ.clone())
                .or_insert(Doc::load(Path::new(&entry.typ))?),
        };

        let chunk = entry.chunk_at(typ_line).map_or(String::new(), |chunk| {
            format!(" (chunk <<{}>>)", chunk.name)
        });
        eprintln!("  ↳ {}:{typ_line}{chunk}", entry.typ);

        let message = caps.name("msg").map_or("", |capture| capture.as_str());
        let note = if mapped_line == out_line {
            format!("generated from {}:{typ_line}", entry.typ)
        } else {
            format!(
                "generated from {}:{typ_line} (line {out_line} is blank or generated)",
                entry.typ
            )
        };
        let mut err = LpError::plain(format!("{rel}:{out_line}: {message}"));
        if let Some(range) = doc.line_range(typ_line) {
            err = LpError::at(
                &doc.src,
                range,
                format!("{rel}:{out_line}: {message}"),
                note,
            );
        }
        eprintln!("{:?}", miette::Report::new(err));
        mapped += 1;
    }

    Ok(mapped)
}
