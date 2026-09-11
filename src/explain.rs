//! Turning a toolchain's diagnostics into `.typ` locations.
//!
//! `lp explain` is a filter: it echoes what it reads and, for every
//! `file:line:col:` it can find in the line map, prints the `.typ` line the
//! generated code actually came from. It knows nothing about any language —
//! the mapping is pure bookkeeping.

use std::collections::BTreeMap;
use std::path::Path;

use regex::Regex;

use crate::diag::LpError;
use crate::map::{LpMap, resolve};
use crate::parse::Doc;

pub fn run(map: &LpMap, format: &str, input: &str) -> Result<usize, LpError> {
    if format == "cargo" {
        return Err(
            LpError::plain("--format cargo (JSON) is not implemented yet")
                .with_help("pipe `cargo build --message-format=short` through lp explain instead"),
        );
    }

    let pattern = Regex::new(r"^(?P<file>[^\s:]+\.\w+):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
        .map_err(|e| LpError::plain(format!("internal: bad diagnostic pattern: {e}")))?;

    let mut docs: BTreeMap<String, Doc> = BTreeMap::new();
    let mut mapped = 0;

    for line in input.lines() {
        println!("{line}");

        let Some(caps) = pattern.captures(line) else {
            continue;
        };
        let (file, out_line) = (&caps["file"], caps["line"].parse::<usize>().unwrap_or(0));
        let Ok((_, entry)) = resolve(map, file) else {
            continue;
        };
        let Some([mapped_line, typ_line]) = entry.locate(out_line) else {
            continue;
        };

        let doc = match docs.get(&entry.typ) {
            Some(doc) => doc,
            None => docs
                .entry(entry.typ.clone())
                .or_insert(Doc::load(Path::new(&entry.typ))?),
        };

        let chunk = entry
            .chunk_at(typ_line)
            .map_or(String::new(), |c| format!(" (chunk <<{}>>)", c.name));
        eprintln!("  ↳ {}:{typ_line}{chunk}", entry.typ);

        let message = caps.name("msg").map_or("", |m| m.as_str());
        let mut err = LpError::plain(format!("{file}:{out_line}: {message}"));
        if let Some(range) = doc.line_range(typ_line) {
            let note = if mapped_line == out_line {
                format!("generated from {}:{typ_line}", entry.typ)
            } else {
                format!(
                    "generated from {}:{typ_line} (line {out_line} is blank or generated)",
                    entry.typ
                )
            };
            err = LpError::at(
                &doc.src,
                range,
                format!("{file}:{out_line}: {message}"),
                note,
            );
        }
        eprintln!("{:?}", miette::Report::new(err));
        mapped += 1;
    }

    Ok(mapped)
}
